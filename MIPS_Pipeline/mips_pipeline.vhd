LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

-- Xiaozhou Liao, 260668818
-- Xu Hai, 260661832
-- Tingzhe Wang,260687154
entity mips_pipeline is
end mips_pipeline;

architecture behavior of mips_pipeline is

component instruction_memory is 
PORT (
	clk			: in std_logic;
	address		: in integer range 0 to 1023;

	readdata		: out std_logic_vector (31 downto 0)
);
end component;

component IF_datapath is
port(
	clk,rst				: in std_logic;
	flush					: in std_logic; -- branch taken
	stall_in				: in std_logic; -- stall if load
	branch_addr			: in integer range 0 to 1023;
	IM_readdata			: in std_logic_vector (31 downto 0);
	prediction_wrong	: IN std_logic := '0';
	prediction_correct: IN std_logic := '0';
	prediction_index	: in integer range 0 to 1023;

	IM_addr				: out integer range 0 to 1023;
	counter				: out integer range 0 to 1023;
	stall_out			: out std_logic;
	instruction			: out std_logic_vector (31 downto 0);
	predict_taken		: out std_logic
);
end component;

component ID_datapath is
port(
	clk					: in std_logic;
	flush					: in std_logic;
	stall_in				: in std_logic;
	wb						: in std_logic;
	wb_data				: in std_logic_vector(31 downto 0);
	wb_addr				: in std_logic_vector(4 downto 0);
	instruction			: in std_logic_vector(31 downto 0);
	counter_in			: in integer;
	id_read				: in std_logic;
	id_addr 				: in integer range 0 to 31;
	EX_forward			: in std_logic;
	MEM_forward			: in std_logic;
	EX_forward_reg 	: in std_logic_vector(4 downto 0);
	MEM_forward_reg	: in std_logic_vector(4 downto 0);
	EX_forward_data	: in std_logic_vector(31 downto 0);
	MEM_forward_data	: in std_logic_vector(31 downto 0);
	predict_taken_in	: in std_logic;

	counter_out			: out integer;
	shamt					: out std_logic_vector(4 downto 0);
	extended_imm		: out std_logic_vector(31 downto 0);
	a,b					: out std_logic_vector(31 downto 0); -- values for ALU
	reg_dest				: out std_logic_vector(4 downto 0); -- wb destibation
	inst_id				: out integer;
	j_addr				: out std_logic_vector(25 downto 0); -- address for j
	a_reg_out			: out std_logic_vector(4 downto 0); --reg number
	b_reg_out			: out std_logic_vector(4 downto 0);
	reg_used				: out std_logic_vector(1 downto 0); --(a,b)
	stall_out			: out std_logic;
	id_data				: out std_logic_vector (31 downto 0);
	predict_taken_out	: out std_logic
);
end component;

component EX_datapath is
port(
	clk					: in std_logic;	
	stall					: in std_logic;
	a_reg,b_reg			: in std_logic_vector(4 downto 0);
	reg_used				: in std_logic_vector(1 downto 0);
	load_data			: in std_logic_vector (31 downto 0);
	load_reg				: in std_logic_vector (4 downto 0);
	lw_forward			: in std_logic;
	a						: in std_logic_vector (31 downto 0);
	b						: in std_logic_vector (31 downto 0);
	shamt					: in std_logic_vector (4 downto 0);
	immediate			: in std_logic_vector (31 downto 0);
	inst_id				: in integer;
	reg_dest_in			: in std_logic_vector(4 downto 0);
	counter				: in integer;
	j_addr				: in std_logic_vector(25 downto 0);
	predict_taken		: in std_logic;

	reg_dest_out		: out std_logic_vector(4 downto 0);
	EX_forward			: out std_logic;
	lw_hazard			: out std_logic;
	stall_out			: out std_logic;
	counter_jal			: out integer;
	counter_out			: out integer := 0; -- prevent out of bound error
	inst_id_out			: out integer;
	result				: out std_logic_vector (31 downto 0);
	b_out					: out std_logic_vector (31 downto 0);
	flush					: out std_logic;
	prediction_wrong	: out std_logic;
	prediction_correct: out std_logic;
	prediction_index	: out integer range 0 to 1023
);
end component;

COMPONENT MEM_datapath IS
GENERIC(
	RAM_SIZE : INTEGER := 8192
);
PORT ( 
	clk					: in std_logic;
	stall_in				: in std_logic;
	inst_id				: in integer;
	result				: in std_logic_vector(31 downto 0);
	b						: in std_logic_vector(31 downto 0);
	wb_reg_in			: in std_logic_vector(4 downto 0);
	mem_read				: in std_logic;
	mem_addr 			: in integer;
	counter_jal			: in integer;
	lw_hazard			: in std_logic;
	EX_forward			: in std_logic;

	MEM_forward_data	: out std_logic_vector(31 downto 0);
	lw_forward			: out std_logic :='0';
	wb_reg_out			: out std_logic_vector(4 downto 0);
	wb_data_out			: out std_logic_vector(31 downto 0);
	read_data			: out std_logic_vector(31 downto 0);
	MEM_forward			: out std_logic:= '0';
	is_load				: out std_logic:= '0';
	need_wb				: out std_logic:= '0';
	stall_out			: out std_logic:= '0';
	mem_data				: out std_logic_vector (31 downto 0)
	);
