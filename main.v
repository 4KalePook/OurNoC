`include "parameters.v"
`include "router.v"
module main();


    reg [`State_bit-1             :0]     state;
    reg [`State_bit-1             :0]     next_state;
    reg [`RouterBitSize-1       :0]       load_rt_stage;
    integer i, j;

    /*******************************
    **   read_router reg          **
    *******************************/
    reg [`RouterBitSize-1      :0]     out_router    [0:`RouterSize-1][0:`maxio-1]; //[router i][outport j] -> router k
    reg [`maxio_bit-1           :0]     out_port      [0:`RouterSize-1][0:`maxio-1]; //[router i][outport j] -> inport k
    reg clk;
    reg [`NumVcBitSize-1           :0]     num_vcs;
    reg [`CreditDelayBitSize-1    :0]        credit_delay;
    reg [`PortBitSize-1         :0]     num_in_ports    [0:`RouterSize-1];
    reg [`PortBitSize-1         :0]     num_out_ports    [0:`RouterSize-1];
    `include "read_router.v"


    /*******************************
    **   read_traffic reg         **
    *******************************/
    reg [`PortBitSize-1         :0]         routing_table [0:`RouterSize-1][0:`RouterSize-1]; //[src][dest] -> outport
    reg [`DataBitSize-1         :0]         all_traffic [0:`RouterSize-1]; //[src][idx] -> Data
    reg [`MaxCycleBitSize-1     :0]         max_cycle;
    reg [`MaxTrafficBitSize-1      :0]         router_traffic_size[0:`RouterSize-1];
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
    reg [`DataBitSize-1             :0]     data[0:`RouterSize-1];
    reg [`in_cycle_size-1           :0]     in_cycle;
    reg [`op_size-1                 :0]     op[0:`RouterSize-1];

    generate
    genvar genvar_i, genvar_j;
    for(genvar_i=0; genvar_i<`RouterSize; genvar_i=genvar_i+1)
    begin:routers
        router r(out_staging[genvar_i], out_cr_staging[genvar_i], done[genvar_i], can_inject[genvar_i], op[genvar_i], in_staging[genvar_i], in_cr_staging[genvar_i], data[genvar_i], in_cycle, clk);
        for(genvar_j=0; genvar_j<`maxio; genvar_j=genvar_j+1)
        begin
            assign out_staging_ar[genvar_i][genvar_j] = out_staging[genvar_i][`Range(genvar_j,`BufferBitSize)];
            assign in_staging[genvar_i][`Range(genvar_j,`BufferBitSize)] = in_staging_ar[genvar_i][genvar_j];
            assign out_cr_staging_ar[genvar_i][genvar_j] = out_cr_staging[genvar_i][`Range(genvar_j,`BufferBitSize)];
            assign in_cr_staging[genvar_i][`Range(genvar_j,`BufferBitSize)] = in_cr_staging_ar[genvar_i][genvar_j];
        end
    end
    endgenerate



    task load_staging;
        integer i, j;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            for(j=0; j<`maxio; j=j+1)
            begin
                in_staging_ar[out_router[i][j]][out_port[i][j]] = out_staging_ar[i][j];
                in_cr_staging_ar[i][j] = out_cr_staging_ar[out_router[i][j]][out_port[i][j]];
                op[i] = `LoadStaging;
            end
        end
    endtask


    task init_router;
        integer i;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            data[i]`InitNumInPort = num_in_ports[i];
            data[i]`InitNumOutPort = num_out_ports[i];
            data[i]`InitNumVc = num_vcs;
            data[i]`InitCreditDelay = credit_delay;
            op[i] = `Init;
        end
    endtask

    task load_rt;
            integer i;
    begin
        for(i=0; i<`RouterSize; i=i+1)
        begin
            if(routing_table[i][load_rt_stage][0] !== 1'bx)
            begin
                data[i]`RTOutPort = routing_table[i][load_rt_stage];
                data[i]`RTDst = load_rt_stage;
                op[i] = `LoadRt;
            end
            else
                op[i] = `NOP;
        end
        load_rt_stage = load_rt_stage + 1;
    end
    endtask

    task phase0;
        integer i;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            op[i] = `Phase0;
        end
    endtask

    task phase1;
        integer i;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            op[i] = `Phase1;
        end
    endtask

    initial
    begin
        read_router();
        read_traffic();
        clk <= 0;
        in_cycle <= 0;
        for(i=0; i<`RouterSize; i=i+1)
        begin
            op[i] <= `NOP;
        end
    end
    always #1 clk=~clk;

    always @(posedge clk) begin
        case(state)
            `NOP: ;
            `Init:
            begin
                init_router;
                next_state = `LoadRt;
            end
            `LoadRt:
            begin
                load_rt;
                next_state = `LoadRt;
                if(load_rt_stage >= `RouterSize)
                    next_state = `LoadStaging;
            end
            `LoadStaging:
            begin
                load_staging();
                next_state = `Phase0;
            end
            `Phase0:
            begin
                phase0();
                next_state = `Phase1;
            end
            `Phase1:
            begin
                phase1();
                next_state = `LoadStaging;
                in_cycle = in_cycle + 1;
            end
        endcase

        state = next_state;
    end

endmodule
