library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Xiaozhou Liao, 260668818
-- Xu Hai, 260661832
--Tingzhe Wang,260687154
entity cache_tb is
end cache_tb;

architecture behavior of cache_tb is

component cache is
generic(
    ram_size : INTEGER := 32768
);
port(
    clock : in std_logic;
    reset : in std_logic;

    -- Avalon interface --
    s_addr : in std_logic_vector (31 downto 0);
    s_read : in std_logic;
    s_readdata : out std_logic_vector (31 downto 0);
    s_write : in std_logic;
    s_writedata : in std_logic_vector (31 downto 0);
    s_waitrequest : out std_logic; 

    m_addr : out integer range 0 to ram_size-1;
    m_read : out std_logic;
    m_readdata : in std_logic_vector (7 downto 0);
    m_write : out std_logic;
    m_writedata : out std_logic_vector (7 downto 0);
    m_waitrequest : in std_logic
);
end component;

component memory is 
GENERIC(
    ram_size : INTEGER := 32768;
    mem_delay : time := 10 ns;
    clock_period : time := 1 ns
);
PORT (
    clock: IN STD_LOGIC;
    writedata: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
    address: IN INTEGER RANGE 0 TO ram_size-1;
    memwrite: IN STD_LOGIC;
    memread: IN STD_LOGIC;
    readdata: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
    waitrequest: OUT STD_LOGIC
);
end component;
	
-- test signals 
signal reset : std_logic := '0';
signal clk : std_logic := '0';
constant clk_period : time := 1 ns;

signal s_addr : std_logic_vector (31 downto 0);
signal s_read : std_logic;
signal s_readdata : std_logic_vector (31 downto 0);
signal s_write : std_logic;
signal s_writedata : std_logic_vector (31 downto 0);
signal s_waitrequest : std_logic;

signal m_addr : integer range 0 to 2147483647;
signal m_read : std_logic;
signal m_readdata : std_logic_vector (7 downto 0);
signal m_write : std_logic;
signal m_writedata : std_logic_vector (7 downto 0);
signal m_waitrequest : std_logic; 

begin

-- Connect the components which we instantiated above to their
-- respective signals.
dut: cache 
port map(
    clock => clk,
    reset => reset,

    s_addr => s_addr,
    s_read => s_read,
    s_readdata => s_readdata,
    s_write => s_write,
    s_writedata => s_writedata,
    s_waitrequest => s_waitrequest,

    m_addr => m_addr,
    m_read => m_read,
    m_readdata => m_readdata,
    m_write => m_write,
    m_writedata => m_writedata,
    m_waitrequest => m_waitrequest
);

MEM : memory
port map (
    clock => clk,
    writedata => m_writedata,
    address => m_addr,
    memwrite => m_write,
    memread => m_read,
    readdata => m_readdata,
    waitrequest => m_waitrequest
);

clk_process : process
begin
  clk <= '0';
  wait for clk_period/2;
  clk <= '1';
  wait for clk_period/2;
end process;

