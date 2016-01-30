library verilog;
use verilog.vl_types.all;
entity packet is
    port(
        src             : out    vl_logic_vector(9 downto 0);
        dest            : out    vl_logic_vector(9 downto 0);
        vc              : out    vl_logic_vector(2 downto 0);
        num_flits       : out    vl_logic_vector(15 downto 0);
        src_init        : in     vl_logic_vector(9 downto 0);
        dest_init       : in     vl_logic_vector(9 downto 0);
        vc_init         : in     vl_logic_vector(2 downto 0);
        num_flits_init  : in     vl_logic_vector(15 downto 0)
    );
end packet;
