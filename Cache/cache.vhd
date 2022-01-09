library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Xiaozhou Liao, 260668818
-- Xu Hai, 260661832
-- Tingzhe Wang,260687154
entity cache is
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
end cache;

architecture arch of cache is
  
type state_type is (init, idle, check, read_buff, read_from_cache, write_to_cache, mem_to_cache, cache_to_mem);
signal state : state_type;

--Cache definition
type word is array(3 downto 0) OF STD_LOGIC_VECTOR(7 downto 0); -- one word is 4 bytes
type block_data is array(3 downto 0) of word; -- data in one block is 4 word
--Arrays storing data, tags and flags
type tag_array is array(31 downto 0) of integer;
type dirty_bit_arr is array(31 downto 0) of std_logic;
type valid_bit_arr is array(31 downto 0) of std_logic;
type cache_mem is array(31 downto 0) of block_data; -- one cache has 32 blocks

--Instantiate cache
signal cache_instance : cache_mem; 
signal tag_arr : tag_array;
signal dirty_bit : dirty_bit_arr;
signal valid_bit : valid_bit_arr;

--Internal signals
signal counter : integer; -- counter used for data transfer between cache and main memory
signal offset_count : integer; -- counter used for reading a block of data from memory
signal word_buffer : word; -- buffer used for bytes to word
signal prev_data : std_logic_vector(7 downto 0); -- storing the last value read from memory

begin

process(clock)
variable tag_matched : std_logic := '0'; -- boolean represent if the input tag matches the tag in the block
variable input_tag : integer; -- tag in the input address
variable index : integer; -- index in the input address
variable word_offset : integer; -- offset in the input address
variable read_address : integer; -- the integer form of the valid part of the input address used to read from memory
variable write_address : integer; -- corresponding memory address of the block with input index for write to memory
begin
	if reset = '1' then
		counter <= 0;
		offset_count <= 0;
		s_waitrequest <= '1'; 
		prev_data <= "00000001";
		for i in 0 to 31 loop -- init the cache
			valid_bit(i) <= '0';
		end loop;
		state <= idle;
	elsif clock'event and clock = '1' then
		case state is
			when init => -- first state before starting receive requests
			for i in 0 to 31 loop -- init the cache by set all valid bits to '0'
				valid_bit(i) <= '0';
			end loop;
			state <= idle;

			when idle => -- idle state, waiting for new request
			s_waitrequest <= '1'; 
			-- reset signals 
			counter <= 0;
			offset_count <= 0;
			prev_data <= "00000001";
			-- forwarding once request received
			if((s_read='1' or s_write='1') and m_waitrequest = '1') then 
				state <= check;
        		end if;
	  
     		when check => -- check flags to determine which action to be taken
			--Assign values to variables
			read_address := to_integer(unsigned(s_addr(14 downto 0))) - (to_integer(unsigned(s_addr(14 downto 0))) mod 32);
			input_tag := to_integer(unsigned(s_addr(14 downto 0))) / 32;
			index := (to_integer(unsigned(s_addr(14 downto 4))) mod 32);
			word_offset := to_integer(unsigned(s_addr(3 downto 2)));
			write_address := (tag_arr(index) * 32 + index) * 4 + word_offset;

			s_waitrequest <= '0'; -- stop receive new req
			if(tag_arr(index)=input_tag) then -- check if tag matched
            	tag_matched := '1';
			else 
				tag_matched := '0';
			end if;

			if(s_read='1') then
				if(valid_bit(index)='1' and tag_matched='1') then
					state <= read_from_cache; -- directly read the requested data from cahce since the data is valid and tag matched
				elsif(dirty_bit(index)='1') then
					state <= cache_to_mem; -- save the modified data before load new data from memory
				else
					-- otherwise need to get the data from main memory first
					m_addr <= read_address + counter + offset_count *4;
					state <= read_buff;
		  		end if;
			else -- s_write='1'
		  		if(dirty_bit(index)='0' or tag_matched='1') then
					state <= write_to_cache; -- directly write to cache since the data was not modified before and tag matched
		  		else
					state <= cache_to_mem; -- otherwise need to save the data to main memory before writing
		  		end if;
			end if;

			when mem_to_cache => -- read data from memory to cache
			if(prev_data/=m_readdata) then 
				if(counter < 4) then -- read for 4 clock cycles 1 byte per each
					prev_data <= m_readdata;	
					word_buffer(counter) <= m_readdata; -- store the read byte to a word buffer
					counter <= counter + 1;	
					state <= read_buff;
				else
					counter <= 0;
					if(offset_count < 4) then -- check if there is another word to read
						cache_instance(index)(offset_count) <= word_buffer; -- store the data to cache from buffer
						offset_count <= offset_count + 1;
						state <= read_buff;
					end if;			
				end if;
			else
			end if;

			when read_buff => -- buffer state for mem_to_cache
			m_addr <= read_address + counter + offset_count *4; -- update address
			m_read <= '1';
			state <= mem_to_cache;
			if(offset_count = 4) then -- finish the reading form memory process
				valid_bit(index) <= '1'; -- assert valid
				tag_arr(index) <= input_tag; -- update tag
				state <= read_from_cache; -- now the requested data is in the cache, perform read from cache
			end if;

			when read_from_cache =>
			s_readdata <= cache_instance(index)(word_offset)(3)&
					  cache_instance(index)(word_offset)(2)&
					  cache_instance(index)(word_offset)(1)&
					  cache_instance(index)(word_offset)(0); -- read the requested word which consists 4 bytes
			state <= idle;
			s_waitrequest <= '1'; 

			when cache_to_mem => -- store data from cache to memory
			m_addr <= write_address;
			if(counter < 4) then -- write for 4 clock cycles 1 byte per each
				m_writedata <= cache_instance(index)(word_offset)(counter); -- write the data in cache byte by byte
				m_write <= '1';
				counter <= counter + 1;
				m_addr <= write_address + counter;
			elsif(s_write='1') then
				state <= write_to_cache; -- now the previously modified data has been stored, safe to perform write to cache
			else -- s_read='1'
				state <= mem_to_cache; -- now the previously modified data has been stored, safe to read from memory
			end if;

			when write_to_cache => 
			-- store the input word 
			cache_instance(index)(word_offset)(0) <= s_writedata(7 downto 0);
			cache_instance(index)(word_offset)(1) <= s_writedata(15 downto 8);
			cache_instance(index)(word_offset)(2) <= s_writedata(23 downto 16);
			cache_instance(index)(word_offset)(3) <= s_writedata(31 downto 24);
			-- assert valid and dirty bits
			valid_bit(index) <= '1';
			dirty_bit(index) <= '1';
			-- update tag
			tag_arr(index) <= input_tag;
			state <= idle;
			s_waitrequest <= '1'; 
	end case;
	end if;
end process;    

end arch;
