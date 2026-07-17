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
    signal src_base_addr : std_logic_vector(ADDR_WIDTH-1 downto 0) := "00000000";
    signal length_in_bytes : std_logic_vector((NB_COL * COL_WIDTH)-1 downto 0) := b"00000000000000000000000000000001";
    signal internal_arvalid : std_logic;
    signal internal_rready : std_logic;
    type STATES is (IDLE,READ,FINAL_READ,END);
    signal state : STATES:= IDLE;
    type ram_type is array (0 to SIZE - 1) of std_logic_vector(NB_COL * COL_WIDTH - 1 downto 0);
    signal mydata : ram_type := (others => (others => '0'));


    process(areset_n,aclk) --READ
    begin
    variable counter : integer := 0;
    variable how_many_reads : integer;
    variable final_read : integer;
    variable bytes_in_int : integer;

        if areset_n = '0' then 
           internal_arvalid <= '0';
            s_axilt_awvalid <= '0';
            s_axilt_wvalid <= '0';
        elsif rising_edge(aclk) then
          case (state) is
           when IDLE =>   
                bytes_in_int:= to_integer(unsigned(length_in_bytes));
                how_many_reads:= bytes_in_int div 4;
                final_read:= bytes_in_int mod 4; 
                s_axilt_araddr <= src_base_addr;
                state <= READ;
           when READ =>
                if s_axilt_araddr /= "11111111" then
                internal_arvalid <= '1';
                internal_rready <= '1';
            end if;
            if internal_arvalid = '1' and s_axilt_arready = '1' then
                internal_arvalid <= '0';
            end if;
            if s_axilt_rvalid = '1' and internal_rready = '1' then 
                internal_rready <= '0';
                mydata(counter) <= s_axilt_rdata;
                counter := counter + 1;
                if counter /= how_many_reads then
                    state <= READ;
                    s_axilt_araddr <= std_logic_vector(unsigned(src_base_addr) + to_unsigned(counter * 4, ADDR_WIDTH));
                elsif final_read = '0' then
                    state <= END;
                else 
                state <= FINAL_READ;
                 s_axilt_araddr <= std_logic_vector(unsigned(src_base_addr) + to_unsigned(counter * 4, ADDR_WIDTH));
            end if;
            when FINAL_READ => 
                if s_axilt_araddr /= "11111111" then
                internal_arvalid <= '1';
                s_axilt_rready <= '1';
                end if;
                if internal_arvalid = '1' and s_axilt_arready = '1' then
                    internal_arvalid <= '0';
                end if; 
                if s_axilt_rvalid = '1' and internal_rready = '1' then 
                    internal_rready <= '0';
                    mydata(counter) <= s_axilt_rdata((final_read*8)-1 downto 0);
                    counter := counter + 1;
                    state <= END;
                end if;
            when END =>
                    report "DATA READ ARE:"
                    for i in 0 to counter-1 loop 
                        report "DATA:" &to_string(mydata(i));
                    end loop; 
                    wait;
            end case; 
            end if;
            end process;
s_axilt_arvalid <= internal_arvalid ;
s_axilt_rready <= internal_rready ;

end behavioural;





                