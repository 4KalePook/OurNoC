`include "parameters.v"
`define Init   5
`define Fill   6
`define Dequeue   7
`define	NumPackets  1024
`define DestSize 14
`define NumFlit 10
`define InitTrafficTotalNumTraffic [31:22];

/*******************************
**        traffic  module     **
*******************************/
module traffic(clk,op, data, done, buffer);

    output done;
    output reg [`BufferBitSize-1 :0] buffer;

    input clk;
    input [2:0] op;
    input [`DataBitSize-1:0] data;

    // reg [`BufferBitSize-1 :0] buffer;
    /*******************************
    **        Pakcet  Arrays       **
    *******************************/
    reg  [`DestSize-1   :0] packet_dest        [0:`TotalNumTrafficSize]; //Ok
    reg  [`VcBitSize-1  :0] packet_vc          [0:`TotalNumTrafficSize]; //Ok
    reg  [`NumFlit-1    :0] packet_num_flits   [0:`TotalNumTrafficSize]; //Ok

    reg [9:0] head,count;		//??
    reg [9:0] num_packets_in_buffer,num_packets_in_buffer_new;

    reg [`NumFlit-1:0] num_flits_left_in_current_packet,num_flits_left_in_current_packet_new;
    reg [9:0] num_packets_sent,num_packets_sent_new;

    reg cur_flit_invalid_p,cur_flit_invalid_p_new;
    reg [`FlitBitSize-1:0] flit;
    reg [9:0] total_num_packets_to_send; //??
    // wire [`DestSize*`NumPackets-1:0] dest;
    // reg  [`DestSize*`NumPackets-1:0] dest_init;
    // wire [`VcBitSize*`NumPackets-1:0] vc;
    // reg  [`VcBitSize*`NumPackets-1:0] vc_init;
    // wire [`NumFlit*`NumPackets-1:0] num_flits;
    // reg  [`NumFlit*`NumPackets-1:0] num_flits_init;

    assign done = (num_packets_sent < total_num_packets_to_send) ? 0 : 1;

    // generate
    // genvar i;
    // for(i=0;i<`NumPackets-1;i=i+1)begin
    // packet packets (dest[(i+1)*`DestSize-1:i*`DestSize],vc[(i+1)*`VcBitSize-1:i*`VcBitSize],num_flits[(i+1)*`NumFlit-1:i*`NumFlit],dest_init[(i+1)*`DestSize-1:i*`DestSize],vc_init[(i+1)*`VcBitSize-1:i*`VcBitSize],num_flits_init[(i+1)*`NumFlit-1:i*`NumFlit]);
    // end
    // endgenerate
    /*******************************************
    **I needed this alwayd loop for synthesis :D **
    ********************************************/
    // always @(op or data)
    // begin
        // buffer `BufferFull = (num_packets_sent < total_num_packets_to_send);
        // num_flits_left_in_current_packet_new = num_flits_left_in_current_packet;
        // cur_flit_invalid_p_new = cur_flit_invalid_p;
    //     if (op == `Init)
    //         num_flits_left_in_current_packet_new=0;
    //     else if(op == `Dequeue )
    //     begin
            // if (cur_flit_invalid_p)
            // begin
            //     if (num_flits_left_in_current_packet == 0)
            //         num_flits_left_in_current_packet_new = num_flits[head*`NumFlit +: `NumFlit];
            // end
            // else
            // num_flits_left_in_current_packet_new = num_flits_left_in_current_packet-1;
    //     end
    //
    //     if(op == `Init)
    //         cur_flit_invalid_p_new = 1;
    //     else if (op == `Dequeue)
            // if (cur_flit_invalid_p)
            //     cur_flit_invalid_p_new = 0;
            // else
            //     cur_flit_invalid_p_new = 1;
    //
    // end

    /*******************************
    **        Queue Task         **
    *******************************/
    task dequeue();
    begin

        //i added
        if (cur_flit_invalid_p)
            cur_flit_invalid_p_new = 0;
        else
            cur_flit_invalid_p_new = 1;

        if (cur_flit_invalid_p)
        begin
            if (num_flits_left_in_current_packet == 0)
                num_flits_left_in_current_packet_new = packet_num_flits[head];
        end
        else
            num_flits_left_in_current_packet_new = num_flits_left_in_current_packet-1;
        //i added



        buffer `BufferVc = packet_vc[head];
        //flit=16'b0;
        //buffer[20:0] = 21'b0;
        if (cur_flit_invalid_p)
        begin
            if (num_flits_left_in_current_packet == 0)
            begin	// create new head flit
                buffer `FlitDst = packet_dest[head];
                buffer `FlitHead = 1;
            end
            else
            begin
                buffer `FlitHead = 0;
            end
            buffer `FlitTail = (num_flits_left_in_current_packet == 1) ? 1 : 0;
        end
        // buffer [`FlitBitSize:0] = flit;
        if (num_flits_left_in_current_packet == 0 )
        begin
            head = (head+1);
            if(head >= num_packets_in_buffer)
            begin
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
        num_packets_in_buffer = 0;
        num_packets_sent_new = 0;
        total_num_packets_to_send = data `InitTrafficTotalNumTraffic;
        cur_flit_invalid_p_new = 1;
        head =0;
        count=0;
    end
    endtask
    /*******************************
    **        Fill Task           **
    *******************************/

    task fill;
    begin
        packet_dest[count] = data `DataDst;
        packet_vc[count]= data `DataVc;
        packet_num_flits[count]= data `DataNumFlit;
        num_packets_in_buffer_new = num_packets_in_buffer + 1;
        count=count+1;
    end
    endtask

    always @(posedge clk) begin
        buffer `BufferFull = (num_packets_sent < total_num_packets_to_send);
        num_flits_left_in_current_packet_new = num_flits_left_in_current_packet;
        cur_flit_invalid_p_new = cur_flit_invalid_p;

        case(op)
            `NOP: ;
            `Fill: fill();
            `Dequeue: dequeue();
            `Init: init();
        default: ;
        endcase
        num_flits_left_in_current_packet = num_flits_left_in_current_packet_new;
        num_packets_sent = num_packets_sent_new;
        num_packets_in_buffer = num_packets_in_buffer_new;
        cur_flit_invalid_p = cur_flit_invalid_p_new;


    end
endmodule