test_process : process
begin
-- there are 8 potential tests for read, but only 4 are possible for our implementation
-- those are not possible including invalid&&(tag matched || dirty), valid && tag not matched && dirty
-- similar for write, only 4 tests are possible.
-- tests will be finished within 200ns
  wait for 1 * clk_period;
  REPORT "Test1: read when invalid";
  s_addr <= std_logic_vector(to_unsigned(4,32));
  -- current tag = 0
  s_read <= '1';
  wait until rising_edge(s_waitrequest);
  s_read <= '0';
  assert s_readdata=X"07" & X"06" & X"05" & X"04" report "test1 failed" severity error;
  
  REPORT "Test2: read when valid, tag matched and not dirty";
  s_addr <= std_logic_vector(to_unsigned(8,32));
  -- current tag = 0
  s_read <= '1';
  wait until rising_edge(s_waitrequest);
  s_read <= '0';
  assert s_readdata=X"0b" & X"0a" & X"09" & X"08" report "test2 failed" severity error;
  
  REPORT "Test3: read when valid, tag not matched and not dirty";
  s_addr <= std_logic_vector(to_unsigned(68,32));
  -- current tag = 2
  s_read <= '1';
  wait until rising_edge(s_waitrequest);
  s_read <= '0';
  assert s_readdata=X"47" & X"46" & X"45" & X"44" report "test3_setup failed" severity error;
  s_addr <= std_logic_vector(to_unsigned(4,32));
  -- current tag = 0
  s_read <= '1';
  wait until rising_edge(s_waitrequest);
  s_read <= '0';
  assert s_readdata=X"07" & X"06" & X"05" & X"04" report "test3 failed" severity error;
  
  REPORT "Test4: write when invalid & Test5: read when valid, tag matched and dirty, ";
  s_addr <= std_logic_vector(to_unsigned(128,32));
  -- current tag = 4
  s_write <= '1';
  s_writedata <= X"04" & X"05" & X"06" & X"07";
  wait until rising_edge(s_waitrequest);
  s_write <= '0';
  s_addr <= std_logic_vector(to_unsigned(128,32));
  -- current tag = 4
  s_read <= '1';
  wait until rising_edge(s_waitrequest);
  s_read <= '0';
  assert s_readdata=X"04" & X"05" & X"06" & X"07" report "test4&5 failed" severity error;

  REPORT "Test6: write when valid, tag not matched and not dirty";
  s_addr <= std_logic_vector(to_unsigned(68,32));
  -- current tag = 2
  s_write <= '1';
  s_writedata <= X"44" & X"45" & X"46" & X"47";
  wait until rising_edge(s_waitrequest);
  s_write <= '0';
  s_addr <= std_logic_vector(to_unsigned(68,32));
  -- current tag = 2
  s_read <= '1';
  wait until rising_edge(s_waitrequest);
  s_read <= '0';
  assert s_readdata=X"44" & X"45" & X"46" & X"47" report "test6 failed" severity error;

  REPORT "Test7: write when valid, tag matched and not dirty";
  s_addr <= std_logic_vector(to_unsigned(4,32));
  -- current tag = 0, this reading making the data in 68 be saved to memory, making it not dirty
  s_read <= '1';
  wait until rising_edge(s_waitrequest);
  s_read <= '0';
  assert s_readdata=X"07" & X"06" & X"05" & X"04" report "test7_setup failed" severity error;
  s_addr <= std_logic_vector(to_unsigned(68,32));
  -- current tag = 2, this reading making the data in 68 be loaded to cache, making tag be 2
  s_read <= '1';
  wait until rising_edge(s_waitrequest);
  s_read <= '0';
  assert s_readdata=X"44" & X"45" & X"46" & X"47" report "test7_setup failed" severity error;
  s_addr <= std_logic_vector(to_unsigned(68,32));
  -- current tag = 2
  s_write <= '1';
  s_writedata <= X"47" & X"46" & X"45" & X"44";
  wait until rising_edge(s_waitrequest);
  s_write <= '0';
  s_addr <= std_logic_vector(to_unsigned(68,32));
  s_read <= '1';
  wait until rising_edge(s_waitrequest);
  s_read <= '0';
  assert s_readdata=X"47" & X"46" & X"45" & X"44" report "test7 failed" severity error;
	
  REPORT "Test8: write when valid, tag matched and dirty";
  s_addr <= std_logic_vector(to_unsigned(68,32));
  -- current tag = 2
  s_write <= '1';
  s_writedata <= X"44" & X"45" & X"46" & X"47";
  wait until rising_edge(s_waitrequest);
  s_write <= '0';
  s_addr <= std_logic_vector(to_unsigned(68,32));
  -- current tag = 2
  s_read <= '1';
  wait until rising_edge(s_waitrequest);
  s_read <= '0';
  assert s_readdata=X"44" & X"45" & X"46" & X"47" report "test8 failed" severity error;
	
  REPORT "Test9: test reset";
  reset <= '1';
  s_addr <= std_logic_vector(to_unsigned(68,32));
  -- current tag = 0
  s_read <= '1';
  wait until rising_edge(s_waitrequest);
  s_read <= '0';
  assert s_readdata=X"47" & X"46" & X"45" & X"44" report "test9 failed" severity error;
  wait;
end process;
	
end;