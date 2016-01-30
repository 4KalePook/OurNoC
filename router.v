`include "parameters.v"


module router(out_staging,out_cr_staging, done, can_inject, op, in_staging_pl, cr_staging_pl, data, in_cycle, clk);
  output[`maxio*22-1:0] out_staging;
  output[`maxio*22-1:0] out_cr_staging;
  output done;
  output can_inject;
  input[2:0] op;
  input[`maxio*22-1:0] in_staging_pl;
  input[`maxio*22-1:0] cr_staging_pl;
  input[31:0] data;
  input[15:0] in_cycle;
  input clk;
  
  reg[5:0] rt[13:0];
  reg[`maxio*22:0] in_staging;
  reg[21:0] crst[`maxio:0][`crbufsz:0];
  reg[15:0] head_crst[`maxio:0];
  reg[15:0] tail_crst[`maxio:0];
  reg[6:0] num_in_ports;
  reg[6:0] num_out_ports;
  reg[5:0] numvcs;
  reg[15:0] credit_delay;
  
  /*******************************
  **        Queue Tasks         **
  *******************************/
  
  
  task tenqueue(input[15:0] out_port,
                input[15:0] cycle,
                input[4:0] vc);
                
      reg[15:0] elem;
      begin
        elem =tail_crst[out_port];
        crst[out_port][elem][15:0]=cycle+credit_delay;
        crst[out_port][elem][20:16]=vc;
        crst[out_port][elem][21]=1; 
        tail_crst[out_port]=(tail_crst[out_port]+1)%`crbufsz;
      end
  endtask
  
  task dequeue(output[4:0] vc, input[15:0] out_port);
    reg[15:0] elem;
    begin
        elem =head_crst[out_port];
        vc=crst[out_port][elem][20:16];
        head_crst[out_port]=(head_crst[out_port]+1)%`crbufsz;
    end
  endtask
  
  function empty;
    input[15:0] out_port;
    begin
        if(head_crst[out_port]==tail_crst[out_port])
          empty=1;
        else
          empty=0;
    end
  endfunction
  
  function tempty;
    input[15:0] out_port;
    input[15:0] cycle;
    reg[15:0] elem;
    begin
        elem =head_crst[out_port];
        if(empty(out_port) == 1 || crst[out_port][elem][15:0] > cycle)
          tempty=1;
        else
          tempty=0;
    end
  endfunction
  
  function full;
    input[15:0] out_port;
    reg[15:0] next_tail;
    begin
        next_tail=(tail_crst[out_port]+1)%`crbufsz;
        if(next_tail==head_crst[out_port])
          full=1;
        else
          full=0;
    end
  endfunction
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
