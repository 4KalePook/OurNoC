library verilog;
use verilog.vl_types.all;
entity traffic is
    generic(
        max_num_packets_in_buffer: integer := 1
    );
    port(
        total_num_packets_to_send: in     vl_logic;
        num_packets_in_buffer: in     vl_logic;
        src_init        : in     vl_logic_vector;
        dest_init       : in     vl_logic_vector;
        vc_init         : in     vl_logic_vector;
        num_flits_init  : in     vl_logic_vector;
        cur_flit_dest   : out    vl_logic_vector(9 downto 0);
        cur_flit_invalid_p: out    vl_logic;
        cur_flit_tail_p : out    vl_logic;
        cur_flit_head_p : out    vl_logic;
        not_finished    : out    vl_logic;
        vc_out          : out    vl_logic_vector(2 downto 0);
        head            : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of max_num_packets_in_buffer : constant is 1;
end traffic;
