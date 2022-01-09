LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

-- Xiaozhou Liao, 260668818
-- Xu Hai, 260661832
-- Tingzhe Wang,260687154
entity EX_datapath is
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
end EX_datapath;

architecture ed of EX_datapath is
signal h_p : std_logic_vector (31 downto 0);
signal l_p : std_logic_vector (31 downto 0);
signal a_reg_i, b_reg_i, reg_dest_i: std_logic_vector (4 downto 0):=(others=>'0');
signal inst_id_i : integer;

begin

	-- is load need to stall
	lw_hazard <= '1'	when ((inst_id_i = 20) and (reg_used(1) = '1') and (reg_dest_i = a_reg)) else
			'1'				when ((inst_id_i = 20) and (reg_used(0) = '1') and (reg_dest_i = b_reg)) else
			'0';

	clk_process: process (clk)
	variable int_reg_a : integer;
	variable int_reg_b : integer;
	variable result_i : integer := 0;
	variable int_immediate : integer := 0;
	variable int_shamt : integer := 0;
	variable temp: std_logic_vector (63 downto 0);
	begin

		if(clk'event and clk = '1') then
			counter_jal <= counter;	
			
			int_reg_a := to_integer(signed(a));
			int_reg_b := to_integer(signed(b));
			int_immediate := to_integer(signed(immediate));
			int_shamt := to_integer(signed(shamt));

			-- forward from mem
			if(lw_forward= '1') then
				if(a_reg_i = load_reg) then 
					int_reg_a := to_integer(signed(load_data));
				end if;
				if(b_reg_i = load_reg) then
					int_reg_b := to_integer(signed(load_data));
				end if;
			end if;

			flush <= '0';

			if(stall = '1') then
				result_i := 0;
				stall_out <= '1';
				result <= std_logic_vector(to_signed(result_i, 32));
			
			else	
				inst_id_out <= inst_id;
				b_out <= b;
				stall_out <= '0';
				reg_dest_out <= reg_dest_in;
				
				if(inst_id=20 or inst_id=21 or inst_id=22 or inst_id=23 or inst_id=24 or inst_id=25) then		
					EX_forward <= '0';
				else
					EX_forward <= '1';
				end if;

				inst_id_i <= inst_id;
				reg_dest_i <= reg_dest_in;
				a_reg_i <= a_reg;
				b_reg_i <= b_reg;
			
				case inst_id is
					when 0 => -- ADD
						result_i := int_reg_a + int_reg_b;
						result <= std_logic_vector(to_signed(result_i, 32));
						
					when 1 => -- SUB
						result_i := int_reg_a - int_reg_b;
						result <= std_logic_vector(to_signed(result_i, 32));
						
					when 2 => -- ADDI
						result_i := int_reg_a + int_immediate;
						result <= std_logic_vector(to_signed(result_i, 32));
						
					when 3 => -- MULT
						result_i := int_reg_a * int_reg_b;
						temp := std_logic_vector(to_signed(result_i, 64));
						h_p <= temp(63 downto 32);
						l_p <= temp(31 downto 0);
						
					when 4 => -- DIV
						result_i := int_reg_a / int_reg_b;
						l_p <= std_logic_vector(to_signed(result_i, 32));
						result_i := int_reg_a mod int_reg_b;
						h_p <= std_logic_vector(to_signed(result_i, 32));
						
					when 5 => -- SLT
						if (int_reg_a < int_reg_b) then
							result_i := 1;
						else
							result_i := 0;
						end if;
						result <= std_logic_vector(to_signed(result_i, 32));
						
					when 6 => -- SLTI
						if(int_reg_a < int_immediate) then
							result_i := 1;
						else
							result_i := 0;
						end if;
						result <= std_logic_vector(to_signed(result_i, 32));
						
					when 7 => -- AND
						result <= a and b;
						
					when 8 => -- OR
						result <= a or b;
						
					when 9 => -- NOR
						result <= a nor b;
						
					when 10 => -- XOR
						result <= a xor b;
						
					when 11 => -- ANDI
						result <= a and immediate;
						
					when 12 => -- ORI
						result <= a or immediate;
						
					when 13 => -- XORI
						result <= a xor immediate;
						
					when 14 => -- MFHI
						result <= h_p;
						
					when 15 => -- MFLO
						result <= l_p;
						
					when 16 => -- LUI
						result <= immediate(15 downto 0) & "0000000000000000";
						
					when 17 => -- SLL
						result <= std_logic_vector(signed(a) sll int_shamt);
						
					when 18 => -- SRL
						result <= std_logic_vector(signed(a) srl int_shamt);
						
					when 19 => -- SRA
						result <= std_logic_vector(shift_right(signed(a), int_shamt));
						
					when 20 => -- LW
						result_i := int_reg_a + int_immediate;
						result <= std_logic_vector(to_signed(result_i, 32));
						
					when 21 => -- SW
						result_i := int_reg_a + int_immediate;
						result <= std_logic_vector(to_signed(result_i, 32));
						
					when 22 => -- BEQ
						prediction_index <= counter;
						if(predict_taken = '1' and int_reg_a /= int_reg_b) then
							flush <= '1';
							counter_out <= counter + 2;
						end if;
						if(predict_taken = '0' and int_reg_a = int_reg_b) then
							flush <= '1';
							counter_out <= counter + int_immediate + 2;
						end if;
						if((predict_taken = '0' and int_reg_a = int_reg_b) OR (predict_taken = '1' and int_reg_a /= int_reg_b)) then
							prediction_wrong <= '1';
						else
							prediction_correct <= '1';
						end if;
						
					when 23 => -- BNE
						prediction_index <= counter;
						if(predict_taken = '1' and int_reg_a = int_reg_b) then
							flush <= '1';
							counter_out <= counter + 2;
						end if;
						if(predict_taken = '0' and int_reg_a /= int_reg_b) then
							flush <= '1';
							counter_out <= counter + int_immediate + 2;
						end if;
						if( (predict_taken = '0' and int_reg_a /= int_reg_b) OR (predict_taken = '1' and int_reg_a = int_reg_b)) then
							prediction_wrong <= '1';
						else
							prediction_correct <= '1';
						end if;
						
					when 24 => -- J
						flush <= '1';
						counter_out <= to_integer(signed(j_addr))+1;
						
					when 25 => -- JR
						flush <= '1';
						counter_out <= int_reg_a+1;
						
					when 26 => -- JAL
						flush <= '1';
						counter_out <= to_integer(signed(j_addr))+1;
						
					when others => NULL;
				end case;
			end if;
		end if;
		
		if(clk'event and clk = '0') then
			prediction_wrong <= '0';	
			prediction_correct <= '0';
		end if;
	end process;
end ed;
