LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

-- Xiaozhou Liao, 260668818
-- Xu Hai, 260661832
-- Tingzhe Wang,260687154
entity MEM_datapath is
generic(
	RAM_SIZE : integer := 8192
);
port(  
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
end MEM_datapath;

architecture md of MEM_datapath is

type MEM is array(ram_size-1 downto 0) of std_logic_vector(31 downto 0);
signal ram_block: MEM:= (others=>(others=> '0'));

begin

	mem_data <= ram_block(mem_addr) when mem_read = '1';

	process (clk)
	begin
		if(clk'event and clk = '1') then
			if(stall_in = '1') then
				stall_out <= '1';
			else 
				stall_out <= '0';
				MEM_forward_data <= result;
				MEM_forward <= EX_forward;
				lw_forward <= '0';

				if (inst_id=20) then --lw
					read_data <= ram_block(to_integer(unsigned(result)));
					wb_reg_out <= wb_reg_in;
					is_load <= '1';
					need_wb <= '1';
					if(lw_hazard='1')then	
						MEM_forward_data <= ram_block(to_integer(unsigned(result)));
						lw_forward <= '1';
					end if;
				elsif (inst_id=21) then --sw
					ram_block(to_integer(unsigned(result))) <= b;
					is_load <= '0';
					need_wb <= '0';
					
				elsif (inst_id=22 or inst_id=23 or inst_id=24 or inst_id=25) then --beq,bne,j,jr
					is_load <= '0';
					need_wb <= '0';
					
				elsif (inst_id= 26) then--jal
					wb_reg_out <= "11111";
					wb_data_out <= std_logic_vector(to_unsigned(counter_jal,32));
					is_load <= '0';
					need_wb <= '1';
					
				else
					wb_reg_out <= wb_reg_in;
					wb_data_out <= result;
					is_load <= '0';
					need_wb <= '1';
				end if;
			end if;
		end if;
	end process;
end md;