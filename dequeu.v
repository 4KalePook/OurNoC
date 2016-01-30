//dequeue method
always @(num_flits_left_in_current_packet or num_packets_in_buffer or num_packets_sent)//the sensivity list may be incomplit
begin
  cur_flit_invalid_p = 1;
  num_flits_left_in_current_packet_next = num_flits_left_in_current_packet - 1; ////combinational loop
  if (num_flits_left_in_current_packet == 0) 
    begin
    head = (head + 1) % num_packets_in_buffer;////these are going to make latches...
    num_packets_sent_next = num_packets_sent + 1;////these are going to make latches...
end
end
always @(num_packets_sent_next or num_flits_left_in_current_packet_next )
begin
num_flits_left_in_current_packet =num_flits_left_in_current_packet_next;
num_packets_sent =num_packets_sent_next;
end