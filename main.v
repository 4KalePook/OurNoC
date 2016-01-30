`include "parameters.v"
`include "router.v"
module main();
    reg [`max_router_bit-1 :0]     out_router    [0:`max_router-1][0:`maxio-1];
    reg [`maxio_bit-1      :0]     out_port      [0:`max_router-1][0:`maxio-1];

    reg clk;
    reg [`State_bit:0] state;
    reg [`State_bit:0] next_state;

    `include "read.v"

    /*******************************
    **   Router instantiation     **
    *******************************/
    wire [`maxio*`flit_size-1   :0]     out_staging[`max_router-1:0];
    wire [`maxio*`flit_size-1   :0]     out_cr_staging[`max_router-1:0];
    wire                                done[`max_router-1:0];
    wire                                can_inject[`max_router-1:0];
    reg [`maxio*`flit_size-1    :0]     in_staging[`max_router-1:0];
    reg [`maxio*`flit_size-1    :0]     in_cr_staging[`max_router-1:0];
    reg [`data_size-1           :0]     data[`max_router-1:0];
    reg [`in_cycle_size-1       :0]     in_cycle;
    reg [`op_size-1             :0]     op[`max_router-1:0];

    generate
    genvar i;
    for(i=0; i<`max_router; i=i+1)
    begin:routers

        router r(out_staging[i], out_cr_staging[i], done[i], can_inject[i], op[i], in_staging[i], in_cr_staging[i], data[i], in_cycle, clk);
    end
    endgenerate


    task load_staging;
        integer i, j;
        for(i=0; i<`max_router; i=i+1)
        begin
            for(j=0; j<`maxio; j=j+1)
            begin
                in_staging[out_router[i][j]][`Range(out_port[i][j], `flit_size)] = out_staging[i][`Range(j, `flit_size)];
                in_cr_staging[i][`Range(j, `flit_size)] = out_cr_staging[out_router[i][j]][`Range(out_port[i][j], `flit_size)];
                op[i] = `LoadStaging;
            end
        end
    endtask



    initial
    begin
        read();
        clk = 0;
        in_cycle=0;
    end

    always #1 clk=~clk;

    always @(posedge clk) begin
        case(state)
            `NOP: ;
            `LoadStaging:
            begin
                load_staging;
                next_state = `Phase0;
            end
            `Phase0:
            begin
                // load_staging;
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
