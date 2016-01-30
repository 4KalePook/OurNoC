library verilog;
use verilog.vl_types.all;
entity flit is
    port(
        head            : out    vl_logic;
        tail            : out    vl_logic;
        dest            : out    vl_logic_vector(9 downto 0);
        head_init       : in     vl_logic;
        tail_init       : in     vl_logic;
        dest_init       : in     vl_logic_vector(9 downto 0)
    );
end flit;
