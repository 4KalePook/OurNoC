`ifndef parameters
`define parameters 1


`define max_router 1024
`define max_router_bit 10
`define maxio 16
`define maxio_bit 4
`define maxvc 8
`define crbufsz 100
`define max_cr_delay 100
`define flit_size 22
`define data_size 32
`define in_cycle_size 14
`define op_size 3
//TODO: mem_size should check
`define mem_size 1000
`define read_word_size 10

`define NOP 0
`define LoadStaging 1
`define Phase0 2
`define Phase1 3
`define LoadRt 4
`define Init   5

`define CopyStaging 0
`define State_bit 3
`define Range(i, siz) size*(i+1)-1:siz*i
`endif