END COMPONENT;

COMPONENT WB_datapath IS
port(
	clk				: in std_logic;
	reg_reg_in		: in std_logic_vector(4 downto 0);
	reg_data			: in std_logic_vector(31 downto 0);
	read_data		: in std_logic_vector(31 downto 0);
	reg_write_in	: in std_logic;
	mem_to_reg		: in std_logic;
	wb_stall_in		: in std_logic;
	
	reg_write_out	: out std_logic;
	reg_reg_out		: out std_logic_vector(4 downto 0);
	data_out			: out std_logic_vector(31 downto 0)
);
END COMPONENT;

signal reset : std_logic := '1';
signal clk : std_logic := '0';
constant clk_period : time := 1 ns;

--instruction memory
signal IM_addr : integer range 0 to 1023;
signal IM_readdata : std_logic_vector (31 downto 0);

--IF datapath
signal IF_stall : std_logic;
signal IF_instruction : std_logic_vector (31 downto 0);
signal IF_counter_out : integer;
signal IF_predict_taken: std_logic;

--ID datapath
signal ID_read: std_logic;
signal ID_addr : integer range 0 to 31;
signal ID_shamt : std_logic_vector(4 downto 0);
signal ID_a, ID_b: std_logic_vector(31 downto 0);
signal ID_imm : std_logic_vector(31 downto 0);
signal ID_inst_id : integer;
signal ID_stall : std_logic;
signal ID_counter : integer;
signal ID_reg_dest : std_logic_vector(4 downto 0);
signal ID_j_addr: std_logic_vector(25 downto 0);
signal ID_a_reg,ID_b_reg: std_logic_vector(4 DOWNTO 0);
signal ID_reg_used: std_logic_vector(1 DOWNTO 0);
signal ID_predict_taken: std_logic := '0';

--EX datapath
signal EX_result : std_logic_vector (31 downto 0);
signal EX_inst_id : integer;
signal EX_b : std_logic_vector(31 downto 0);
signal EX_stall : std_logic;
signal EX_reg_dest : std_logic_vector(4 downto 0);
signal EX_flush: std_logic;
signal EX_counter_out: integer;
signal EX_counter_jal: integer;
signal EX_forward_valid: std_logic;
signal EX_prediction_wrong: std_logic;
signal EX_prediction_correct: std_logic;
signal EX_prediction_index : integer range 0 to 1023;

--MEM dapatath
signal MEM_stall : std_logic;
signal MEM_data_m_waitrequest : std_logic;
signal reg_write, mem_to_reg : std_logic;
signal MEM_read_data : std_logic_vector(31 downto 0);
signal MEM_reg_data : std_logic_vector(31 downto 0);
signal MEM_reg_reg_out : std_logic_vector(4 downto 0);
signal MEM_forward: std_logic;
signal MEM_forward_data : std_logic_vector(31 downto 0);
signal MEM_lw_forward: std_logic;
signal MEM_load_reg: std_logic_vector (4 downto 0);
signal MEM_read: std_logic;
signal MEM_addr : integer range 0 to 8191;
signal MEM_data,id_data : std_logic_vector(31 downto 0);

--WB datapath
signal WB_stall_in : std_logic;
signal WB_result_in : std_logic_vector(31 downto 0);
signal WB_reg_dest_in : std_logic_vector(4 downto 0);
signal WB_in_dump : std_logic;
signal lw_hazard: std_logic;

--I/O
FILE REG	: text;
FILE MEM	: text;

begin
instruction_memoryD : instruction_memory
port map (
	clk => clk,
	address => IM_addr,
	
	readdata => IM_readdata
);

IF_datapathD: IF_datapath 
port map(
	clk => clk,
	rst => reset,
	flush => EX_flush,
	stall_in => lw_hazard,
	branch_addr => EX_counter_out,
	IM_readdata => IM_readdata,
	prediction_wrong => EX_prediction_wrong,
	prediction_correct => EX_prediction_correct,
	prediction_index => EX_prediction_index,
	
	stall_out => IF_stall,
	IM_addr => IM_addr,
	counter => IF_counter_out,
	instruction => IF_instruction,
	predict_taken => IF_predict_taken
);

