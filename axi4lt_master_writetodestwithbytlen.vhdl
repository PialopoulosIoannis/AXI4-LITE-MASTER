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
    signal length_in_bytes : std_logic_vector ((NB_COL * COL_WIDTH)-1 downto 0) := x"00000009";
    type STATES is (IDLE,WRITE,FINAL_WRITING,FINAL,DONE);
    signal state : STATES:= IDLE;
    type ram_type is array (0 to SIZE - 1) of std_logic_vector(NB_COL * COL_WIDTH - 1 downto 0);
    signal internal_awaddr : STD_LOGIC_VECTOR (ADDR_WIDTH-1 downto 0);
    signal mydata : ram_type := ( 
        0      => x"dead1111",
        1      => x"dead2222",
        2      => x"00000033",
        others => (others => '0'));
    signal internal_wvalid : std_logic;
    signal internal_awvalid : std_logic;    
    signal internal_bready : std_logic;
        
    begin

    process(aclk, areset_n)

    variable counter : integer := 0;
    variable how_many_writes : integer;
    variable final_write : integer;
    variable bytes_in_int : integer;
    variable mask : std_logic_vector(NB_COL * COL_WIDTH - 1 downto 0) := (others => '0');

    begin 

    if areset_n = '0' then 
        s_axilt_awvalid <= '0';
        s_axilt_wvalid <= '0';
        counter := 0;
        state <= IDLE;
        how_many_writes := 0;
        final_write := 0;
        bytes_in_int := 0;
        internal_bready <= '0';
        s_axilt_wstrb <= (others => '1');

    elsif rising_edge(aclk) then
        case (state) is
            when IDLE =>
                bytes_in_int:= to_integer(unsigned(length_in_bytes));
                how_many_writes:= bytes_in_int / 4;
                final_write:= bytes_in_int mod 4; 
                s_axilt_wstrb <= (others => '1');
                internal_awaddr <= dst_base_addr;
                internal_awvalid <= '1';
                internal_wvalid <= '1';
                s_axilt_wdata <= mydata(counter);
                if how_many_writes /= 0 then
                    state <= WRITE;
                else state <= FINAL_WRITING;
                end if;
            when WRITE =>
                    if internal_awvalid = '1' and s_axilt_awready = '1' then
                        internal_awvalid <= '0';
                    end if;
                    if internal_wvalid = '1' and s_axilt_wready = '1' then
                        internal_wvalid <= '0';
                        internal_bready <= '1';
                    end if;
                    if internal_bready = '1' and s_axilt_bvalid = '1' then
                        internal_bready <= '0';
                        counter := counter + 1;
                        if counter /= how_many_writes then
                            state <= WRITE;
                            s_axilt_wdata <= mydata(counter);
                            internal_awaddr <= std_logic_vector(unsigned(dst_base_addr) + (counter * 4));
                            internal_awvalid <= '1';
                            internal_wvalid <= '1';
                        elsif final_write = 0 then
                            state <= FINAL;
                        else 
                        state <= FINAL_WRITING;
                        case (final_write) is
                            when 1 =>
                                s_axilt_wstrb <= "0001";
                            when 2 =>
                                s_axilt_wstrb <= "0011";
                            when 3 =>
                                s_axilt_wstrb <= "0111";
                            when others =>
                                s_axilt_wstrb <= (others => '1');
                        end case;
                        internal_awaddr <= std_logic_vector(unsigned(dst_base_addr) + (counter * 4));
                        s_axilt_wdata <= mydata(counter);
                        internal_awvalid <= '1';
                        internal_wvalid <= '1';
                        end if;
                    end if;
            when FINAL_WRITING =>
                    if internal_awvalid = '1' and s_axilt_awready = '1' then
                        internal_awvalid <= '0';
                    end if;
                    if internal_wvalid = '1' and s_axilt_wready = '1' then
                        internal_wvalid <= '0';
                        internal_bready <= '1';
                    end if;
                    if internal_bready = '1' and s_axilt_bvalid = '1' then
                        internal_bready <= '0';
                        counter := counter + 1;
                        state <= FINAL;
                    end if;
            when FINAL =>
                    report "DATA WRITTEN";
                    state <= DONE;
            when DONE =>
                null;
        end case;
    end if;
    end process;
    s_axilt_awaddr <= internal_awaddr;
    s_axilt_wvalid <= internal_wvalid;
    s_axilt_awvalid <= internal_awvalid;
    s_axilt_bready <= internal_bready;

end behavioural;



    
