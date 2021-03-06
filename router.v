`include "parameters.v"


module  router #(parameter id=1)(out_staging,out_cr_staging, done, can_inject, op, in_staging_pl, cr_staging_pl, data, in_cycle, clk);
  output[`maxio*`BufferBitSize-1:0] out_staging;
  output[`maxio*`BufferBitSize-1:0] out_cr_staging;
  output done;
  output[`maxvc-1:0] can_inject;
  input[`op_size-1:0] op;
  input[`maxio*`BufferBitSize-1:0] in_staging_pl;
  input[`maxio*`BufferBitSize-1:0] cr_staging_pl;
  input[`DataBitSize-1:0] data;
  input[`in_cycle_size-1:0] in_cycle;
  input clk;
  reg done;

  reg [`BufferBitSize-1:0] out_staging_ar[`maxio-1:0];
  reg [`BufferBitSize-1:0] out_cr_staging_ar[`maxio-1:0];
  wire [`BufferBitSize-1:0] in_staging_pl_ar[`maxio-1:0];
  wire [`BufferBitSize-1:0] cr_staging_pl_ar[`maxio-1:0];

  /* Range access is not possible in runtime.
     the following code will generate an array from the flattened input.
  */
  generate
    genvar i;
    for(i=0;i<`maxio;i=i+1)begin
      assign out_staging[(i+1)*`BufferBitSize-1:i*`BufferBitSize]=out_staging_ar[i];
      assign out_cr_staging[(i+1)*`BufferBitSize-1:i*`BufferBitSize]=out_cr_staging_ar[i];
      assign in_staging_pl_ar[i]=in_staging_pl[(i+1)*`BufferBitSize-1:i*`BufferBitSize];
      assign cr_staging_pl_ar[i]=cr_staging_pl[(i+1)*`BufferBitSize-1:i*`BufferBitSize];
    end
  endgenerate


  reg[`PortBitSize-1:0] rt[`RouterBitSize-1:0];
  //per input
  reg[`BufferBitSize-1:0] in_staging[`maxio-1:0];
  reg[`BufferBitSize-1:0] buffer[`maxio-1:0][`maxvc-1:0];
  //per output buffer
  reg[`PortBitSize-1:0]  cur_in_port[`maxio-1:0][`maxvc-1:0];
  reg[`CreditBitSize-1:0]  credit[`maxio-1:0][`maxvc-1:0];

  reg[`BufferBitSize-1:0] crst[`maxio-1:0][`crbufsz-1:0];
  reg[`IndBitSize-1:0] head_crst[`maxio-1:0];
  reg[`IndBitSize-1:0] tail_crst[`maxio-1:0];

