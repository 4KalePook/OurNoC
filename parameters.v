`ifndef parameters
`define parameters 1
`define debug 1
`define input_buffer_size 1

`define max_router 1024
`define max_router_bit 10
`define maxio 16
`define maxio_bit 4
`define maxvc 8
`define maxvc_bit 3
`define max_cycle_bit 20

`define Port_Num 6
`define Port_Num_Bit 3

`define crbufsz 100

`define max_cr_delay 100
`define max_cr_delay_bit 7

`define BufferBitSize 22 //{full[1],vc[5],flit[16]}
`define .BufferFull [21:21]
`define .BufferVc [20:16]

`define FlitSize 16 //{dst[14], head[1], tail[1]}
`define .FlitDst [15:2]
`define .FlitHead [1:1]
`define .FlitTail [0:0]


`define DataBitSize 32 //{dst[14], vc[5], num_flit[2]}
`define .DataDst [31:18]
`define .DataVc [17:13]
`define .DataNumFlit [12:11]

`define in_cycle_size 16
`define op_size 3
//TODO: mem_size should check
`define mem_size 1000
`define read_word_size 20
`define NOP 0
`define LoadStaging 1
`define Phase0 2
`define Phase1 3
`define LoadRt 4
`define Init   5

`define CopyStaging 0
`define State_bit 3
`define Range(i,siz) siz*(i+1)-1:siz*i
`endif
