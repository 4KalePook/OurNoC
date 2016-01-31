`include "parameters.v"
`include "router.v"
module main();


    reg [`State_bit             :0]     state;
    reg [`State_bit             :0]     next_state;

    /*******************************
    **   read_router reg          **
    *******************************/
    reg [`max_router_bit-1      :0]     out_router    [0:`max_router-1][0:`maxio-1];
    reg [`maxio_bit-1           :0]     out_port      [0:`max_router-1][0:`maxio-1];
    reg clk;
    reg [`maxvc_bit-1           :0]     num_vcs;
    reg [`max_cr_delay_bit-1    :0]     cr_delay;
    `include "read_router.v"


    /*******************************
    **   read_traffic reg         **
    *******************************/
    reg [`MaxPortBitSize-1          :0]     routing_table [0:`max_router-1][0:`max_router-1]; //[src][dest] -> outport
    reg [`DataBitSize-1             :0]     all_traffic [0:`max_router-1]; //[src][idx] -> Data
    `include "read_traffic.v"

    /*******************************
    **   Router instantiation     **
    *******************************/
    wire [`maxio*`BufferBitSize-1   :0]     out_staging[0:`max_router-1];
    wire [`BufferBitSize-1          :0]     out_staging_ar[0:`max_router-1][0:`maxio-1];
    wire [`maxio*`BufferBitSize-1   :0]     out_cr_staging[0:`max_router-1];
    wire [`BufferBitSize-1          :0]     out_cr_staging_ar[0:`max_router-1][0:`maxio-1];
    wire                                    done[0:`max_router-1];
    wire [`maxvc-1                  :0]     can_inject[0:`max_router-1];
    wire [`maxio*`BufferBitSize-1   :0]     in_staging[0:`max_router-1];
    reg [`BufferBitSize-1           :0]     in_staging_ar[0:`max_router-1][0:`maxio-1];
    wire [`maxio*`BufferBitSize-1   :0]     in_cr_staging[0:`max_router-1];
    reg [`BufferBitSize-1           :0]     in_cr_staging_ar[0:`max_router-1][0:`maxio-1];
    reg [`data_size-1               :0]     data[0:`max_router-1];
    reg [`in_cycle_size-1           :0]     in_cycle;
    reg [`op_size-1                 :0]     op[0:`max_router-1];

    generate
    genvar i, j;
    for(i=0; i<`max_router; i=i+1)
    begin:routers
        router r(out_staging[i], out_cr_staging[i], done[i], can_inject[i], op[i], in_staging[i], in_cr_staging[i], data[i], in_cycle, clk);
        for(j=0; j<`maxio; j=j+1)
        begin
            assign out_staging_ar[i][j] = out_staging[i][`Range(j,`BufferBitSize)];
            assign in_staging[i][`Range(j,`BufferBitSize)] = in_staging_ar[i][j];
            assign out_cr_staging_ar[i][j] = out_cr_staging[i][`Range(j,`BufferBitSize)];
            assign in_cr_staging[i][`Range(j,`BufferBitSize)] = in_cr_staging_ar[i][j];
        end
    end
    endgenerate



    generate
    genvar i, j;
    for(i=0; i<`max_router; i=i+1)
    begin:routers
        router r(out_staging[i], out_cr_staging[i], done[i], can_inject[i], op[i], in_staging[i], in_cr_staging[i], data[i], in_cycle, clk);
        for(j=0; j<`maxio; j=j+1)
        begin
            assign out_staging_ar[i][j] = out_staging[i][`Range(j,`BufferBitSize)];
            assign in_staging[i][`Range(j,`BufferBitSize)] = in_staging_ar[i][j];
            assign out_cr_staging_ar[i][j] = out_cr_staging[i][`Range(j,`BufferBitSize)];
            assign in_cr_staging[i][`Range(j,`BufferBitSize)] = in_cr_staging_ar[i][j];
        end
    end
    endgenerate



    task load_staging;
        integer i, j;
        for(i=0; i<`max_router; i=i+1)
        begin
            for(j=0; j<`maxio; j=j+1)
            begin
                in_staging_ar[out_router[i][j]][out_port[i][j]] = out_staging_ar[i][j];
                in_cr_staging_ar[i][j] = out_cr_staging_ar[out_router[i][j]][out_port[i][j]];
                op[i] = `LoadStaging;
            end
        end
    endtask


    task phase0;
        integer i, j;
        for(i=0; i<`max_router; i=i+1)
        begin
            op[i] = `Phase0;
        end
    endtask

    task phase1;
        integer i, j;
        for(i=0; i<`max_router; i=i+1)
        begin
            op[i] = `Phase1;
        end
    endtask

    initial
    begin
        read_router();
        read_traffic();
        clk = 0;
        in_cycle=0;
    end
    always #1 clk=~clk;

    always @(posedge clk) begin
        case(state)
            `NOP: ;
            `LoadStaging:
            begin
                phase0();
                next_state = `Phase0;
            end
            `Phase0:
            begin
                phase1();
                next_state = `Phase1;
            end
            `Phase1:
            begin
                load_staging;
                next_state = `LoadStaging;
                in_cycle = in_cycle + 1;
            end
        endcase

        state = next_state;
    end

endmodule
