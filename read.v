`include "parameters.v"
task read;
    reg[`read_word_size-1:0] mem[0:`mem_size-1];
    integer i, j;
    begin
        $readmemh("router_configuration.hex", mem);
        i=0;
        while(mem[i] != `read_word_size'bx)
        begin
            out_router[mem[i][0]][mem[i][1]] = mem[i][2];
            out_port[mem[i][0]][mem[i][1]] = mem[i][3];
        end
    end
endtask
