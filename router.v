`include "parameters.v"


module router(out_staging,out_cr_staging, done, can_inject, op, in_staging_pl, cr_staging_pl, data, in_cycle, clk);
  output[`maxio*22-1:0] out_staging;
  output[`maxio*22-1:0] out_cr_staging;
  output done;
  output[`maxvc-1:0] can_inject;
  input[2:0] op;
  input[`maxio*22-1:0] in_staging_pl;
  input[`maxio*22-1:0] cr_staging_pl;
  input[31:0] data;
  input[15:0] in_cycle;
  input clk;
  reg done;
  
  reg [22-1:0] out_staging_ar[`maxio:0];
  reg [22-1:0] out_cr_staging_ar[`maxio:0];
  wire [22-1:0] in_staging_pl_ar[`maxio:0];
  wire [22-1:0] cr_staging_pl_ar[`maxio:0];
  
  /* Range access is not possible in runtime.
     the following code will generate an array from the flattened input.
  */
  generate
    genvar i;
    for(i=0;i<`maxio;i=i+1)begin
      assign out_staging[(i+1)*22-1:i*22]=out_staging_ar[i];
      assign out_cr_staging[(i+1)*22-1:i*22]=out_cr_staging_ar[i];
      assign in_staging_pl_ar[i]=in_staging_pl[(i+1)*22-1:i*22];
      assign cr_staging_pl_ar[i]=cr_staging_pl[(i+1)*22-1:i*22];
    end
  endgenerate
  
  
  reg[5:0] rt[13:0];
  //per input
  reg[21:0] in_staging[`maxio:0];
  reg[21:0] buffer[`maxio:0][`maxvc:0];
  //per output buffer
  reg[15:0]  cur_in_port[`maxio:0][`maxvc:0];
  reg[7:0]  credit[`maxio:0][`maxvc:0];
  
  reg[21:0] crst[`maxio:0][`crbufsz:0];
  reg[15:0] head_crst[`maxio:0];
  reg[15:0] tail_crst[`maxio:0];
  
  reg[6:0] num_in_ports;
  reg[6:0] num_out_ports;
  reg[5:0] numvcs;
  reg[15:0] credit_delay;
  
  generate
    
    for(i=0;i<`maxvc;i=i+1)begin
        assign can_inject[i]=~(buffer[0][i][21]);
    end
  endgenerate
  
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
    rt[data[13:0]]=data[19:14];
  end
  endtask
  
  /** Load input into stagings **/
  task load_staging;
    reg[21:0] crtmp;
    integer i;
    begin
        for(i=0;i<num_in_ports;i=i+1) begin
            if(in_staging[i][21])begin
                if(`debug)
                    $display("Error input staging is full\n");
            end
            in_staging[i]=in_staging_pl_ar[i];
        end
        for(i=1;i<num_out_ports;i=i+1) 
        begin
            crtmp=cr_staging_pl_ar[i];
            if(crtmp[21])
            begin
                if(!full(i))
                begin
                    tenqueue(i,crtmp[15:0]+credit_delay,crtmp[20:16]);
                end 
                else begin
                    if(`debug)
                      $display("Error credit buffer is full\n");
                end
            end
        end
    end
  endtask
  
  /** in_staging -> buffer **/ 
  task phase0;
    reg[21:0] tmp;
    reg[4:0] vc;
    reg ret;
    integer i; 
    begin
      ret=1;
      for(i=0;i<num_in_ports;i=i+1) begin
          tmp=in_staging[i];
          if(tmp[21]==1) begin
              ret=0;
              vc=tmp[20:16];
              if(buffer[i][vc][21]==1) begin
                  if(`debug  && i!=0)
                      $display("Error input buffer is full.\n");
              end
              else begin
                      buffer[i][vc]=tmp;
              end
          end
          in_staging[i]='0;
      end
      
      for(i=1;i<num_out_ports;i=i+1) begin
          
          if(!tempty(i,in_cycle)) begin
              dequeue(vc,i);
              credit[i][vc]=credit[i][vc]+1;
          end
          if(!empty(i)) begin
              ret=0;
          end
      end
      done=ret;
    end
  endtask
  
  /** routing **/
  task phase1;
    reg[`maxio-1:0] mark_out;
    reg[`maxio-1:0] mark_in;
    integer i;
    integer vc;
    reg[15:0] flit;
    reg[15:0] out_p;
    reg[7:0] cred;
    reg is_full;
    reg ret;
    
    begin
      mark_out='0;
      mark_in='0;
      ret=1;
      for(i=0; i<num_out_ports; i=i+1) begin
          for(vc=0; vc<numvcs; vc=vc+1) begin
              out_staging_ar[i]='0;
          end
      end
      
      for(vc=0; vc<numvcs; vc=vc+1) begin
          for(i=0; i<num_in_ports; i=i+1) begin
              out_cr_staging_ar[i]='0;
              if(mark_in[i]==0)begin
                  flit = buffer[i][vc][15:0];
                  is_full = buffer[i][vc][21];
                  if(is_full) begin
                      ret=0;
                      out_p = rt[flit[13:0]];
                      
                     if(!mark_out[out_p] && (cur_in_port[out_p][vc]=='1 || cur_in_port[out_p][vc]==i)) begin   
                          cred = credit[out_p][vc];                
                          
                          
                          if(out_p==0)begin
                                if(flit[14])
                                  cur_in_port[out_p][vc]='1;
                                else
                                  cur_in_port[out_p][vc]=i;
                            
                                mark_in[i]=1;
                                mark_out[out_p]=1;
                          
                                out_staging_ar[out_p]=buffer[i][vc];
                                out_cr_staging_ar[i]={1'b1,vc,in_cycle};
                          end else
                          if(cred > 0 ) begin
                                if(flit[14])
                                  cur_in_port[out_p][vc]='1;
                                else
                                  cur_in_port[out_p][vc]=i;
                            
                                mark_in[i]=1;
                                mark_out[out_p]=1;
                          
                                out_staging_ar[out_p]=buffer[i][vc];
                                out_cr_staging_ar[i]={1'b1,vc,in_cycle};
                                cred=cred-1;
                                credit[out_p][vc]=cred;
                          end 
                      end
                  end
              end
          end
      end
      done=ret;
    end
  endtask
  
  /** initializing, router parameters will be set to their initial value or input data. 
      data[11:0]  -> credit_delay
      data[17:12] -> numvcs 
      data[24:18] -> num_out_ports
      data[31:25] -> num_in_ports
  **/
  task init;
    integer i,j;
    begin 
      credit_delay=data[11:0];
      numvcs=data[17:12];
      num_out_ports=data[24:18];
      num_in_ports=data[24:18];
      done=0;
      for(i=0;i<`maxio;i=i+1) begin
          in_staging[i]='0;
          for(j=0; j<`maxvc; j=j+1) begin
                buffer[i][j]='0;
                cur_in_port[i][j]='0;
                credit[i][j]='0;
          end
          head_crst[i]='0;
          tail_crst[i]='0;
      end
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
