`include "parameters.v"
task read_router;
    reg[`read_word_size-1:0] mem[0:`mem_size-1];
    integer i, j;
    begin
        for(i=0; i<`RouterSize; i=i+1)
        begin
            num_in_ports[i] = 0;
            num_out_ports[i] = 0;
        end
        begin
            $readmemh("router_configuration_file.hex", mem);
            i=2;
            credit_delay = mem[0];
            num_vcs = mem[1];
            while(mem[i][0] !== 1'bx)
            begin //src:outport -> dst:inport
                if(num_out_ports[mem[i]] < mem[i+1])
                    num_out_ports[mem[i]] = mem[i+1];
                if(num_in_ports[mem[i+2]] < mem[i+3])
                    num_in_ports[mem[i+2]] = mem[i+3];

                out_router[mem[i]][mem[i+1]] = mem[i+2];
                out_port[mem[i]][mem[i+1]] = mem[i+3];
                if(`debugRouter)
                    $display("router connection : %b %b %b %b", mem[i+0], mem[i+1], mem[i+2], mem[i+3]);
                i=i+4;
            end
        end
    end
endtask