ID_datapathD: ID_datapath
port map (
	clk => clk,
	flush => EX_flush,
	stall_in => IF_stall,
	wb => WB_in_dump,
	wb_data => WB_result_in,
	wb_addr => WB_reg_dest_in,
	instruction => IF_instruction,
	counter_in => IF_counter_out,
	id_read => ID_read,
	id_addr => ID_addr,
	EX_forward => EX_forward_valid, 
	MEM_forward => MEM_forward, 
	EX_forward_reg => EX_reg_dest, 
	MEM_forward_reg => MEM_reg_reg_out,
	EX_forward_data => EX_result, 
	MEM_forward_data => MEM_forward_data,
	predict_taken_in => IF_predict_taken,
	
	counter_out => ID_counter,
	shamt => ID_shamt,
	extended_imm => ID_imm,
	a => ID_a,
	b => ID_b,
	reg_dest => ID_reg_dest,
	inst_id => ID_inst_id,
	j_addr => ID_j_addr,
	a_reg_out => ID_a_reg,
	b_reg_out => ID_b_reg,
	reg_used => ID_reg_used,
	stall_out => ID_stall,
	id_data => ID_data,
	predict_taken_out => ID_predict_taken
);

EX_datapathD: EX_datapath
port map(
	clk => clk,
	stall => ID_stall,
	lw_forward => MEM_lw_forward,
	a => ID_a,
	b => ID_b,
	shamt => ID_shamt,
	immediate => ID_imm,
	inst_id => ID_inst_id,
	a_reg => ID_a_reg,
	b_reg => ID_b_reg,
	reg_used => ID_reg_used,
	load_data => MEM_forward_data,
	load_reg => MEM_reg_reg_out,
	reg_dest_in => ID_reg_dest,
	j_addr => ID_j_addr,
	predict_taken => ID_predict_taken,
	
	counter => ID_counter,
	reg_dest_out => EX_reg_dest,
	flush => EX_flush,
	counter_jal => EX_counter_jal,
	stall_out => EX_stall,
	counter_out => EX_counter_out,
	inst_id_out => EX_inst_id,
	result => EX_result,
	b_out => EX_b,
	EX_forward => EX_forward_valid,
	lw_hazard => lw_hazard,
	prediction_wrong => EX_prediction_wrong,
	prediction_correct => EX_prediction_correct,
	prediction_index => EX_prediction_index
);

MEM_datapathD: MEM_datapath
port map(
	clk => clk,
	stall_in => EX_stall,
	inst_id => EX_inst_id,
	result => EX_result,
	b => EX_b,
	wb_reg_in => EX_reg_dest,
	mem_read => MEM_read,
	mem_addr => MEM_addr,
	lw_hazard => lw_hazard,
	EX_forward => EX_forward_valid,
	counter_jal => EX_counter_jal,
	wb_reg_out => MEM_reg_reg_out,
	wb_data_out => MEM_reg_data,
	read_data => MEM_read_data,
	MEM_forward => MEM_forward,
	
	is_load => MEM_to_reg,
	need_wb => reg_write,
	stall_out => WB_stall_in,
	MEM_forward_data =>MEM_forward_data,
	lw_forward => MEM_lw_forward,
	mem_data => MEM_data
);

WB_datapathD: WB_datapath
port map(
  clk =>clk,
  reg_reg_in => MEM_reg_reg_out,
  reg_data => MEM_reg_data,
  read_data => MEM_read_data,
  reg_write_in => reg_write, 
  mem_to_reg => MEM_to_reg, 
  wb_stall_in => WB_stall_in,
  reg_write_out => WB_in_dump,
  reg_reg_out => WB_reg_dest_in,
  data_out => WB_result_in
);
				
clk_process : process
begin
  clk <= '1';
  wait for clk_period/2;
  clk <= '0';
  wait for clk_period/2;
end process;

test_process : process
variable inst_line : line;
variable inst : std_logic_vector(31 downto 0);
variable reg_line : line;
variable mem_line : line;
variable i : integer := 0;

begin
	REPORT "Read instructions.";
	wait for 1 ns;
	REPORT "Instructions loaded.";
	
	REPORT "Execution start.";
	reset <= '0';
	wait for 10000 ns;
	--REPORT "Execution finished.";
	
	REPORT "Log register values.";
	file_open(REG, "registers.txt", write_mode);
	while(i < 32) loop
		id_read <= '1';
		id_addr <= i;
		wait for clk_period;
		write(reg_line, id_data);
		writeline(REG, reg_line);
		i := i + 1;
	end loop;
	id_read <= '0';
	file_close(REG);
	i := 0;
	REPORT "Register values logged.";
		
	REPORT "Log memory values.";
	file_open(MEM, "memory.txt", write_mode);
	while(i < 8192) loop
		mem_read <= '1';
		mem_addr <= i;
		wait for clk_period;
		write(mem_line, mem_data);
		writeline(MEM, mem_line);
		i := i + 1;
	end loop;
	mem_read <= '0';
	file_close(MEM);
	i := 0;
	REPORT "Memory values logged.";
	
	REPORT "Output files generated.";
	
	wait; -- prevent looping
end process;

end behavior;
