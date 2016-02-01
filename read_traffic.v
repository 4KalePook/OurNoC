`include "parameters.v"
task read_traffic;
    reg[`read_word_size-1:0] mem[0:`mem_size-1];
    integer i, j;
    begin
        $readmemh("traffic_configuration_file.hex", mem);
        i=1;
        max_cycle = mem[0];
        while(mem[i][0] !== 1'bx)
        begin
            routing_table[mem[i]][mem[i+1]] = mem[i+2]; // src:dest = out_port
            $display("routing table: %b %b %b", mem[i+0], mem[i+1], mem[i+2]);
            i=i+3;
        end
        i=i+1;
        while(mem[i][0] !== 1'bx)
        begin
            router_traffic_size[mem[i]] = router_traffic_size[mem[i]] + 1;
            $display("nod : %b %b", mem[i+0], mem[i+1]);
            i=i+2;
            for(j=0; j<mem[i-1]*4; j=j+3)
            begin
                // all_traffic[mem[i+j]][FlitSrc] = mem[i+j];
                all_traffic[mem[i+j]]`DataDst = mem[i+j+1];
                all_traffic[mem[i+j]]`DataVc = mem[i+j+2];
                all_traffic[mem[i+j]]`DataNumFlit = mem[i+j+3];
                $display("flit : %b %b %b %b", mem[i+j], mem[i+j+1], mem[i+j+2], mem[i+j+3]);
            end
            i = i+mem[i-1]*4;
        end
    end
endtask
