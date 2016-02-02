`include "parameters.v"
`define Init   5
`define Fill   6
`define Dequeue   7
`define	NumPackets  10
`define DestSize 14
`define NumFlit 10
`define InitTrafficTotalNumTraffic [31:22]
  /*******************************
  **        packet  module      **
  *******************************/
  
module packet(dest,vc,num_flits,dest_init,vc_init,num_flits_init);
input[`DestSize-1:0] dest_init;
input [`VcBitSize-1:0] vc_init;
input[`NumFlit-1:0] num_flits_init;

output reg[`DestSize-1:0] dest;
output reg[`VcBitSize-1:0]vc;
output reg[`NumFlit-1:0]num_flits;

always @(dest_init,vc_init,num_flits_init)
begin
dest=dest_init;
vc=vc_init;
num_flits=num_flits_init;
end

endmodule
  /*******************************
  **        traffic  module         **
  *******************************/
module traffic(clk,op, data, done, buffer);

  output done;
  output reg [`BufferBitSize-1 :0] buffer;
  
  input clk;
  input [2:0] op;
  input [`DataBitSize-1:0] data;

 // reg [`BufferBitSize-1 :0] buffer;
  
  reg [9:0] head,count,count_new;		//??
  reg [9:0] num_packets_in_buffer,num_packets_in_buffer_new;

  reg [`NumFlit-1:0] num_flits_left_in_current_packet,num_flits_left_in_current_packet_new;
  reg [9:0] num_packets_sent,num_packets_sent_new;

  reg cur_flit_invalid_p,cur_flit_invalid_p_new;
  reg [`FlitBitSize-1:0] flit;
  reg [9:0] total_num_packets_to_send; //??
  wire [`DestSize*`NumPackets-1:0] dest;
  reg  [`DestSize*`NumPackets-1:0] dest_init;
  wire [`VcBitSize*`NumPackets-1:0] vc;
  reg  [`VcBitSize*`NumPackets-1:0] vc_init;
  wire [`NumFlit*`NumPackets-1:0] num_flits;
  reg  [`NumFlit*`NumPackets-1:0] num_flits_init;

  assign done = (num_packets_sent < total_num_packets_to_send) ? 0 : 1;
    generate
    genvar i;
    for(i=0;i<`NumPackets-1;i=i+1)begin
	  packet packets (dest[(i+1)*`DestSize-1:i*`DestSize],vc[(i+1)*`VcBitSize-1:i*`VcBitSize],num_flits[(i+1)*`NumFlit-1:i*`NumFlit],dest_init[(i+1)*`DestSize-1:i*`DestSize],vc_init[(i+1)*`VcBitSize-1:i*`VcBitSize],num_flits_init[(i+1)*`NumFlit-1:i*`NumFlit]);
    end
  endgenerate
  /*******************************************
  **I needed this alwayd loop for synthesis :D **
  ********************************************/
  always @(op or data or num_packets_in_buffer or num_flits_left_in_current_packet or cur_flit_invalid_p or num_packets_sent or total_num_packets_to_send or head or num_flits or dest)
  begin
  buffer `BufferFull = (num_packets_sent < total_num_packets_to_send);
  num_flits_left_in_current_packet_new = num_flits_left_in_current_packet;
 
   if (op == `Init)
  num_flits_left_in_current_packet_new=0;
  else if(op == `Dequeue )
  begin
  if (cur_flit_invalid_p) 
  begin
    if (num_flits_left_in_current_packet == 0) 
      num_flits_left_in_current_packet_new = num_flits[head*`NumFlit +: `NumFlit];
  end
  else
  num_flits_left_in_current_packet_new = num_flits_left_in_current_packet-1;
  end
 
   
 if(op == `Init)
 cur_flit_invalid_p_new = 1;
 else if (op == `Dequeue)
 begin
 if (cur_flit_invalid_p) 
    cur_flit_invalid_p_new = 0;
 else
 cur_flit_invalid_p_new = 1;
 end
 else
 cur_flit_invalid_p_new = cur_flit_invalid_p;
 
 if(op == `Init)
 num_packets_in_buffer_new = 0;
 else if (op == `Fill)
 num_packets_in_buffer_new = num_packets_in_buffer + 1;
 else
 num_packets_in_buffer_new = num_packets_in_buffer;
  end
 
  /*******************************
  **        Queue Task         **
  *******************************/
    task dequeue();

    begin
    
	buffer `BufferVc = vc[head*`VcBitSize +: `VcBitSize ];
	if (cur_flit_invalid_p) 
	begin
    if (num_flits_left_in_current_packet == 0) 
	begin	// create new head flit
      flit `FlitDst = dest[head*`DestSize +: `DestSize];
      flit `FlitHead = 1;
    end 
	else 
	begin
      flit `FlitHead = 0;
    end
    flit `FlitTail = (num_flits_left_in_current_packet == 1) ? 1 : 0; 
  end
 
  buffer [`FlitBitSize:0] = flit;
 
		if (num_flits_left_in_current_packet == 0 )
		begin
        head = (head+1);
		if(head >= num_packets_in_buffer)begin
			head=head-num_packets_in_buffer;
		end
		num_packets_sent_new = num_packets_sent + 1 ;
		end
    end
  endtask
  
 
  /*******************************
  **        Init Task           **
  *******************************/

    task init;
    begin
	
	num_packets_sent_new = 0;
	total_num_packets_to_send = data `InitTrafficTotalNumTraffic;
	head =0;
	count_new=0;
	
	 end
    endtask
  /*******************************
  **        Fill Task           **
  *******************************/
	
	task fill;
	begin
	
	dest_init [count*`DestSize +: `DestSize]= data `DataDst;
	vc_init[count*`VcBitSize +: `VcBitSize]= data `DataVc;
	num_flits_init[count * `NumFlit +: `NumFlit ]= data `DataNumFlit;
	count_new=count+1;
	
	
	end
	endtask
  always @(posedge clk) begin
  
      case(op)
        `NOP:
        begin
        $display("NOP");
         
       end
        `Fill:
      begin 
      $display("Fill");
      fill();
     end
        `Dequeue:
        begin
        $display("Dequeue");
         dequeue();
        end
        `Init:
        begin
         $display("Init");
         init();
        end
		default: ;
      endcase  
	  num_flits_left_in_current_packet = num_flits_left_in_current_packet_new;
	  num_packets_sent = num_packets_sent_new;
	  num_packets_in_buffer = num_packets_in_buffer_new;
	  cur_flit_invalid_p = cur_flit_invalid_p_new;
	  count = count_new;
  end
endmodule

