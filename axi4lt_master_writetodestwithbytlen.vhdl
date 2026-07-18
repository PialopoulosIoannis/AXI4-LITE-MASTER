library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi4_lite_master is
    generic(
        SIZE : integer := 1024;
        ADDR_WIDTH : integer := 12;
        COL_WIDTH : integer := 8;
        NB_COL : integer := 4
    );
    port (
        aclk            : in   STD_LOGIC; 
        areset_n        : in   STD_LOGIC;
        
        s_axilt_awaddr  : out   STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
        s_axilt_awvalid : out   STD_LOGIC;
        s_axilt_awready : in    STD_LOGIC;

        s_axilt_wdata   : out   STD_LOGIC_VECTOR((NB_COL * COL_WIDTH)-1 downto 0); -- this is dia
        s_axilt_wstrb   : out   STD_LOGIC_VECTOR(((NB_COL * COL_WIDTH)/8)-1 downto 0); -- 4 bits we need
        s_axilt_wvalid  : out   STD_LOGIC;
        s_axilt_wready  : in    STD_LOGIC;

        s_axilt_bresp   : in    STD_LOGIC_VECTOR(1 downto 0);
        s_axilt_bvalid  : in    STD_LOGIC;
        s_axilt_bready  : out   STD_LOGIC;

        s_axilt_araddr  : out   STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
        s_axilt_arvalid : out   STD_LOGIC;
        s_axilt_arready : in    STD_LOGIC;

        s_axilt_rdata   : in    STD_LOGIC_VECTOR((NB_COL * COL_WIDTH)-1 downto 0);
        s_axilt_rresp   : in    STD_LOGIC_VECTOR(1 downto 0);
        s_axilt_rvalid  : in    STD_LOGIC;
        s_axilt_rready  : out   STD_LOGIC
    );
end axi4_lite_master;

architecture behavioural of axi4_lite_master is
    signal dst_base_addr : std_logic_vector (ADDR_WIDTH-1 downto 0) := b"000000000000";
    signal lenght_in_bytes : std_logic_vector ((NB_COL * COL_WIDTH)-1 downto 0) := x"00000009";
    type STATES is (IDLE,WRITE,FINAL_WRITING,FINAL,DONE);
    signal state : STATES:= IDLE;
    type ram_type is array (0 to SIZE - 1) of std_logic_vector(NB_COL * COL_WIDTH - 1 downto 0);
    signal internal_awaddr : STD_LOGIC_VECTOR (ADDR_WIDTH-1 downto 0);
    signal mydata : ram_type := ( 
        0      => x"dead1111",
        1      => x"dead2222",
        2      => x"00000033",
        others => (others => '0'));
        
    begin;

    process(aclk, areset_n)

    variable counter : integer := 0;
    variable how_many_reads : integer;
    variable final_read : integer;
    variable bytes_in_int : integer;
    variable mask : std_logic_vector(NB_COL * COL_WIDTH - 1 downto 0) := (others => '0');

    begin; 

    if areset_n = '0' then 
        s_axilt_awvalid = '0';
        s_axilt_wvalid = '0';
    elsif rising_edge(aclk) then
        case (state) is
            when IDLE =>
                bytes_in_int:= to_integer(unsigned(length_in_bytes));
                how_many_reads:= bytes_in_int / 4;
                final_read:= bytes_in_int mod 4; 
                internal_awaddr <= dst_base_addr;
                if how_many_reads /= 0 then
                    state <= WRITE;
                else state <= FINAL_WRITING;
                end if;
            when WRITE =>     



    
