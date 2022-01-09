LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

-- Xiaozhou Liao, 260668818
-- Xu Hai, 260661832
-- Tingzhe Wang,260687154
entity ID_datapath is
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
end ID_datapath;

architecture dd of ID_datapath is
	signal reg_dest_i: std_logic_vector(4 downto 0);
	type REGS is array(31 downto 0) of STD_LOGIC_VECTOR(31 downto 0);
	signal reg: REGS:= (others=>(others=>'0'));
	signal a_reg,b_reg:  std_logic_vector(4 downto 0):=(others=>'0');
	signal inst_id_i : integer;
	
	begin		
		-- write back
		reg(to_integer(unsigned(wb_addr))) <= wb_data when wb = '1';
		
		-- write to file
		id_data <= reg(id_addr) when id_read = '1';
		
		-- forwarding
		a <=	(others=>'0')	when flush = '1' else
			EX_forward_data	when (EX_forward = '1' and EX_forward_reg = a_reg) else
			MEM_forward_data	when (MEM_forward = '1' and MEM_forward_reg = a_reg) else
			(others=>'0')		when a_reg = "00000" else	
			reg(to_integer(unsigned(a_reg))); 
		b <=	(others=>'0')	when flush = '1' else
			EX_forward_data	when (EX_forward = '1' and EX_forward_reg = b_reg) else
			MEM_forward_data	when (MEM_forward = '1' and MEM_forward_reg = b_reg) else
			(others=>'0')		when b_reg = "00000" else
			reg(to_integer(unsigned(b_reg)));

		-- assign result to output
		reg_dest <= reg_dest_i when flush = '0' else
				  (others=>'0'); 
		inst_id <= inst_id_i when flush = '0' else
				  0; 
		
		-- wire reg(0) to 0
		reg(0) <= (others => '0');
		
		process (clk)
		variable opcode,func: std_logic_vector(5 downto 0);
		variable rs,rt,rd: std_logic_vector(4 downto 0);
		variable imm: std_logic_vector(15 downto 0);
		begin
			if(clk'event and clk = '1') then   
				if(stall_in = '1') then
					stall_out <= '1';
				else
					stall_out <= '0';
					counter_out <= counter_in;
					shamt <= instruction(10 downto 6);
					j_addr <= instruction(25 downto 0);
					predict_taken_out <= predict_taken_in;
					
					rs := instruction(25 downto 21);
					rt := instruction(20 downto 16);
					rd := instruction(15 downto 11);
					opcode := instruction(31 downto 26);
					func := instruction(5 downto 0);
					imm := instruction(15 downto 0);
					
					if(opcode = "000000") then -- R-type
						case func is
							when "100000" => -- add
								a_reg <= rs;
								b_reg <= rt;
								reg_dest_i <=  rd; 	
								reg_used <= "11";
								inst_id_i <= 0;
							when "100010" => -- sub
								a_reg <= rs;
								b_reg <= rt;
								reg_dest_i <=  rd; 
								reg_used <= "11";
								inst_id_i <= 1;
							when "011000" => -- mult
								a_reg <= rs;
								b_reg <= rt;
								reg_used <= "11";
								inst_id_i <= 3;
							when "011010" => -- div
								a_reg <= rs;
								b_reg <= rt;	
								reg_used <= "11";
								inst_id_i <= 4;
							when "101010" => -- slt
								a_reg <= rs;
								b_reg <= rt;	
								reg_dest_i <=  rd; 	
								reg_used <= "11";
								inst_id_i <= 5;
							when "100100" => -- and
								a_reg <= rs;
								b_reg <= rt;	
								reg_dest_i <=  rd; 	
								reg_used <= "11";
								inst_id_i <= 7;
							when "100101" => -- or
								a_reg <= rs;
								b_reg <= rt;	
								reg_dest_i <=  rd; 
								reg_used <= "11";
								inst_id_i <= 8;
							when "100111" => -- nor
								a_reg <= rs;
								b_reg <= rt;	
								reg_dest_i <=  rd;  	
								reg_used <= "11";
								inst_id_i <= 9;
							when "100110" => -- xor
								a_reg <= rs;
								b_reg <= rt;	
								reg_dest_i <=  rd;  	
								reg_used <= "11";
								inst_id_i <= 10;
							when "010000" => -- mfhi
								reg_dest_i <=  rd;
								reg_used <= "00";
								inst_id_i <= 14;
							when "010010" => -- mflo
								reg_dest_i <=  rd;	
								reg_used <= "00";
								inst_id_i <= 15;
							when "000000" => -- sll
								a_reg <= rt; 
								reg_dest_i <=  rd;
								reg_used <= "10";
								inst_id_i <= 17;
							when "000010" => -- srl
								a_reg <= rt; 
								reg_dest_i <=  rd;
								reg_used <= "10";
								inst_id_i <= 18;
							when "000011" => -- sra
								a_reg <= rt; 
								reg_dest_i <=  rd; 	
								reg_used <= "10";
								inst_id_i <= 19;
							
							when "001000" => -- jr
								a_reg <= rs;
								reg_used <= "10";
								inst_id_i <= 25;
							when others => -- non-supported cmds
								a_reg <= (others => '0');
								b_reg <= (others => '0');
								reg_dest_i <=  (others => '0');	
								reg_used <= (others => '0');
								inst_id_i <= 0;
						end case;
					elsif(opcode = "000010") then -- j
						reg_used <= "00";
						inst_id_i <= 24;
					elsif(opcode = "000011") then -- jal
						reg_used <= "00";
						inst_id_i <= 26;
					else
						case opcode is
							when "001000" => -- addi
								a_reg <= rs;
								reg_dest_i <=  rt; 	
								reg_used <= "10";
								inst_id_i <= 2;
							when "001010" => -- slti
								a_reg <= rs;
								reg_dest_i <= rt; 
								reg_used <= "10";
								inst_id_i <= 6;
							when "001100" => -- andi
								a_reg <= rs;
								reg_dest_i <= rt; 	
								reg_used <= "10";
								inst_id_i <= 11;
							when "001101" => -- ori
								a_reg <= rs;
								reg_dest_i <= rt; 	
								reg_used <= "10";
								inst_id_i <= 12;
							when "001110" => -- xori
								a_reg <= rs;
								reg_dest_i <= rt;  	
								reg_used <= "10";
								inst_id_i <= 13;
							when "001111" => -- lui
								reg_dest_i <=  rt;
								reg_used <= "00";
								inst_id_i <= 16;
							when "100011" => -- lw
								a_reg <= rs;
								reg_dest_i <=  rt;
								reg_used <= "10";
								inst_id_i <= 20;
							when "101011" => -- sw
								a_reg <= rs;
								b_reg <= rt;
								reg_used <= "11";
								inst_id_i <= 21;
							
							when "000100" => -- beq
								a_reg <= rs;
								b_reg <= rt;	
								reg_used <= "11";
								inst_id_i <= 22;
							when "000101" => -- bne
								a_reg <= rs;
								b_reg <= rt;		
								reg_used <= "11";
								inst_id_i <= 23;
							when others => -- non-supported cmds
								a_reg <= (others => '0');
								b_reg <= (others => '0');
								reg_dest_i <=  (others => '0');	
								reg_used <= (others => '0');
								inst_id_i <= 0;
						end case;
					end if; 
					
					a_reg_out <= a_reg;
					b_reg_out <= b_reg;
						
					if(inst_id_i = 11 or inst_id_i = 12 or inst_id_i = 13) then -- imm logical cmds
						extended_imm <= (31 downto 16 => '0') & imm; -- zero extended
					else -- other imm cmds
						extended_imm <= (31 downto 16 => imm(15)) & imm; -- sign extended
					end if;	
				end if;
			end if;
		end process;
end dd;
		
