`define maxio 16
`define maxvc 8
`define crbufsz 100

`define NOP 0
`define LoadStaging 1
`define Phase0 2
`define Phase1 3
`define LoadRt 4
`define Init   5

module router(out_staging,out_cr_staging, done, can_inject, op, in_staging_pl, cr_staging_pl, data, clk);
  output[`maxio*22:0] out_staging;
  output[`maxio*22:0] out_cr_staging;
  output done;
  output can_inject;
  input[2:0] op;
  input[`maxio*22:0] in_staging_pl;
  input[`maxio*22:0] cr_staging_pl;
  input[31:0] data;
  input clk;
  
  reg[5:0] rt[13:0];
  reg[`maxio*22:0] in_staging;
  reg[21:0] crst[`maxio:0][`crbufsz:0];
  reg[10:0] head_crst[`maxio:0];
  reg[10:0] tail_crst[`maxio:0];
  reg[10:0] head_crst;
  reg[5:0] num_in_ports;
  reg[5:0] num_out_ports;
  reg[4:0] numvcs;
  reg[13:0] credit_delay;
  
  /*******************************
  **        Queue Tasks         **
  *******************************/
  task tenqueue(input cycle,vc);
    
  endtask
  
  task tdequeue();
    
  endtask
  task empty();
    
  endtask
  
  task tempty();
    
  endtask
  
  task full_p();
    
  endtask
  /*******************************
  **        Router Tasks        **
  *******************************/
  
  /** Load a single routing entry into rt
   ** data represents an entry in rt:  data[13:0]-> dest, data[19:14]-> out_port
   **/
  task load_rt; 
  begin
    
  end
  endtask
  
  task load_staging;
  begin
  end
  endtask
  
  task phase0; 
  begin
  end
  endtask
  
  task phase1;
  begin
  end
  endtask
  
  task init; 
  begin
  end
  endtask
  
  always @(posedge clk) begin
      case(op)
        `NOP: ;
        `LoadStaging: load_staging();
        `Phase0: phase0();
        `Phase1: phase1();
        `LoadRt: load_rt();
        `Init: init();
      endcase  
  end
endmodule
