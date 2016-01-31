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

`define flit_size 22
`define data_size 32
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

`define FlitSrc 42:33
`define FlitDst 32:23
`define FlitVc 22:20
`define FlitNum 19:17
// `define

`define CopyStaging 0
`define State_bit 3
`define Range(i,siz) siz*(i+1)-1:siz*i
`endif
