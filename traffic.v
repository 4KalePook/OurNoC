module traffic(total_num_packets_to_send,num_packets_in_buffer,src_init ,dest_init,vc_init ,num_flits_init, 
cur_flit_dest,cur_flit_invalid_p,cur_flit_tail_p,cur_flit_head_p,not_finished,vc_out,head);

parameter max_num_packets_in_buffer=1;
input num_packets_in_buffer;//bound???
input total_num_packets_to_send;//bound???
input [9*max_num_packets_in_buffer:0] src_init,dest_init;
input [2*max_num_packets_in_buffer:0] vc_init ;
input [15*max_num_packets_in_buffer:0]num_flits_init ; 
output [9:0] cur_flit_dest;
output cur_flit_invalid_p,cur_flit_tail_p,cur_flit_head_p,not_finished;
output [2:0] vc_out;
output head;//not sure about the size
///////////////////////////
  reg head;
  wire [max_num_packets_in_buffer:0] src,dest,vc,num_flits;

  

reg [15:0] num_flits_left_in_current_packet,num_flits_left_in_current_packet_next;//not sure about the bound
reg [9:0] num_packets_sent,num_packets_sent_next;

  reg cur_flit_invalid_p;
  reg [9:0] cur_flit_dest;
  reg cur_flit_head_p,cur_flit_tail_p;
///////////////////////////
//not_finished method
assign not_finished = (num_packets_sent < total_num_packets_to_send) ? 1 : 0;
//vc method
assign vc_out = vc[head];
//init method
initial
begin
//num_packets_in_buffer=0;
num_packets_sent=0;
//???total_num_packets_to_send=؟؟؟؟؟
head =0;
num_flits_left_in_current_packet=0;
cur_flit_invalid_p= 1;
end
//fill method
//I have changed this method......we should first read the file complitely and then give the number of packets and array of initial values to generate the packages
//I had to made this "max_num_packets_in_buffer" because this is impossible to generate on unconstant value.....
genvar i;
for (i=0;i<max_num_packets_in_buffer;i=i+1)
begin:packet_gen
packet traffic_pack (src[9*i],dest[9*i],vc[2*i],num_flits[15*i],src_init[9*i],dest_init[9*i],vc_init[2*i],num_flits_init[15*i]);
end
//first method
always @(cur_flit_invalid_p or num_flits_left_in_current_packet or dest[head] or num_flits[head]  )
begin
if (cur_flit_invalid_p) 
begin // create flit from current packet
    cur_flit_invalid_p = 0;

    if (num_flits_left_in_current_packet == 0) 
    begin // create new head flit
      cur_flit_dest = dest[9*head];
      num_flits_left_in_current_packet = num_flits[9*head];

      cur_flit_head_p = 1;
  end
   else 
     begin
      cur_flit_head_p = 0;
  end
    cur_flit_tail_p = (num_flits_left_in_current_packet == 1) ? 1 : 0; 
end
end

endmodule