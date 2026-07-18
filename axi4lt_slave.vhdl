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
    signal src_base_addr : std_logic_vector(ADDR_WIDTH-1 downto 0) := "000000000000";
    signal length_in_bytes : std_logic_vector((NB_COL * COL_WIDTH)-1 downto 0) := x"00000009";
    signal internal_arvalid : std_logic;
    signal internal_rready : std_logic;
    type STATES is (IDLE,READ,FINAL_READING,FINAL,DONE);
    signal state : STATES:= IDLE;
    type ram_type is array (0 to SIZE - 1) of std_logic_vector(NB_COL * COL_WIDTH - 1 downto 0);
    signal mydata : ram_type := (others => (others => '0'));
    signal internal_araddr : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');

     function to_hex(slv : std_logic_vector) return string is --hex function
        variable hex    : string(1 to slv'length/4);
        variable nibble : std_logic_vector(3 downto 0);
    begin
        for i in hex'range loop
            nibble := slv(slv'high - (i-1)*4 downto slv'high - (i-1)*4 - 3);
            case nibble is
                when "0000" => hex(i) := '0';
                when "0001" => hex(i) := '1';
                when "0010" => hex(i) := '2';
                when "0011" => hex(i) := '3';
                when "0100" => hex(i) := '4';
                when "0101" => hex(i) := '5';
                when "0110" => hex(i) := '6';
                when "0111" => hex(i) := '7';
                when "1000" => hex(i) := '8';
                when "1001" => hex(i) := '9';
                when "1010" => hex(i) := 'A';
                when "1011" => hex(i) := 'B';
                when "1100" => hex(i) := 'C';
                when "1101" => hex(i) := 'D';
                when "1110" => hex(i) := 'E';
                when "1111" => hex(i) := 'F';
                when others => hex(i) := 'X'; -- covers U, Z, -, W, etc.
            end case;
        end loop;
        return hex;
    end function;

begin 
    process(areset_n,aclk) --READ
    
    variable counter : integer := 0;
    variable how_many_reads : integer;
    variable final_read : integer;
    variable bytes_in_int : integer;
    variable mask : std_logic_vector(NB_COL * COL_WIDTH - 1 downto 0) := (others => '0');
    
    begin
        if areset_n = '0' then 
           internal_arvalid <= '0';
            s_axilt_awvalid <= '0';
            s_axilt_wvalid <= '0';
            STATE <= IDLE;
            counter := 0;
        elsif rising_edge(aclk) then
          case (state) is
           when IDLE =>   
                bytes_in_int:= to_integer(unsigned(length_in_bytes));
                how_many_reads:= bytes_in_int / 4;
                final_read:= bytes_in_int mod 4; 
                internal_araddr <= src_base_addr;
                for i in 0 to (NB_COL * COL_WIDTH) - 1 loop
                        if i< final_read*8 then
                            mask(i) := '1';
                        else
                            mask(i) := '0';
                        end if;
                end loop;
                if how_many_reads /= 0 then
                    state <= READ;
                else state <= FINAL_READING;
                end if;
           when READ =>
                if internal_araddr /= "11111111" then
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
                    internal_araddr <= std_logic_vector(unsigned(src_base_addr) + (counter * 4));
                elsif final_read = 0 then
                    state <= FINAL;
                else 
                state <= FINAL_READING;
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
                    mydata(counter) <= mask and s_axilt_rdata;
                    counter := counter + 1;
                    state <= FINAL;
                end if;
            when FINAL =>
                    report "DATA READ ARE:";
                    for i in 0 to counter-1 loop 
                        report "DATA:" & to_hex(mydata(i));
                    end loop; 
                    state <= DONE;
           
            when DONE =>
            null;
            end case; 
             end if;
            end process;

s_axilt_arvalid <= internal_arvalid ;
s_axilt_rready <= internal_rready ;
s_axilt_araddr <= internal_araddr;

end behavioural;





                