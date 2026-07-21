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
    signal dst_base_addr : std_logic_vector (ADDR_WIDTH-1 downto 0) := b"000000010000";
    signal src_base_addr : std_logic_vector(ADDR_WIDTH-1 downto 0) := b"000000000000";
    signal length_in_bytes : std_logic_vector ((NB_COL * COL_WIDTH)-1 downto 0) := x"00000009";
    signal start : std_logic := '1';
    type READ_STATES is (IDLE_R,READ,FINAL_READING,FINAL_R,DONE_R,WAITING_R,WAITING_R_1,WAITING_R_2);
    type WRITE_STATES is (IDLE_W,WRITE,FINAL_WRITING,FINAL_W,DONE_W,WAITING_W,WAITING_1);
    signal state_r : READ_STATES:= IDLE_R;
    signal state_w : WRITE_STATES := IDLE_W;
    type ram_type is array (0 to SIZE - 1) of std_logic_vector(NB_COL * COL_WIDTH - 1 downto 0);
    signal internal_awaddr : STD_LOGIC_VECTOR (ADDR_WIDTH-1 downto 0);
    signal data_buffer : std_logic_vector(NB_COL * COL_WIDTH - 1 downto 0) := (others => '0');
    signal buffer_ready_r : std_logic := '0';
    signal buffer_ready_w : std_logic := '1';
    signal internal_wvalid : std_logic;
    signal internal_awvalid : std_logic;    
    signal internal_bready : std_logic;
    signal internal_arvalid : std_logic;
    signal internal_rready : std_logic;
    signal internal_araddr : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal w_done : std_logic;
    signal aw_done : std_logic;
        
    begin

        process(areset_n,aclk) --READ FROM
    
    variable counter : integer := 0;
    variable how_many_reads : integer;
    variable final_read : integer;
    variable bytes_in_int_r : integer;
    variable mask : std_logic_vector(NB_COL * COL_WIDTH - 1 downto 0) := (others => '0');
    
    begin
        if start = '1' then
        if areset_n = '0' then 
           internal_arvalid <= '0';
            state_r <= IDLE_R;
            counter := 0;
            buffer_ready_r <= '0';
            internal_araddr <= src_base_addr;
            
        elsif rising_edge(aclk) then
          case (state_r) is
           when IDLE_R =>   
                    bytes_in_int_r:= to_integer(unsigned(length_in_bytes));
                    how_many_reads:= bytes_in_int_r / 4;
                    final_read:= bytes_in_int_r mod 4; 
                    for i in 0 to (NB_COL * COL_WIDTH) - 1 loop
                            if i< final_read*8 then
                                mask(i) := '1';
                            else
                                mask(i) := '0';
                            end if;
                    end loop;
                    if how_many_reads /= 0 then
                        state_r <= READ;
                    else state_r <= FINAL_READING;
                    end if;
           when READ =>
                        if internal_araddr /= b"111111111111" then
                        internal_arvalid <= '1';
                        internal_rready <= '1';
                    end if;
                    if internal_arvalid = '1' and s_axilt_arready = '1' then
                        internal_arvalid <= '0';
                    end if;
                    if s_axilt_rvalid = '1' and internal_rready = '1' then 
                        internal_rready <= '0';
                        data_buffer <= s_axilt_rdata;
                        buffer_ready_r <= '1';
                        counter := counter + 1;
                         internal_araddr <= std_logic_vector(unsigned(src_base_addr) + (counter * 4));
                        state_r <= WAITING_R_1;
                    end if;
                    when WAITING_R_1 =>
                    state_r <= WAITING_R_2;
                    when WAITING_R_2 =>
                    state_r <= WAITING_R;
            when WAITING_R =>
            if buffer_ready_w = '1' then
                buffer_ready_r <='0';
                if counter /= how_many_reads then
                            state_r <= READ;
                        elsif final_read = 0 then
                            state_r <= FINAL_R;
                        else 
                        state_r <= FINAL_READING;
                        internal_araddr <= std_logic_vector(unsigned(src_base_addr) + (counter * 4));
                    end if;
                    end if;
            when FINAL_READING => 
                    if internal_araddr /= b"111111111111" then
                    internal_arvalid <= '1';
                    internal_rready <= '1';
                    end if;
                    if internal_arvalid = '1' and s_axilt_arready = '1' then
                        internal_arvalid <= '0';
                    end if; 
                    if s_axilt_rvalid = '1' and internal_rready = '1' then 
                        internal_rready <= '0';
                        data_buffer <= mask and s_axilt_rdata;
                        buffer_ready_r <= '1';
                        counter := counter + 1;
                        state_r <= FINAL_R;
                    end if;
            when FINAL_R =>
                    report "DATA READ ";
                    --for i in 0 to counter-1 loop 
                       -- report "DATA:" & to_hex(mydata(i));
                   -- end loop; 
                    state_r <= DONE_R;
           
            when DONE_R =>
            null;
            end case; 
             end if;
             end if;
            end process;

    process(aclk, areset_n) --WRITE TO

    variable counter : integer := 0;
    variable how_many_writes : integer;
    variable final_write : integer;
    variable bytes_in_int_w : integer;
    variable mask : std_logic_vector(NB_COL * COL_WIDTH - 1 downto 0) := (others => '0');

    begin 
    if start = '1' then
    if areset_n = '0' then 
        internal_awvalid <= '0';
        internal_wvalid <= '0';
        counter := 0;
        state_w <= IDLE_W;
        how_many_writes := 0;
        final_write := 0;
        bytes_in_int_w := 0;
        internal_bready <= '0';
        s_axilt_wstrb <= (others => '1');
        w_done <= '0';
        aw_done <= '0';
        internal_awaddr <= dst_base_addr;


    elsif rising_edge(aclk) then
        case (state_w) is
            when IDLE_W => 
                if buffer_ready_r = '1' then
                    bytes_in_int_w:= to_integer(unsigned(length_in_bytes));
                    how_many_writes:= bytes_in_int_w / 4;
                    final_write:= bytes_in_int_w mod 4; 
                    s_axilt_wstrb <= (others => '1');
                    internal_awaddr <= std_logic_vector(unsigned(dst_base_addr) + (counter * 4));
                    s_axilt_wdata <= data_buffer;
                    internal_awvalid <= '1';
                    internal_wvalid <= '1';
                        if how_many_writes /= 0 then
                            state_w <= WRITE;
                        else state_w <= FINAL_WRITING;
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
                        end if;
                        else state_w <= IDLE_W;
                        end if;
            when WRITE =>
                if buffer_ready_r = '1' then
                        if internal_awvalid = '1' and s_axilt_awready = '1' then
                            internal_awvalid <= '0'; 
                            aw_done <= '1';
                        end if;
                        if internal_wvalid = '1' and s_axilt_wready = '1' then
                            internal_wvalid <= '0';
                            internal_bready <= '1';
                            w_done <= '1';
                        end if;
                        if internal_bready = '1' and s_axilt_bvalid = '1' and w_done = '1' and aw_done = '1' then
                            internal_bready <= '0';
                            counter := counter + 1;
                            w_done <= '0';
                            aw_done <= '0';
                            buffer_ready_w <= '1';
                            state_w <= WAITING_1;
                        end if;
                        else state_w <= WAITING_1;
                        internal_awvalid <= '0';
                        internal_wvalid <= '0';
                end if;
                when WAITING_1 =>
                            state_w <= WAITING_W;
            when WAITING_W =>
            if buffer_ready_r = '1' then
                internal_awvalid <= '1';
                internal_wvalid <= '1';
                s_axilt_wdata <= data_buffer;
                if counter /= how_many_writes then
                    state_w <= WRITE;
                elsif final_write /= 0 then
                    state_w <= FINAL_WRITING;
                else state_w <= FINAL_W;
                end if;
            else state_w <= WAITING_W; 
            end if;
            when FINAL_WRITING =>
                    if buffer_ready_r = '1' then
                        if internal_awvalid = '1' and s_axilt_awready = '1' then
                            internal_awvalid <= '0';
                            aw_done <= '1';
                        end if;
                        if internal_wvalid = '1' and s_axilt_wready = '1' then
                            internal_wvalid <= '0';
                            internal_bready <= '1';
                            w_done <= '1';
                        end if;
                        if internal_bready = '1' and s_axilt_bvalid = '1' and w_done = '1' and aw_done = '1' then
                            internal_bready <= '0';
                            counter := counter + 1;
                            w_done <= '0';
                            aw_done <= '0';
                            buffer_ready_w <= '1';
                            state_w <= FINAL_W;
                        end if;
                        else state_w <= WAITING_1;
                            internal_awvalid <= '0';
                            internal_wvalid <= '0';
                    end if;
            when FINAL_W =>
                    report "DATA WRITTEN";
                    state_w <= DONE_W;
            when DONE_W =>
                null;
        end case;
    end if;
    end if;
    end process;
    s_axilt_awaddr <= internal_awaddr;
    s_axilt_wvalid <= internal_wvalid;
    s_axilt_arvalid <= internal_arvalid;
    s_axilt_awvalid <= internal_awvalid;
    s_axilt_bready <= internal_bready;
    s_axilt_araddr <= internal_araddr;
    s_axilt_rready <= internal_rready;

end behavioural;



    
