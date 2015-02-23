LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

entity functionalProcessor is
	generic(
		clock_period : time := 1 ns
	);
	port (
		clock : in std_logic;
		reset : in std_logic
	);
end functionalProcessor;

architecture behaviour of functionalProcessor is

	-- CONSTANTS --
	Constant Num_Bits_in_Byte	: integer := 8; 
	Constant Num_Bytes_in_Word	: integer := 4; 
	Constant Memory_Size		: integer := 256; 

	-- MULTI-STATE SIGNAL --
	signal currentInstruction : std_logic_vector(Num_Bytes_in_Word*Num_Bits_in_Byte-1 downto 0);
	
	-- FSM --
	type state_type is (init, readInstruction1, readInstruction2, processInstruction, done);
	signal state: state_type:=init;
	
	----------------------
	-- Memory Component --
	----------------------

	-- Instruction Memory signal
	signal programCounter		: integer 	:= 0;
	signal InstMem_word_byte 	: std_logic	:= '1';
	signal InstMem_re 			: std_logic := '0';
	signal InstMem_rd_ready 	: std_logic	:= '0';
	signal InstMem_data 		: std_logic_vector(Num_Bytes_in_Word*Num_Bits_in_Byte-1 downto 0);
	signal InstMem_init 		: std_logic	:= '0';
	signal InstMem_dump 		: std_logic	:= '0';
 
	COMPONENT Main_Memory
		generic (
			File_Address_Read 	: string :="Init.dat";
			File_Address_Write 	: string :="MemCon.dat";
			Mem_Size_in_Word 	: integer:=256;	
			Num_Bytes_in_Word	: integer:=4;
			Num_Bits_in_Byte	: integer := 8; 
			Read_Delay			: integer:=0; 
			Write_Delay			: integer:=0
		 );
		PORT(
			clk 		: IN  std_logic;
			address 	: IN  integer;
			Word_Byte	: in std_logic;
			we 			: IN  std_logic;
			wr_done 	: OUT  std_logic;
			re 			: IN  std_logic;
			rd_ready 	: OUT  std_logic;
			data 		: INOUT  std_logic_vector(Num_Bytes_in_Word*Num_Bits_in_Byte-1 downto 0);
			initialize 	: IN  std_logic;
			dump 		: IN  std_logic
        );
    END COMPONENT;
    
    ----------------------------
	-- Main Control Component --
	----------------------------
	
	-- Main contral signal
	signal MC_RegDst	: std_logic	:= '0';
	signal MC_Jump		: std_logic	:= '0';
	signal MC_Branch	: std_logic	:= '0';
	signal MC_MemRead	: std_logic	:= '0';
	signal MC_MemtoReg	: std_logic	:= '0';
	signal MC_MemWrite	: std_logic	:= '0';
	signal MC_AluSrc	: std_logic	:= '0';
	signal MC_RegWrite	: std_logic	:= '0';
	signal MC_ALUOp		: std_logic_vector(2 downto 0);
	    
	COMPONENT control 
	PORT (
		clock		: in std_logic;
		Instruction	: in std_logic_vector(31 downto 26);
		RegDst		: out std_logic;
		Jump		: out std_logic;
		Branch		: out std_logic;
		MemRead		: out std_logic;
		MemtoReg	: out std_logic;
		MemWrite	: out std_logic;
		AluSrc		: out std_logic;
		RegWrite	: out std_logic;
		ALUOp		: out std_logic_vector(2 downto 0)
	);
	END COMPONENT;
	
	-------------------------
	-- Registers Component --
	-------------------------
	
	-- Registers output signal
	signal regData_1 : std_logic_vector(31 downto 0);
	signal regData_2 : std_logic_vector(31 downto 0);
	
	COMPONENT registers
	port (
		clock		: in std_logic;
		read_reg_1	: in std_logic_vector(4 downto 0);
		read_reg_2	: in std_logic_vector(4 downto 0);
		write_reg	: in std_logic_vector(4 downto 0);
		writedata	: in std_logic_vector(31 downto 0);
		regwrite	: in std_logic;
		readdata_1	: out std_logic_vector(31 downto 0);
		readdata_2	: out std_logic_vector(31 downto 0)
	);
	END COMPONENT;
	
	
	-------------------------------
	-- Mux 2-1 (5bits) Component --
	-------------------------------
	
	-- Mux signals
	signal writeRegisterMuxResult : STD_LOGIC_VECTOR (4 DOWNTO 0);
	
	COMPONENT Mux2_1 
	PORT (
		data0x	: IN STD_LOGIC_VECTOR (4 DOWNTO 0);
		data1x	: IN STD_LOGIC_VECTOR (4 DOWNTO 0);
		sel		: IN STD_LOGIC ;
		result	: OUT STD_LOGIC_VECTOR (4 DOWNTO 0)
	);
	END COMPONENT;
	
	
