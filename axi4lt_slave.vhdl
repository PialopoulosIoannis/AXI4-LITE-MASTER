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
    signal src_base_addr : std_logic_vector(ADDR_WIDTH-1 downto 0) <= "00000000";
    signal length_in_bits : std_logic_vector((NB_COL * COL_WIDTH)-1 downto 0) <= b"00000000000000000000000000000001";
    signal mydata : std_logic_vector((NB_COL * COL_WIDTH)-1 downto 0) <= (others => '0'); 
    signal internal_arvalid : std_logic;
    signal internal_rready : std_logic;


    process(areset_n,aclk) --READ
    begin
        if areset_n = '0' then 
           internal_arvalid <= '0';
            s_axilt_awvalid <= '0';
            s_axilt_wvalid <= '0';
        elsif rising_edge(aclk) then
            if src_base_addr /= "11111111" then
                internal_arvalid <= '1';
                s_axilt_rready =<='1';
            end if;
            if internal_arvalid = '1' and s_axilt_arready = '1' then
                internal_arvalid <= '0';
                src_base_addr <="11111111";
            end if;
            if s_axilt_rvalid = '1' and internal_rready = '1' then 
                internal_rready <= '0';
                mydata <= s_axilt_rdata(length_in_bytes downto 0);
                report "DATA: " & to_string(mydata);
            end if;
        end if;
    end process;
s_axilt_arvalid <= internal_arvalid ;
s_axilt_rready <= internal_rready ;

end behavioural;





                