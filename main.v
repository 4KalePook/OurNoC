`define InitTraffic 6 //internal state
`define FillTraffic 7 //internal state
`define State_bit 4
`include "parameters.v"
`include "router.v"
`include "traffic.v"
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
    `include "read_router.v"


    /*******************************
    **   read_traffic reg         **
    *******************************/
    reg [`PortBitSize-1         :0]         routing_table [0:`RouterSize-1][0:`RouterSize-1]; //[src][dest] -> outport
    reg [`DataBitSize-1         :0]         all_traffic [0:`RouterSize-1][0:`TotalNumTrafficSize-1]; //[src][idx] -> Data
    reg [`MaxCycleBitSize-1     :0]         max_cycle;
    reg [`TotalNumTrafficBitSize-1      :0]      total_num_traffic[0:`RouterSize-1];
    `include "read_traffic.v"

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
            if(`debug)
                $display("traffic_buffer[%b][0]: BufferFull: %b BufferVc: %b FlitHead: %b FlitTail: %b FlitDst: %b",
                    i, in_staging_ar[i][0] `BufferFull, in_staging_ar[i][0] `BufferVc, in_staging_ar[i][0] `FlitHead, in_staging_ar[i][0] `FlitTail, in_staging_ar[i][0] `FlitDst);

            if(can_inject[i][traffic_buffer[i] `BufferVc])
            begin
                in_staging_ar[i][0] = traffic_buffer[i][0];
                traffic_op[i] = `Dequeue;
            end
            else
                traffic_op[i] = `NOP;
            for(j=0; j<`maxio; j=j+1)
            begin
                in_staging_ar[out_router[i][j]][out_port[i][j]] = out_staging_ar[i][j];
                in_cr_staging_ar[i][j] = out_cr_staging_ar[out_router[i][j]][out_port[i][j]];
                // if(`debug)
                //     $display("traffic_buffer[%b][0]: BufferFull: %b BufferVc: %b FlitHead: %b FlitTail: %b FlitDst: %b",
                //         i, in_staging_ar[i][0] `BufferFull, in_staging_ar[i][0] `BufferVc, in_staging_ar[i][0] `FlitHead, in_staging_ar[i][0] `FlitTail, in_staging_ar[i][0] `FlitDst);

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
            if(`debug)
                $display("router[%b]: InitNumInPort:%b InitNumOutPort:%b InitNumVc:%b InitCreditDelay:%b",
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
                if(`debug)
                    $display("router[%b]: RTOutPort:%b RTDst:%b",
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
            traffic_data[i] `InitTrafficTotalNumTraffic = total_num_traffic[i];
            traffic_op[i] = `Init;
            if(`debug)
                $display("traffic[%b]: InitTrafficTotalNumTraffic:%b",
                    i, traffic_data[i] `InitTrafficTotalNumTraffic);
        end
    endtask


    task fill_traffic;
    begin
        for(i=0; i<`RouterSize; i=i+1)
        begin
            if(total_num_traffic[i] > 0)
            begin
                traffic_data[i] `DataDst = all_traffic[i][cnt_fill_traffic]`DataDst;
                traffic_data[i] `DataVc = all_traffic[i][cnt_fill_traffic]`DataVc;
                traffic_data[i] `DataNumFlit = all_traffic[i][cnt_fill_traffic]`DataNumFlit;
                traffic_op[i] = `Fill;
                done_fill_traffic = 1'b1;
                total_num_traffic[i] = total_num_traffic[i] - 1;
                if(`debug)
                    $display("traffic[%b]: DataDst: %b DataVc: %b DataNumFlit: %b",
                        i, traffic_data[i] `DataDst, traffic_data[i] `DataVc, traffic_data[i] `DataNumFlit);
            end
            else
                traffic_op[i] = `NOP;
        end
        cnt_fill_traffic = cnt_fill_traffic + 1;
    end
    endtask


    initial
    begin
        read_router();
        read_traffic();
        clk <= 0;
        in_cycle <= 0;
        cnt_fill_traffic = 0;
        load_rt_stage = 0;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            router_op[i] <= `NOP;
        end
        state = `InitTraffic;
    end
    always #1 clk=~clk;

    always @(posedge clk) begin
        case(state)
            `NOP: ;
            `Init:
            begin
                if(`debug)
                    $display("main State: Init");
                init_router;
                next_state = `LoadRt;
            end
            `LoadRt:
            begin
                if(`debug)
                    $display("main State: LoadRt");
                load_rt;
                next_state = `LoadRt;
                if(load_rt_stage >= `RouterSize)
                    next_state = `LoadStaging;
            end
            `LoadStaging:
            begin
                if(`debug)
                    $display("main State: LoadStaging");
                load_staging();
                next_state = `Phase0;
            end
            `Phase0:
            begin
                if(`debug)
                    $display("main State: Phase0");
                phase0();
                next_state = `Phase1;
            end
            `Phase1:
            begin
                if(`debug)
                    $display("main State: Phase1");
                phase1();
                next_state = `LoadStaging;
                in_cycle = in_cycle + 1;
            end
            `InitTraffic:
            begin
                if(`debug)
                    $display("main State: InitTraffic");
                init_traffic();
                next_state = `FillTraffic;
            end
            `FillTraffic:
            begin
                if(`debug)
                    $display("main State: FillTraffic");
                done_fill_traffic = 0;
                fill_traffic();
                if(done_fill_traffic == 1'b0)
                    next_state = `Init;
                else
                    next_state = `FillTraffic;
            end
        endcase

        state = next_state;
    end

endmodule
