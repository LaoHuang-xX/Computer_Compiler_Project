LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

-- Xiaozhou Liao, 260668818
-- Xu Hai, 260661832
-- Tingzhe Wang,260687154
entity IF_datapath is
port(
	clk,rst				: in std_logic;
	flush					: in std_logic; -- branch taken
	stall_in				: in std_logic; -- stall if load
	branch_addr			: in integer range 0 to 1023;
	IM_readdata			: in std_logic_vector (31 downto 0);
	prediction_wrong	: in std_logic := '0';
	prediction_correct: in std_logic := '0';
	prediction_index	: in integer range 0 to 1023;

	IM_addr				: out integer range 0 to 1023;
	counter				: out integer range 0 to 1023;
	stall_out			: out std_logic;
	instruction			: out std_logic_vector (31 downto 0);
	predict_taken		: out std_logic
);
end IF_datapath;

architecture fd of IF_datapath is
signal new_counter : integer range 0 to 1023 := 1; -- next counter
type local_predictor is array(1023 downto 0) of std_logic;
signal branch_predictor : local_predictor := (1023 downto 0 => '0'); -- 1-bit predictor

begin
  	process (clk)
	variable i : integer := 0;
  	begin
    if(clk'event and clk = '1') then
		if(rst = '1') then
			IM_addr <= 0;
			new_counter <= 1;
			stall_out <= '1';
		elsif(rst = '0') then
			if(stall_in = '0' and new_counter < 1023) then
				instruction <= IM_readdata;
				IM_addr <= new_counter;
				counter <= new_counter - 1;
				if(IM_readdata(31 downto 26) = "000100" OR IM_readdata(31 downto 26) = "000101") then -- beq, bne
					i := new_counter - 1;
					if(branch_predictor(i) = '0') then
						predict_taken <= '0';	
						if (new_counter < 1024) then
							new_counter <= new_counter + 1; 
						end if;
					else	-- '1'
						predict_taken <= '1';
						new_counter <= new_counter + 1 + to_integer(signed(IM_readdata(15 downto 0)));
						IM_addr <= new_counter + to_integer(signed(IM_readdata(15 downto 0)));
					end if;
				elsif (new_counter < 1024) then
					new_counter <= new_counter + 1; -- update counter
				end if;
				stall_out <= '0';
			else
				stall_out <= '1';
				instruction <= (others=>'0');
			end if;
		end if;
	end if;
	if(clk'event and clk = '0') then
		if(rst = '0' and flush = '1') then -- branch taken
			IM_addr <= branch_addr - 1; -- branch to new address 
			new_counter <= branch_addr;
			instruction <= (others=>'0'); -- cancel last instruction
		end if;
	end if;
	end process;
	
--	process (prediction_wrong, prediction_correct)
--	begin
--		if(rising_edge(prediction_wrong)) then
--			report "fail, predictor was " & std_logic'image(branch_predictor(prediction_index));
--			case branch_predictor(prediction_index) is
--				When '0' =>
--					branch_predictor(prediction_index) <= '1';
--				When '1' => 
--					branch_predictor(prediction_index) <= '0';
--				When others =>
--					branch_predictor(prediction_index) <= branch_predictor(prediction_index);
--			end case;
--		elsif(rising_edge(prediction_correct)) then
--			report "success, predictor was " & std_logic'image(branch_predictor(prediction_index));
--			case branch_predictor(prediction_index) is
--				When '0' =>
--					branch_predictor(prediction_index) <= '0';
--				When '1' => 
--					branch_predictor(prediction_index) <= '1';
--				When others =>
--					branch_predictor(prediction_index) <= branch_predictor(prediction_index);
--			end case;
--		end if;
--	end process;
end fd;
