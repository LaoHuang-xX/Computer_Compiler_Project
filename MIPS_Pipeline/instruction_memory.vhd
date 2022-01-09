LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

-- Xiaozhou Liao, 260668818
-- Xu Hai, 260661832
-- Tingzhe Wang,260687154
entity instruction_memory is
port (
	clk			: in std_logic;
	address		: in integer range 0 to 1023;

	readdata		: out std_logic_vector (31 downto 0)
);
end instruction_memory;

architecture im of instruction_memory is
type MEM is array(1023 downto 0) of std_logic_vector(31 downto 0);
signal ram_block: MEM;

file INSTS : text;

signal last_instruction_addr : integer := 0;

begin
	--This is the main section of the SRAM model
	mem_process: process (clk)
	variable inst_line : line;
	variable inst : std_logic_vector(31 downto 0);
	variable reg_line : line;
	variable mem_line : line;
	variable i : integer := 0;
	variable done : std_logic := '0';
	begin
		--This is a cheap trick to initialize the SRAM in simulation
		if(now < 1 ps) then
			for j in 0 to 1023 loop
				ram_block(j) <= (others => '0');
			end loop;
			
			file_open(INSTS, "program.txt", read_mode);
			while (not endfile(INSTS) and i < 1024) loop
				readline(INSTS, inst_line);
				read(inst_line, inst);
				ram_block(i) <= inst;
				i := i + 1;
			end loop;
			file_close(INSTS);
			last_instruction_addr <= i;
			i := 0;
		end if;
	
	if(rising_edge(clk) and address > last_instruction_addr and done = '0') then
		REPORT "Execution finished.";
		done := '1';
	end if;
	
	end process;
	readdata <= ram_block(address);

end im;
