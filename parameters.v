`ifndef parameters
`define parameters 1
`define debug 1
`define input_buffer_size 1

`define maxio 16
`define maxio_bit 4
`define maxvc 8


`define crbufsz 100

`define max_cr_delay 100


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

`define MaxTrafficBitSize 10 //TODO: check
`define MaxCycleBitSize 20
`define VcBitSize 5
`define NumVcBitSize 6 //should one bit more 16vc for example
`define RouterBitSize 14
`define RouterSize 1024
`define PortSize 6
`define PortBitSize 7 //hooman value!!
`define CreditDelayBitSize 12 //hooman value!!!
/*******************************
**      Struct Buffer        **
*******************************/
`define BufferBitSize 22 //{full[1],vc[5],flit[16]}
`define BufferFull [21:21]
`define BufferVc [20:16]

/*******************************
**      Struct Flit           **
*******************************/
`define FlitBitSize 16 //{dst[14], head[1], tail[1]}
`define FlitDst [15:2]
`define FlitHead [1:1]
`define FlitTail [0:0]

/*******************************
**      Struct Data           **
*******************************/
`define DataBitSize 32 //{dst[14], vc[5], num_flit[10]}
`define DataDst [31:18]
`define DataVc [17:13]
`define DataNumFlit [12:3]


/*******************************
**      Struct RoutingTable           **
*******************************/
`define RTBitSize 32 //{out_port[6], dst[14]}
`define RTOutPort [19:14]
`define RTDst [13:0]


/*******************************
**      Struct Init           **
*******************************/
`define InitBitSize 32 //same as data {dst[num_in_ports[7]], num_out_ports[7], num_vc[6], credit_dlay[12]}
`define InitNumInPort [31:25]
`define InitNumOutPort [24:18]
`define InitNumVc [17:12]
`define InitCreditDelay [11:0]



`endif
