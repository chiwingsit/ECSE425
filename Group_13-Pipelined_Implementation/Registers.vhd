LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

entity registers is
	generic(
		clock_period : time := 1 ns
	);
	port (
		clock		: in std_logic;
		init 		: in std_logic;
		read_reg_1	: in std_logic_vector(4 downto 0);
		read_reg_2	: in std_logic_vector(4 downto 0);
		write_reg	: in std_logic_vector(4 downto 0);
		writedata	: in std_logic_vector(31 downto 0);
		regwrite	: in std_logic;
		readdata_1	: out std_logic_vector(31 downto 0);
		readdata_2	: out std_logic_vector(31 downto 0);
		
		writeLOHI	: in std_logic;
		LOin			: in std_logic_vector(31 downto 0);
		HIin			: in std_logic_vector(31 downto 0);
		LOout			: out std_logic_vector(31 downto 0);
		HIout			: out std_logic_vector(31 downto 0)
	);
end registers;

architecture behaviour of registers is

	constant	reg_width	: integer := 32;
	constant	data_width	: integer := 32;

	type MEM is array(reg_width+1 downto 0) OF std_logic_vector(data_width-1 downto 0);
	signal regs: MEM;
	-- Register 0 : connected to ground
	-- Register 31: return address
	-- Register 32: LO
	-- Register 33: HI
begin

	reg_process: process (clock)
	begin
		if (clock'event AND clock = '1') then
		
			if (init = '1') then
				for i in 0 to reg_width-1 loop 
					regs(i) <= (others => 'Z');
				end loop;
			elsif(regwrite = '1') then
				regs(to_integer(unsigned(write_reg))) <= writedata;
			end if;
			if(writeLOHI = '1') then
				regs(32) <= LOin;
				regs(33) <= HIin;
			end if;

			regs(0) <= "00000000000000000000000000000000";
		end if;
	end process;
	
	readdata_1 <= regs(to_integer(unsigned(read_reg_1)));
	readdata_2 <= regs(to_integer(unsigned(read_reg_2)));
	
	LOout <= regs(32);
	HIout <= regs(33);
	
end behaviour;