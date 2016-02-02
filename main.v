

`include "parameters.v"

//internal state
`define Phase0Router 1
`define Phase1Router 2
`define LoadStagingRouter 3
`define LoadRtRouter 4
`define InitRouter 5
`define InitTraffic 6 //internal state
`define FillTraffic 7 //internal state
`define PreDequeTraffic 8
`define State_bit 4



`define debugRouter 0
`define debugTraffic 1

`define Init   5
`define Fill   6
`define Dequeue   7

`define	NumPackets  1024
`define DestSize 14
`define NumFlit 10
`define InitTrafficTotalNumTraffic [31:22]

module main();


    reg [`State_bit-1             :0]     state;
    reg [`State_bit-1             :0]     next_state;
    reg [`RouterBitSize-1       :0]       load_rt_stage;
    genvar genvar_i, genvar_j;
    reg done_fill_traffic;
    integer cnt_fill_traffic;
    integer i, j;
    reg clk;

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
    reg [`in_cycle_size-1           :0]     in_cycle;
    reg [`op_size-1                 :0]     router_op[0:`RouterSize-1];

    generate
    for(genvar_i=0; genvar_i<`RouterSize; genvar_i=genvar_i+1)
    begin:routers
        router r(out_staging[genvar_i], out_cr_staging[genvar_i], done[genvar_i], can_inject[genvar_i], router_op[genvar_i], in_staging[genvar_i], in_cr_staging[genvar_i], router_data[genvar_i], in_cycle, clk);
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
    integer i, j;
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
            while(mem[i][0] !== 1'bx)
            begin //src:outport -> dst:inport
                if(num_out_ports[mem[i]] < mem[i+1])
                    num_out_ports[mem[i]] = mem[i+1];
                if(num_in_ports[mem[i+2]] < mem[i+3])
                    num_in_ports[mem[i+2]] = mem[i+3];

                out_router[mem[i]][mem[i+1]] = mem[i+2];
                out_port[mem[i]][mem[i+1]] = mem[i+3];
                if(`debugRouter)
                    $display("  router connection : %b %b %b %b", mem[i+0], mem[i+1], mem[i+2], mem[i+3]);
                i=i+4;
            end
        end
    end
	endtask
////////////////////////////////////////////////////
	task read_traffic;
    reg[`read_word_size-1:0] mem[0:`mem_size-1];
    integer i, j, k;
    begin
        if(`debugTraffic | `debugRouter)
            $display("Read traffic and routing table from file:");
        for(i=0; i<`RouterSize; i=i+1)
            total_num_traffic[i] = 0;
        $readmemh("traffic_configuration_file.hex", mem);
        i=1;
        max_cycle = mem[0];
        while(mem[i][0] !== 1'bx)
        begin
            routing_table[mem[i]][mem[i+1]] = mem[i+2]; // src:dest = out_port
            if(`debugRouter)
                $display("  routing table: %b %b %b", mem[i+0], mem[i+1], mem[i+2]);
            i=i+3;
        end
        i=i+1;
        while(mem[i][0] !== 1'bx)
        begin
            total_num_traffic[mem[i]] = mem[i+1];
            if(`debugTraffic)
                $display("  nod : %b %b", mem[i+0], mem[i+1]);
            i=i+2;
            k=0;
            for(j=0; j<mem[i-1]*4; j=j+4)
            begin
                // all_traffic[mem[i+j]][FlitSrc] = mem[i+j];
                all_traffic[mem[i+j]][k]`DataDst = mem[i+j+1];
                all_traffic[mem[i+j]][k]`DataVc = mem[i+j+2];
                all_traffic[mem[i+j]][k]`DataNumFlit = mem[i+j+3];
                k=k+1;
                if(`debugTraffic)
                    $display("  flit : %b %b %b %b", mem[i+j], mem[i+j+1], mem[i+j+2], mem[i+j+3]);
            end
            i = i+mem[i-1]*4;
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
            if(`debugTraffic)
                $display("  traffic_buffer[%b]: BufferFull: %b BufferVc: %b FlitHead: %b FlitTail: %b FlitDst: %b",
                    i, traffic_buffer[i]  `BufferFull, traffic_buffer[i]  `BufferVc, traffic_buffer[i]  `FlitHead, traffic_buffer[i]  `FlitTail, traffic_buffer[i] `FlitDst);

            if(can_inject[i][traffic_buffer[i] `BufferVc])
            begin
                in_staging_ar[i][0] = traffic_buffer[i][0];
                traffic_op[i] <= `Dequeue;
            end
            else
                traffic_op[i] <= `NOP;
            for(j=0; j<`maxio; j=j+1)
            begin
                in_staging_ar[out_router[i][j]][out_port[i][j]] = out_staging_ar[i][j];
                in_cr_staging_ar[i][j] = out_cr_staging_ar[out_router[i][j]][out_port[i][j]];
                if(`debugRouter)
                    $display("  out_staging_ar[%b][%b]: BufferFull: %b BufferVc: %b FlitHead: %b FlitTail: %b FlitDst: %b",
                        i, j, out_staging_ar[i][j] `BufferFull, out_staging_ar[i][j] `BufferVc, out_staging_ar[i][j] `FlitHead, out_staging_ar[i][j] `FlitTail, out_staging_ar[i][j] `FlitDst);
                if(`debugRouter)
                    $display("  out_cr_staging_ar[%b][%b]: BufferFull: %b BufferVc: %b FlitHead: %b FlitTail: %b FlitDst: %b",
                        out_router[i][j], out_port[i][j], out_cr_staging_ar[out_router[i][j]][out_port[i][j]] `BufferFull, out_cr_staging_ar[out_router[i][j]][out_port[i][j]] `BufferVc, out_cr_staging_ar[out_router[i][j]][out_port[i][j]] `FlitHead, out_cr_staging_ar[out_router[i][j]][out_port[i][j]] `FlitTail, out_cr_staging_ar[out_router[i][j]][out_port[i][j]] `FlitDst);

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
            if(`debugRouter)
                $display("  router[%b]: InitNumInPort:%b InitNumOutPort:%b InitNumVc:%b InitCreditDelay:%b",
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
                if(`debugRouter)
                    $display("  router[%b]: RTOutPort:%b RTDst:%b",
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
                $display("  traffic[%b]: InitTrafficTotalNumTraffic:%b",
                    i, traffic_data[i] `InitTrafficTotalNumTraffic);
        end
    endtask


    task fill_traffic;
    begin
        done_fill_traffic <= 1'b0;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            if(total_num_traffic[i] > 0)
            begin
                traffic_data[i] `DataDst <= all_traffic[i][cnt_fill_traffic]`DataDst;
                traffic_data[i] `DataVc <= all_traffic[i][cnt_fill_traffic]`DataVc;
                traffic_data[i] `DataNumFlit <= all_traffic[i][cnt_fill_traffic]`DataNumFlit;
                traffic_op[i] <= `Fill;
                done_fill_traffic <= 1'b1;
                total_num_traffic[i] <= total_num_traffic[i] - 1;
                if(`debugTraffic)
                    $display("  traffic[%b]: DataDst: %b DataVc: %b DataNumFlit: %b",
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

    initial
    begin
        read_router();
        read_traffic();
        clk = 0;
        in_cycle = 0;
        cnt_fill_traffic <= 0;
        load_rt_stage = 0;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            router_op[i] <= `NOP;
            traffic_op[i] <= `NOP;
        end
        state = `InitTraffic;
    end
    always #1 clk=~clk;

    task nop_traffic;
        integer i;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            traffic_op[i] <= `NOP;
        end
    endtask

    always @(posedge clk) begin
        case(state)
            `NOP: ;
            `InitRouter:
            begin
                if(`debug)
                    $display("***main State: Init***");
                nop_traffic;
                init_router;
                next_state <= `LoadRt;
            end
            `LoadRtRouter:
            begin
                if(`debug)
                    $display("***main State: LoadRt***");
                load_rt;
                next_state <= `LoadRt;
                if(load_rt_stage >= `RouterSize)
                    next_state <= `LoadStaging;
            end
            `LoadStagingRouter:
            begin
                if(`debug)
                    $display("***main State: LoadStaging***");
                load_staging();
                next_state <= `Phase0;
            end
            `Phase0Router:
            begin
                if(`debug)
                    $display("***main State: Phase0***");
                phase0();
                next_state <= `Phase1;
            end
            `Phase1Router:
            begin
                if(`debug)
                    $display("***main State: Phase1***");
                phase1();
                next_state <= `LoadStaging;
                in_cycle = in_cycle + 1;
            end
            `InitTraffic:
            begin
                if(`debug)
                    $display("***main State: InitTraffic***");
                init_traffic();
                next_state <= `FillTraffic;
            end
            `FillTraffic:
            begin
                if(`debug)
                    $display("***main State: FillTraffic***");
                fill_traffic();
                if(done_fill_traffic == 1'b0)
                    next_state <= `PreDequeTraffic;
                else
                    next_state <= `FillTraffic;
            end
            `PreDequeTraffic:
            begin
                if(`debug)
                    $display("***main State: PreDequeTraffic***");
                pre_dequeue_traffic();
                next_state <= `Init;
            end
        endcase

        state <= next_state;
    end

endmodule
