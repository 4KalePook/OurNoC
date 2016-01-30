module packet(src,dest,vc,num_flits,src_init,dest_init,vc_init,num_flits_init);
input[9:0] src_init,dest_init;
input [2:0] vc_init;
input[15:0] num_flits_init; //in refrence code the size was unsigned char so I took it as 2 bytes :)

output reg[9:0] src,dest;
output reg[2:0]vc;
output reg[15:0]num_flits; //in refrence code the size was unsigned char so I took it as 2 bytes :)

always @(src_init,dest_init,vc_init,num_flits_init)
begin
src=src_init;
dest=dest_init;
vc=vc_init;
num_flits=num_flits_init;
end

//there are two other methods "first" and "dequeu" which don't have cpp code ???

endmodule