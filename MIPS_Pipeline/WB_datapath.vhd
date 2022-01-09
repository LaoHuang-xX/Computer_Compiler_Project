LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

-- Xiaozhou Liao, 260668818
-- Xu Hai, 260661832
-- Tingzhe Wang,260687154
entity WB_datapath is
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
end WB_datapath;

architecture wd of WB_datapath is
begin
	process (clk)
	begin
		if(rising_edge(clk) and wb_stall_in = '0') then
			reg_reg_out <= reg_reg_in;
			reg_write_out <=reg_write_in;
			if(mem_to_reg = '1') then
				data_out <= read_data;
			else
				data_out <= reg_data;
			end if;
		else 
			reg_reg_out <= (others=>'0');
			reg_write_out <= '0'; 
			data_out <= (others=>'0');
		end if;
	end process;

end wd;