BEGIN

	------------------------
	-- Instruction Memory --
	------------------------
	InstMem: Main_Memory 
	generic map (
			File_Address_Read 	=>"Init.dat",
			File_Address_Write 	=>"MemCon.dat",
			Mem_Size_in_Word 	=>256,
			Num_Bytes_in_Word	=>4,
			Num_Bits_in_Byte	=>8,
			Read_Delay			=>0,
			Write_Delay			=>0
		 )
		PORT MAP (
			clk 		=> clock,
			address 	=> programCounter,
			Word_Byte 	=> InstMem_word_byte,
			we 			=> '0',
			re 			=> InstMem_re,
			rd_ready 	=> InstMem_rd_ready,
			data 		=> InstMem_data,          
			initialize 	=> InstMem_init,
			dump 		=> InstMem_dump
        );
        
    ----------------------------
	-- Main Control Component --
	----------------------------    
	MainContral : control 
	PORT MAP (
		clock		=> clock,
		Instruction	=> currentInstruction(31 downto 26),
		RegDst		=> MC_RegDst,
		Jump		=> MC_Jump,
		Branch		=> MC_Branch,
		MemRead		=> MC_MemRead,
		MemtoReg	=> MC_MemtoReg,
		MemWrite	=> MC_MemWrite,
		AluSrc		=> MC_AluSrc,
		RegWrite	=> MC_RegWrite,
		ALUOp		=> MC_ALUOp
	);
	
	-------------------------------
	-- Mux 2-1 (5bits) Component --
	-------------------------------
	writeRegisterMux : Mux2_1 
	PORT MAP (
		data0x	=> currentInstruction(20 downto 16),
		data1x	=> currentInstruction(15 downto 11),
		sel		=> MC_RegDst,
		result	=> writeRegisterMuxResult
	);
	
	--------------------
	-- Main Registers --
	--------------------
	MainRegisters : registers
	PORT MAP (
		clock		=> clock,
		read_reg_1	=> currentInstruction(25 downto 21),
		read_reg_2	=> currentInstruction(20 downto 16),
		write_reg	=> writeRegisterMuxResult,
		writedata	=> (OTHERS => '0'), -- TODO CHANGE IT WHEN DATAMEMORY IS IMPLEMENTED
		regwrite	=> MC_RegWrite,
		readdata_1	=> regData_1,
		readdata_2	=> regData_2
	);
        
	
	---------------
	-- FSM LOGIC --
	---------------
	fsm: process (clock)
	begin		
      if(clock'event and clock='1') then
			
			case state is
				when init =>
					InstMem_init 	<= '1'; 
					state 			<= readInstruction1;
					
				when readInstruction1 =>	
					InstMem_re <='1';
					InstMem_init <= '0';
					state <= readInstruction2;				
				
				when readInstruction2 =>
					
					-- state initialisation --
					InstMem_init 	<= '0';
					InstMem_re 		<= '1';

					-- state processing --
					if (InstMem_rd_ready = '1') then -- the output is ready on the memory bus
						state <= processInstruction; 
						currentInstruction <= InstMem_data;
						programCounter <= programCounter + 4; -- update program counter
						InstMem_re <='0';
					else
						state <= readInstruction2; -- stay in this state till you see InstMem_rd_ready='1';
					end if;
					
				when processInstruction =>
					
				
				when others =>
			end case;
			
		end if;
   end process;

end behaviour;