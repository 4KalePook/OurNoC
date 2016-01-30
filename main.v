`include "parameters.v"
`include "router.v"
module main();

reg clk;

generate
genvar i;
for(i=0; i<`max_router; i=i+1)
begin:routers
/*******************************
**   Router instantiation     **
*******************************/
    wire [`maxio*`flit_size-1   :0]     out_staging;
    wire [`maxio*`flit_size-1   :0]     out_cr_staging;
    wire                                done;
    wire                                can_inject;
    reg [`maxio*`flit_size-1    :0]     in_staging;
    reg [`maxio*`flit_size-1    :0]     in_cr_staging;
    reg [`data_size-1           :0]     data;
    reg [`in_cycle_size-1       :0]     in_cycle;
    reg [`op_size-1             :0]     op;
    router r(out_staging, out_cr_staging, done, can_inject, op, in_staging, in_cr_staging, data, in_cycle, clk);
end
endgenerate

always @(posedge clk) begin
    case(op)
      `CopyStaging: ;
    //   `LoadStaging: load_staging();
    //   `Phase0: phase0();
    //   `Phase1: phase1();
    //   `LoadRt: load_rt();
    //   `Init: init();
    endcase
end

endmodule
