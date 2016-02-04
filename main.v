

`include "parameters.v"

//internal state
`define CheckEnd 0
`define Phase0Router 1
`define Phase1Router 2
`define LoadStagingRouter 3
`define LoadRtRouter 4
`define InitRouter 5
`define InitTraffic 6 //internal state
`define FillTraffic 7 //internal state
`define PreDequeTraffic 8
`define EndState 9
`define InitState 10
`define State_bit 4




`define Init   5
`define Fill   6
`define Dequeue   7

`define	NumPackets  1024
`define DestSize 14
`define NumFlit 10
`define InitTrafficTotalNumTraffic [31:22]

module main(output reg is_end, output reg [`in_cycle_size-1:0] in_cycle, input wire reset, input wire clk);


    reg [`State_bit-1             :0]     state;
    reg [`State_bit-1             :0]     next_state;
    reg [`RouterBitSize-1       :0]       load_rt_stage;
    genvar genvar_i, genvar_j;
    reg done_fill_traffic;
    integer cnt_fill_traffic;
    integer i, j;
    // reg is_end;
    // reg clk;

    /*******************************
    **   read_router reg          **
    *******************************/
    reg [`RouterBitSize-1      :0]     out_router    [0:`RouterSize-1][0:`maxio-1]; //[router i][outport j] -> router k
    reg [`maxio_bit-1           :0]     out_port      [0:`RouterSize-1][0:`maxio-1]; //[router i][outport j] -> inport k
    reg [`NumVcBitSize-1           :0]     num_vcs;
    reg [`CreditDelayBitSize-1    :0]        credit_delay;
    reg [`PortBitSize-1         :0]     num_in_ports    [0:`RouterSize-1];
    reg [`PortBitSize-1         :0]     num_out_ports    [0:`RouterSize-1];


    /*******************************
    **   read_traffic reg         **
    *******************************/
    reg [`PortBitSize-1         :0]         routing_table [0:`RouterSize-1][0:`RouterSize-1]; //[src][dest] -> outport
    reg [`DataBitSize-1         :0]         all_traffic [0:`RouterSize-1][0:`TotalNumTrafficSize-1]; //[src][idx] -> Data
    reg [`MaxCycleBitSize-1     :0]         max_cycle;
    reg [`TotalNumTrafficBitSize-1      :0]      total_num_traffic[0:`RouterSize-1];
    reg [`TotalNumTrafficBitSize-1      :0]      total_num_traffic_input[0:`RouterSize-1];

    /*******************************
    **   Router instantiation     **
    *******************************/
    wire [`maxio*`BufferBitSize-1   :0]     out_staging[0:`RouterSize-1];
    wire [`BufferBitSize-1          :0]     out_staging_ar[0:`RouterSize-1][0:`maxio-1];
    wire [`maxio*`BufferBitSize-1   :0]     out_cr_staging[0:`RouterSize-1];
    wire [`BufferBitSize-1          :0]     out_cr_staging_ar[0:`RouterSize-1][0:`maxio-1];
    wire                                    done[0:`RouterSize-1];
    wire [`maxvc-1                  :0]     can_inject[0:`RouterSize-1];
    wire [`maxio*`BufferBitSize-1   :0]     in_staging[0:`RouterSize-1];
    reg [`BufferBitSize-1           :0]     in_staging_ar[0:`RouterSize-1][0:`maxio-1];
    wire [`maxio*`BufferBitSize-1   :0]     in_cr_staging[0:`RouterSize-1];
    reg [`BufferBitSize-1           :0]     in_cr_staging_ar[0:`RouterSize-1][0:`maxio-1];
    reg [`DataBitSize-1             :0]     router_data[0:`RouterSize-1];
    // reg [`in_cycle_size-1           :0]     in_cycle;
    reg [`op_size-1                 :0]     router_op[0:`RouterSize-1];

    generate
    for(genvar_i=0; genvar_i<`RouterSize; genvar_i=genvar_i+1)
    begin:routers
        router #(genvar_i) r(out_staging[genvar_i], out_cr_staging[genvar_i], done[genvar_i], can_inject[genvar_i], router_op[genvar_i], in_staging[genvar_i], in_cr_staging[genvar_i], router_data[genvar_i], in_cycle, clk);
        for(genvar_j=0; genvar_j<`maxio; genvar_j=genvar_j+1)
        begin
            assign out_staging_ar[genvar_i][genvar_j] = out_staging[genvar_i][`Range(genvar_j,`BufferBitSize)];
            assign in_staging[genvar_i][`Range(genvar_j,`BufferBitSize)] = in_staging_ar[genvar_i][genvar_j];
            assign out_cr_staging_ar[genvar_i][genvar_j] = out_cr_staging[genvar_i][`Range(genvar_j,`BufferBitSize)];
            assign in_cr_staging[genvar_i][`Range(genvar_j,`BufferBitSize)] = in_cr_staging_ar[genvar_i][genvar_j];
        end
    end
    endgenerate



    /*******************************
    **  I/O tasks instantiation   **
    *******************************/
	 task read_router;
    reg[`read_word_size-1:0] mem[0:`mem_size-1];
    reg[`read_word_size-1:0] memoff[0:3];
    reg[8:0] i, j;
    begin
        if(`debugRouter)
            $display("Read router connection from file:");
        for(i=0; i<`RouterSize; i=i+1)
        begin
            num_in_ports[i] = 0;
            num_out_ports[i] = 0;
        end
        begin
            $readmemh("router_configuration_file.hex", mem);
            i=2;
            credit_delay = mem[0];
            num_vcs = mem[1];
            while( i+3 < `mem_size && mem[i][0] !== 1'bx)
            begin //src:outport -> dst:inport
                memoff[0]=`SafeAccess(mem,i,`mem_size);
                memoff[1]=`SafeAccess(mem,i+1,`mem_size);
                memoff[2]=`SafeAccess(mem,i+2,`mem_size);
                memoff[3]=`SafeAccess(mem,i+3,`mem_size);
                if(num_out_ports[memoff[0]] < memoff[1])
                    num_out_ports[memoff[0]] = memoff[1];
                if(num_in_ports[memoff[2]] < memoff[3])
                    num_in_ports[memoff[2]] = memoff[3];

                out_router[memoff[0]][memoff[1]] = memoff[2];
                out_port[memoff[0]][memoff[1]] = memoff[3];
                if(`debugRouter)
                    $display("  router connection : %b %b %b %b", memoff[0], memoff[1], memoff[2], memoff[3]);
                i=i+4;
            end
        end
    end
	endtask
////////////////////////////////////////////////////
	task read_traffic;
    reg[`read_word_size-1:0] mem[0:`mem_size-1];
    reg[`read_word_size-1:0] memoff[0:3];
    reg[8:0] i, j, k;
    begin
        if(`debugTraffic | `debugRouter)
            $display("Read traffic and routing table from file:");
        for(i=0; i<`RouterSize; i=i+1)
        begin
            total_num_traffic[i] = 0;
            total_num_traffic_input[i] = 0;
        end
        $readmemh("traffic_configuration_file.hex", mem);
        i=1;
        max_cycle = mem[0];
        while(i+2 < `mem_size && mem[i][0] !== 1'bx)
        begin
            memoff[0]=`SafeAccess(mem,i,`mem_size);
            memoff[1]=`SafeAccess(mem,i+1,`mem_size);
            memoff[2]=`SafeAccess(mem,i+2,`mem_size);
            
            routing_table[memoff[0]][memoff[1]] = memoff[2]; // src:dest = out_port
            if(`debugRouter)
                $display("  routing table: %b %b %b", memoff[0], memoff[1], memoff[2]);
            i=i+3;
        end
        i=i+1;
        while(i+1 < `mem_size && mem[i][0] !== 1'bx)
        begin
            
            memoff[0]=`SafeAccess(mem,i,`mem_size);
            memoff[1]=`SafeAccess(mem,i+1,`mem_size);
            
            total_num_traffic[memoff[0]] = memoff[1];
            if(`debugTraffic)
                $display("  nod : %b %b", mem[i+0], mem[i+1]);
            i=i+2;
            k=0;
            j=0;
            while(i+j+3 < `mem_size && (k < `TotalNumTrafficSize)&& mem[i+j][0] !== 1'bx && j<mem[i-1]*4)
            begin
                // all_traffic[mem[i+j]][FlitSrc] = mem[i+j];
                memoff[0]=`SafeAccess(mem,i+j,`mem_size);
                memoff[1]=`SafeAccess(mem,i+j+1,`mem_size);
                memoff[2]=`SafeAccess(mem,i+j+2,`mem_size);
                memoff[3]=`SafeAccess(mem,i+j+3,`mem_size);
                all_traffic[memoff[0]][k]`DataDst = memoff[1];
                all_traffic[memoff[0]][k]`DataVc = memoff[2];
                all_traffic[memoff[0]][k]`DataNumFlit = memoff[3];
                k=k+1;
                total_num_traffic_input[mem[i]] = k;
                if(`debugTraffic)
                    $display("  flit : %b %b %b %b", memoff[0], memoff[1], memoff[2], memoff[3]);
                j= j+4;
            end
            i = i+j;
        end
    end
	 endtask


    /*******************************
    **   Traffic instantiation    **
    *******************************/

    wire [`BufferBitSize-1          :0]     traffic_buffer[0:`RouterSize-1];
    wire                                    traffic_done [0:`RouterSize-1];
    reg  [`op_size-1                :0]     traffic_op [0:`RouterSize-1];
    reg  [`DataBitSize-1            :0]     traffic_data[0:`RouterSize-1];

    generate
    for(genvar_i=0; genvar_i<`RouterSize; genvar_i=genvar_i+1)
    begin:traffics
        traffic t(clk, traffic_op[genvar_i], traffic_data[genvar_i], traffic_done[genvar_i], traffic_buffer[genvar_i]);
    end
    endgenerate



    task load_staging;
        integer i, j;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            if(`debugTraffic && i < 5)
                $display("  traffic_buffer[%d]: BufferFull: %b BufferVc: %b FlitHead: %b FlitTail: %b FlitDst: %b",
                    i, traffic_buffer[i]  `BufferFull, traffic_buffer[i]  `BufferVc, traffic_buffer[i]  `FlitHead, traffic_buffer[i]  `FlitTail, traffic_buffer[i] `FlitDst);

            if(can_inject[i][traffic_buffer[i] `BufferVc])
            begin
                in_staging_ar[i][0] = traffic_buffer[i];
                traffic_op[i] <= `Dequeue;
                $display("raft too");
            end
            else
            begin
                traffic_op[i] <= `NOP;
                in_staging_ar[i][0] = 0;
            end
            for(j=1; j<`maxio; j=j+1)
            begin
                in_staging_ar[out_router[i][j]][out_port[i][j]] = out_staging_ar[i][j];
                in_cr_staging_ar[i][j] = out_cr_staging_ar[out_router[i][j]][out_port[i][j]];
                // if(`debugRouter && j<5 && i<5)
                // begin
                //     // $display("  out_staging_ar[%d][%d]: BufferFull: %b BufferVc: %b FlitHead: %b FlitTail: %b FlitDst: %b",
                //     //     i, j, out_staging_ar[i][j] `BufferFull, out_staging_ar[i][j] `BufferVc, out_staging_ar[i][j] `FlitHead, out_staging_ar[i][j] `FlitTail, out_staging_ar[i][j] `FlitDst);
                //     // $display("  out_port[%d][%d]: %b out_router: %b",i, j, out_port[i][j], out_router[i][j]);
                // end
                // if(`debugRouter && j<5 && i<5)
                //     $display("in_cr[%d][%d] = out_cr[%d][%d]: BufferFull: %b BufferVc: %b FlitHead: %b FlitTail: %b FlitDst: %b",
                //         i, j, out_router[i][j], out_port[i][j], out_cr_staging_ar[out_router[i][j]][out_port[i][j]] `BufferFull, out_cr_staging_ar[out_router[i][j]][out_port[i][j]] `BufferVc, out_cr_staging_ar[out_router[i][j]][out_port[i][j]] `FlitHead, out_cr_staging_ar[out_router[i][j]][out_port[i][j]] `FlitTail, out_cr_staging_ar[out_router[i][j]][out_port[i][j]] `FlitDst);

                router_op[i] = `LoadStaging;
            end
        end
    endtask


    task init_router;
        integer i;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            router_data[i]`InitNumInPort = num_in_ports[i];
            router_data[i]`InitNumOutPort = num_out_ports[i];
            router_data[i]`InitNumVc = num_vcs;
            router_data[i]`InitCreditDelay = credit_delay;
            if(`debugRouter && i<5)
                $display("  router[%d]: InitNumInPort:%b InitNumOutPort:%b InitNumVc:%b InitCreditDelay:%b",
                    i, router_data[i]`InitNumInPort,router_data[i]`InitNumOutPort,router_data[i]`InitNumVc,router_data[i]`InitCreditDelay);
            router_op[i] = `Init;
        end
    endtask

    task load_rt;
            integer i;
    begin
        for(i=0; i<`RouterSize; i=i+1)
        begin
            if(routing_table[i][load_rt_stage][0] !== 1'bx)
            begin
                router_data[i]`RTOutPort = routing_table[i][load_rt_stage];
                router_data[i]`RTDst = load_rt_stage;
                router_op[i] = `LoadRt;
                if(`debugRouter && i<5)
                    $display("  router[%d]: RTOutPort:%b RTDst:%b",
                        i, router_data[i]`RTOutPort,router_data[i]`RTDst);

            end
            else
                router_op[i] = `NOP;
        end
        load_rt_stage = load_rt_stage + 1;
    end
    endtask

    task phase0;
        integer i;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            router_op[i] = `Phase0;
        end
    endtask

    task phase1;
        integer i;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            router_op[i] = `Phase1;
        end
    endtask


    task init_traffic;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            traffic_data[i] `InitTrafficTotalNumTraffic <= total_num_traffic[i];
            traffic_op[i] <= `Init;
            if(`debugTraffic)
                $display("  traffic[%d]: InitTrafficTotalNumTraffic:%b",
             i, traffic_data[i] `InitTrafficTotalNumTraffic);
        end
    endtask


    task fill_traffic;
    begin
        done_fill_traffic <= 1'b0;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            if(total_num_traffic_input[i] > 0)
            begin
                traffic_data[i] `DataDst <= all_traffic[i][cnt_fill_traffic]`DataDst;
                traffic_data[i] `DataVc <= all_traffic[i][cnt_fill_traffic]`DataVc;
                traffic_data[i] `DataNumFlit <= all_traffic[i][cnt_fill_traffic]`DataNumFlit;
                traffic_op[i] <= `Fill;
                done_fill_traffic <= 1'b1;
                total_num_traffic_input[i] <= total_num_traffic_input[i] - 1;
                if(`debugTraffic)
                    $display("  traffic[%d]: DataDst: %b DataVc: %b DataNumFlit: %b",
                        i, traffic_data[i] `DataDst, traffic_data[i] `DataVc, traffic_data[i] `DataNumFlit);
            end
            else
                traffic_op[i] <= `NOP;
        end
        cnt_fill_traffic <= cnt_fill_traffic + 1;
    end
    endtask


    task pre_dequeue_traffic;
    integer i;
    begin
        for(i=0; i<`RouterSize; i=i+1)
        begin
            traffic_op[i] <= `PreDeque;
        end
    end
    endtask

    task init_state;
    begin
        read_router();
        read_traffic();
        in_cycle = 0;
        cnt_fill_traffic <= 0;
        load_rt_stage = 0;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            router_op[i] <= `NOP;
            traffic_op[i] <= `NOP;
        end
    end
    endtask


    task nop_traffic;
        integer i;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            traffic_op[i] <= `NOP;
        end
    endtask



    task check_end;
    begin
        is_end = 1;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            router_op[i] = `NOP;
            if(done[i] !== 1'b1)
            begin
                is_end = 0;
                if(`debugRouter)
                    $display("  done[%d]: %b", i, done[i]);
            end
        end
    end
    endtask

    always @(posedge clk or posedge reset) begin
        if(reset)
            state <= `InitState;
        else
        begin
            case(state)
                `EndState:
                begin
                    if(`debug)
                        $display("***main State: EndState***");
                end
                `InitState:
                begin
                    if(`debug)
                        $display("***main State: InitState***");
                    init_state;
                    state <= `InitTraffic;
                end
                `InitRouter:
                begin
                    if(`debug)
                        $display("***main State: InitRouter***");
                    nop_traffic;
                    init_router;
                    state <= `LoadRtRouter;
                end
                `LoadRtRouter:
                begin
                    if(`debug)
                        $display("***main State: LoadRtRouter***");
                    load_rt;
                    state <= `LoadRtRouter;
                    if(load_rt_stage >= `RouterSize)
                        state <= `LoadStagingRouter;
                end
                `LoadStagingRouter:
                begin
                    if(`debug)
                        $display("***main State: LoadStagingRouter***");
                    load_staging();
                    state <= `Phase0Router;
                end
                `Phase0Router:
                begin
                    if(`debug)
                        $display("***main State: Phase0Router***");
                    nop_traffic;
                    phase0();
                    state <= `Phase1Router;
                end
                `Phase1Router:
                begin
                    if(`debug)
                        $display("***main State: Phase1Router***");
                    phase1();
                    state <= `CheckEnd;
                end
                `CheckEnd:
                begin
                    if(`debug)
                        $display("***main State: CheckEnd ***");
                    check_end();
                    if(is_end == 1'b1)
                    begin
                        $display("finished at Cycle: %d", in_cycle);
                        state <= `EndState;
                    end
                    else
                    begin
                        in_cycle = in_cycle + 1;
                        if(`debug)
                          $display("***Next Cycle: %d***",in_cycle);
                        state <= `LoadStagingRouter;
                    end
                end
                `InitTraffic:
                begin
                    if(`debug)
                        $display("***main State: InitTraffic***");
                    init_traffic();
                    state <= `FillTraffic;
                end
                `FillTraffic:
                begin
                    if(`debug)
                        $display("***main State: FillTraffic***");
                    fill_traffic();
                    if(done_fill_traffic == 1'b0)
                        state <= `PreDequeTraffic;
                    else
                        state <= `FillTraffic;
                end
                `PreDequeTraffic:
                begin
                    if(`debug)
                        $display("***main State: PreDequeTraffic***");
                    pre_dequeue_traffic();
                    state <= `InitRouter;
                end
            endcase
        end
        // state <= next_state;
    end

endmodule


module stimulus();
    wire is_end;
    wire [`in_cycle_size-1:0] in_cycle;
    reg reset;
    reg clk;

    always #1 clk=~clk;

    main m(is_end, in_cycle, reset, clk);
    initial begin
        clk=0;
        reset = 1;
        #1 reset = 0;
    end

    always @(posedge is_end)
    begin
        $display("\n*************** SIMUlATION END AT CYCLE : %d *********************", in_cycle);
    end
endmodule
