`include "parameters.v"
`define	NumPackets  1024
`define DestSize 14
`define NumFlit 10

/*******************************
**        traffic  module     **
*******************************/
module traffic(clk,op, data, done, buffer);

    output done;
    output reg [`BufferBitSize-1 :0] buffer;

    input clk;
    input [`op_size-1:0] op;
    input [`DataBitSize-1:0] data;

    // reg [`BufferBitSize-1 :0] buffer;
    /*******************************
    **        Pakcet  Arrays       **
    *******************************/
    reg  [`DestSize-1   :0] packet_dest        [0:`TotalNumTrafficSize]; //Ok
    reg  [`VcBitSize-1  :0] packet_vc          [0:`TotalNumTrafficSize]; //Ok
    reg  [`NumFlit-1    :0] packet_num_flits   [0:`TotalNumTrafficSize]; //Ok

    reg [9:0] head,count;		//??
    // reg [9:0] num_packets_in_buffer,num_packets_in_buffer_new;

    reg [`NumFlit-1:0] num_flits_left_in_current_packet; //,num_flits_left_in_current_packet_new;
    reg [9:0] num_packets_sent;//,num_packets_sent_new;
    // reg [9:0] num_packets_fill;
    // reg cur_flit_invalid_p,cur_flit_invalid_p_new;
    reg [`FlitBitSize-1:0] flit;
    reg [9:0] total_num_packets_to_send; //??
    // wire [`DestSize*`NumPackets-1:0] dest;
    // reg  [`DestSize*`NumPackets-1:0] dest_init;
    // wire [`VcBitSize*`NumPackets-1:0] vc;
    // reg  [`VcBitSize*`NumPackets-1:0] vc_init;
    // wire [`NumFlit*`NumPackets-1:0] num_flits;
    // reg  [`NumFlit*`NumPackets-1:0] num_flits_init;

    assign done = (head <= total_num_packets_to_send) ? 0 : 1;

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
    task dequeue;
    begin

        //i added
        // if (cur_flit_invalid_p)
        //     cur_flit_invalid_p_new = 0;
        // else
        //     cur_flit_invalid_p_new = 1;

        // if (cur_flit_invalid_p)
        // begin
        if(`debug)
            $display("In Traffic: BufferVc: %b FlitDst: %b current_num: %b num_flits: %b head: %b", packet_vc[head], packet_dest[head], num_flits_left_in_current_packet,packet_num_flits[head],head);

        if (num_flits_left_in_current_packet == 1)
        begin
            num_flits_left_in_current_packet <= packet_num_flits[head];
            num_packets_sent <= num_packets_sent + 1;
            if(head + 1 >= count)
                head <= 0;
            else
                head <= head + 1;
            buffer `FlitHead <= 1;
            buffer `BufferVc <= packet_vc[head];
            buffer `FlitDst <= packet_dest[head];
        end
        else
        begin
            num_flits_left_in_current_packet <= num_flits_left_in_current_packet-1;
            buffer `FlitHead <= 0;
        end


        if (num_flits_left_in_current_packet == 2 || (num_flits_left_in_current_packet==1 && packet_num_flits[head] == 1))
            buffer `FlitTail <= 1;
        else
            buffer `FlitTail <= 0;
    end
    endtask

    task pre_dequeue;
    begin
        buffer `BufferVc <= packet_vc[head];
        buffer `FlitDst <= packet_dest[head];
        num_flits_left_in_current_packet <= packet_num_flits[head];
        buffer `FlitHead <= 1;
        if(head + 1 >= count)
            head <= 0;
        else
            head <= head + 1;
        num_packets_sent <= num_packets_sent + 1;
        if (packet_num_flits[head] == 1)
            buffer `FlitTail <= 1;
        else
            buffer `FlitTail <= 0;
    end
    endtask

    /*******************************
    **        Init Task           **
    *******************************/

    task init;
    begin
        total_num_packets_to_send <= data `InitTrafficTotalNumTraffic;
        // num_flits_left_in_current_packet <= 1;
        head <= 0;
        count <= 0;
        num_packets_sent <= 0;
    end
    endtask
    /*******************************
    **        Fill Task           **
    *******************************/

    task fill;
    begin
        packet_dest[count] <= data `DataDst;
        packet_vc[count] <= data `DataVc;
        packet_num_flits[count] <= data `DataNumFlit;
        count <= count+1;
    end
    endtask

    always @(posedge clk) begin
        buffer `BufferFull <= (num_packets_sent <= total_num_packets_to_send);
        // num_flits_left_in_current_packet_new <= num_flits_left_in_current_packet;
        // cur_flit_invalid_p_new <= cur_flit_invalid_p;

        case(op)
            `NOP: ;
            `Fill: fill();
            `PreDeque: pre_dequeue();
            `Dequeue: dequeue();
            `Init: init();
        default: ;
        endcase
        // num_flits_left_in_current_packet <= num_flits_left_in_current_packet_new;
        // num_packets_sent <= num_packets_sent_new;
        // num_packets_in_buffer <= num_packets_in_buffer_new;
        // cur_flit_invalid_p <= cur_flit_invalid_p_new;


    end
endmodule
