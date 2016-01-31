`include "parameters.v"
task read_traffic;
    reg[`read_word_size-1:0] mem[0:`mem_size-1];
    integer i, j;
    begin
        $readmemh("traffic_configuration.hex", mem);
        i=1;
        max_cycle = mem[0];
        while(mem[i][0] !== 1'bx)
        begin
            routing_table[mem[i]][mem[i+1]] = mem[i+2]; // src:dest:out_port
            $display("mem0-2 : %b %b %b", mem[i+0], mem[i+1], mem[i+2]);
            i=i+3;
        end
        i=i+1;
        while(mem[i][0] !== 1'bx)
        begin
            router_num_packet_to_send[mem[i]] = mem[i+1];
            for(j=0; j<mem[i]; j=j+1)
            begin
                all_traffic[mem[i]][mem[i+1]] = mem[i+2]; // src:dest:out_port
                $display("mem0-2 : %b %b %b", mem[i+0], mem[i+1], mem[i+2]);
            end
            i=i+3;
        end
    end
endtask