// reg[`PortBitSize-1:0] num_in_ports;
// reg[`PortBitSize-1:0] num_out_ports;
//  reg[`NumVcBitSize-1:0] numvcs;
  reg[`CreditDelayBitSize:0] credit_delay;

  generate

    for(i=0;i<`maxvc;i=i+1)begin
        assign can_inject[i]=~(buffer[0][i][21]);
    end
  endgenerate

  /*******************************
  **        Queue Tasks         **
  *******************************/


  task tenqueue(input[`PortBitSize-1:0] out_port,
                input[`MaxCycleBitSize-1:0] cycle,
                input[`VcBitSize-1:0] vc);

      reg[`IndBitSize-1:0] elem;
      begin
        elem =tail_crst[out_port];
        crst[out_port][elem]`BufferTimeStamp=cycle;
        crst[out_port][elem]`BufferVc=vc;
        crst[out_port][elem]`BufferFull=1;
        tail_crst[out_port]=(tail_crst[out_port]+1)%`crbufsz;
      end
  endtask

  task dequeue(output[`VcBitSize-1:0] vc, input[`PortBitSize-1:0] out_port);
    reg[`IndBitSize:0] elem;
    begin
        elem =head_crst[out_port];
        vc=crst[out_port][elem]`BufferVc;
        head_crst[out_port]=(head_crst[out_port]+1)%`crbufsz;
    end
  endtask

  function empty;
    input[`PortBitSize:0] out_port;
    begin
        if(head_crst[out_port]==tail_crst[out_port])
          empty=1;
        else
          empty=0;
    end
  endfunction

  function tempty;
    input[`PortBitSize-1:0] out_port;
    input[`MaxCycleBitSize-1:0] cycle;
    reg[`IndBitSize-1:0] elem;
    begin
        elem =head_crst[out_port];
        if(empty(out_port) == 1 || crst[out_port][elem]`BufferTimeStamp > cycle)
          tempty=1;
        else
          tempty=0;
    end
  endfunction

  function full;
    input[`PortBitSize-1:0] out_port;
    reg[`IndBitSize-1:0] next_tail;
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
  task load_rt(input[31:0] in_data);
  begin
    rt[in_data`RTDst]=in_data`RTOutPort;
  end
  endtask

  /** Load input into stagings **/
  task load_staging;
    reg[`BufferBitSize-1:0] crtmp;
    integer i;
    begin
        for(i=0;i<`maxio;i=i+1) begin
            if(in_staging[i]`BufferFull)begin
                if(`debug)
                    $display("%d Error input staging is full\n",id);
            end
            if(in_staging_pl_ar[i]`BufferFull)begin
                
                if(`debug)
                    $display("%d incoming input at port %d, flit: %b \n",id,i,in_staging_pl_ar[i]);
            end
            in_staging[i]=in_staging_pl_ar[i];
        end
        for(i=1;i<`maxio;i=i+1)
        begin
            crtmp=cr_staging_pl_ar[i];
            if(crtmp`BufferFull)
            begin
                if(`debug)
                    $display("%d Incoming credit at out_port %d Cr_staging_pl: %b \n",id,i,crtmp);
                if(!full(i))
                begin
                    $display("%d enqueueing TimeStamp:%d delay:%d sum:%b",id,crtmp`BufferTimeStamp,credit_delay,crtmp`BufferTimeStamp+credit_delay);
                    tenqueue(i,crtmp`BufferTimeStamp+credit_delay,crtmp`BufferVc);
                end
                else begin
                    if(`debug)
                      $display("%d Error credit buffer is full\n",id);
                end
            end
        end
    end
  endtask

  /** in_staging -> buffer **/
  task phase0;
    reg[`BufferBitSize-1:0] tmp;
    reg[`VcBitSize-1:0] vc;
    reg ret;
    integer i;
    begin
      ret=1;
      for(i=0;i<`maxio;i=i+1) begin
          tmp=in_staging[i];
          if(tmp`BufferFull==1) begin
              if(`debug)
                $display("Note: %d in %d buffering instaging",id,i);
              ret=0;
              vc=tmp`BufferVc;
              if(buffer[i][vc]`BufferFull==1) begin
                  if(`debug  && i!=0)

                      $display("%d vc %d Error input buffer is full.\n",id,vc);
              end
              else begin
                      buffer[i][vc]=tmp;
              end
          end
          in_staging[i]='b0;
      end

      for(i=1;i<`maxio;i=i+1) begin

          if(!tempty(i,in_cycle)) begin
              dequeue(vc,i);
              $display("%d credit ready in queue out %d vc %d cycle:%d !!",id,i,vc,in_cycle);
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
    reg[`FlitBitSize-1:0] flit;
    reg[`PortBitSize-1:0] out_p;
    reg[`CreditBitSize-1:0] cred;
    reg is_full;
    reg ret;

    begin
      mark_out='b0;
      mark_in='b0;
      ret=1;
      for(i=0; i<`maxio; i=i+1) begin
           out_staging_ar[i]='b0;
           out_cr_staging_ar[i]='b0;
//         for(vc=0; vc<`maxvc; vc=vc+1) begin
//         end
      end

      for(vc=0; vc<`maxvc; vc=vc+1) begin
          for(i=0; i<`maxio; i=i+1) begin
              if(mark_in[i]==0)begin
                  flit = buffer[i][vc]`BufferFlit;
                  is_full = buffer[i][vc]`BufferFull;
                  if(is_full) begin
                      if(`debug)
                        $display("%d in %d vc %d Note: full buffer",id,i,vc);
                      ret=0;
                      out_p = rt[flit`FlitDst];

                     if(!mark_out[out_p] && (cur_in_port[out_p][vc]=='b1 || cur_in_port[out_p][vc]==i)) begin
                          cred = credit[out_p][vc];


                          if(`debug)
                            $display("%d out_p %d Note: free target out port for this buffer.",id,out_p);

                          if(out_p==0)begin



                                if(flit`FlitTail)
                                  cur_in_port[out_p][vc]='b1;
                                else
                                  cur_in_port[out_p][vc]=i;

                                mark_in[i]=1;
                                mark_out[out_p]=1;
                                out_staging_ar[out_p]=buffer[i][vc];
                                //out_cr_staging_ar[i]={1'b1,vc,in_cycle};
                                out_cr_staging_ar[i]='b0;
                                out_cr_staging_ar[i]`BufferFull=1;
                                out_cr_staging_ar[i]`BufferVc=vc;
                                out_cr_staging_ar[i]`BufferTimeStamp=in_cycle;
                                if(`debug)
                                    $display("%d Note: sending data at cycle %d. flit: %b",id,in_cycle,out_staging_ar[out_p]);
                                if(`debug)
                                    $display("%d Note: sending credit on in_port %d, cr_staging: %b",id,i,out_cr_staging_ar[i]);
                                buffer[i][vc]='b0;
                          end else
                          if(cred > 0 ) begin

                                if(flit`FlitTail)
                                  cur_in_port[out_p][vc]='b1;
                                else
                                  cur_in_port[out_p][vc]=i;

                                mark_in[i]=1;
                                mark_out[out_p]=1;

                                out_staging_ar[out_p]=buffer[i][vc];
                                out_cr_staging_ar[i]='b0;
                                out_cr_staging_ar[i]`BufferFull=1;
                                out_cr_staging_ar[i]`BufferVc=vc;
                                out_cr_staging_ar[i]`BufferTimeStamp=in_cycle;
                                cred=cred-1;
                                credit[out_p][vc]=cred;
                                buffer[i][vc]='b0;
                                if(`debug)
                                    $display("%d Note: credit is non-zero, sending data at cycle %d flit:%b.",id,in_cycle,out_staging_ar[out_p]);
                                
                                if(`debug)
                                    $display("%d Note: sending credit on in_port %d, cr_staging: %b",id,i,out_cr_staging_ar[i]);
                          end
                      end
                  end
              end
          end
      end
      done=done&ret;
    end
  endtask

  /** initializing, router parameters will be set to their initial value or input data.
      data[11:0]  -> credit_delay
      data[17:12] -> numvcs
      data[24:18] -> num_out_ports
      data[31:25] -> num_in_ports
  **/
  task init(input[31:0] in_data);
    integer i,j;
    begin
      credit_delay=in_data`InitCreditDelay;
//      numvcs=data`InitNumVc;
//      num_out_ports=data`InitNumOutPort;
//      num_in_ports=data`InitNumInPort;
      done=1;
      for(i=0;i<`maxio;i=i+1) begin
          in_staging[i]='b0;
          for(j=0; j<`maxvc; j=j+1) begin
                buffer[i][j]='b0;
                cur_in_port[i][j]='b1;
                credit[i][j]=`input_buffer_size;
          end
          head_crst[i]='b0;
          tail_crst[i]='b0;
      end
    end
  endtask
  
task log;
integer i,j;
begin
//      numvcs=data`InitNumVc;
//      num_out_ports=data`InitNumOutPort;
//      num_in_ports=data`InitNumInPort;
      $display("router %d done %d",id,done);
      for(i=0;i<`maxio;i=i+1) begin
        
          for(j=0; j<`maxvc; j=j+1) begin
                
                $display("router %d out %d vc %d val %d\n",id,i,j,credit[i][j]);
          end
      end
end
endtask

  always @(negedge clk) begin
      case(op)
        `NOP: ;
        `LoadStaging: load_staging();
        `Phase0: phase0();
        `Phase1: phase1();
        `LoadRt: load_rt(data);
        `Init: init(data);
      endcase
      
               //  log();
  end
  /*
=======

  reg[31:0] in_data;
  initial begin

      force op='b0;
      force in_staging_pl = 'b0;
      force cr_staging_pl = 'b0;
      force in_staging_pl_ar[1]={1'b1,4'b0001,1'b0,1'b1, 1'b1, 14'd12};

      in_data=0;
      in_data`InitCreditDelay=1;
      init(in_data);
      in_data=0;
      in_data`RTDst=12;
      in_data`RTOutPort=1;
      #100 load_rt(in_data);
      #100 load_staging();
      #100 phase0();
      #100 phase1();
      #100 phase1();

  end
  */

endmodule
