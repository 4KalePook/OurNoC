library verilog;
use verilog.vl_types.all;
entity router is
    port(
        out_staging     : out    vl_logic_vector(351 downto 0);
        out_cr_staging  : out    vl_logic_vector(351 downto 0);
        done            : out    vl_logic;
        can_inject      : out    vl_logic_vector(8 downto 0);
        op              : in     vl_logic_vector(2 downto 0);
        in_staging_pl   : in     vl_logic_vector(351 downto 0);
        cr_staging_pl   : in     vl_logic_vector(351 downto 0);
        data            : in     vl_logic_vector(31 downto 0);
        in_cycle        : in     vl_logic_vector(15 downto 0);
        clk             : in     vl_logic
    );
end router;
