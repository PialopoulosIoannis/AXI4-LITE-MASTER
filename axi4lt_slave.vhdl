library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi4_lite_ram is
    generic(
        SIZE : integer := 1024;
        ADDR_WIDTH : integer := 12;
        COL_WIDTH : integer := 8;
        NB_COL : integer := 4
    );
    port (
        aclk            : out   STD_LOGIC; 
        areset_n        : out   STD_LOGIC;
        
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
end axi4_lite_ram;