`include "parameters.v"
`include "router.v"
module main();
    `include "read.v"
    reg clk;
    reg state;

    wire [`max_router_bit-1 :0]     out_router    [0:`max_router-1][0:`maxio-1];
    wire [`maxio_bit-1      :0]     out_port      [0:`max_router-1][0:`maxio-1];



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
    reg [`in_cycle_size-1       :0]     in_cycle[`max_router-1:0];
    reg [`op_size-1             :0]     op[`max_router-1:0];

    generate
    genvar i;
    for(i=0; i<`max_router; i=i+1)
    begin:routers

        router r(out_staging[i], out_cr_staging[i], done[i], can_inject[i], op[i], in_staging[i], in_cr_staging[i], data[i], in_cycle[i], clk);
    end
    endgenerate


    task copy_staging;
        integer i, j;
        for(i=0; i<`max_router; i=i+1)
        begin
            for(j=0; j<`maxio; j=j+1)
                in_staging[out_router[i][j]][Range(out_port[i][j], `flit_size)] = out_staging[i][Range(j, `flit_size)];
        end
    endtask



    initial
    begin
        read();
    end
    always @(posedge clk) begin
        case(state)
          `CopyStaging: copy_staging;
        endcase
    end

endmodule
