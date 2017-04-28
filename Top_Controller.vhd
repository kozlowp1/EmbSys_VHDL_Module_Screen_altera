library ieee ;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.all;

entity Top_Controller is 
port(  
 --slave interface
 Clk : IN std_logic;
 as_nReset : IN std_logic;
 as_Address : IN std_logic_vector (2 DOWNTO 0);
 as_ChipSelect : IN std_logic;
 as_Read : IN std_logic;
 as_Write : IN std_logic;
 as_ReadData : OUT std_logic_vector (31 DOWNTO 0);
 as_WriteData : IN std_logic_vector (31 DOWNTO 0);

 -- master interface
  signal am_address : out std_logic_vector(31 downto 0);
  signal am_byteEenable : out std_logic_vector(3 downto 0);
  signal am_read : out std_logic;
  signal am_readData : in std_logic_vector(31 downto 0);
  signal am_write : out std_logic;
  signal am_writeData : out std_logic_vector(31 downto 0);
  signal am_waitrequest : in std_logic;
  signal am_ReadDataValid : in std_logic;
  signal am_BurstCount : out std_logic_vector(7 downto 0);

 --Controller out interface
  signal DCX : OUT  std_logic ;
  signal WRX : OUT  std_logic ;
  signal CSX : OUT  std_logic ;
  signal LCD_ON : OUT  std_logic ;
  signal RESX : OUT  std_logic ;
  signal DATA_CMD_out: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
  signal RDX : OUT  std_logic 


);
end Top_Controller;
architecture behav of Top_Controller is  
		
		--inner signals
		--between master and fifo		
		signal data_sig			:  STD_LOGIC_VECTOR (15 DOWNTO 0);
		signal rdreq_sig		:  STD_LOGIC ;
		signal sclr_sig			:  STD_LOGIC ;
		signal wrreq_sig		:  STD_LOGIC ;
		signal almost_empty_sig		:  STD_LOGIC ;
		signal almost_full_sig		:  STD_LOGIC ;
		signal empty_sig		:  STD_LOGIC ;
		signal full_sig			:  STD_LOGIC ;
		signal q_sig			:  STD_LOGIC_VECTOR (15 DOWNTO 0);
		signal usedw_sig		:  STD_LOGIC_VECTOR (8 DOWNTO 0);
		--between master interface and lcd control
		signal DCXi_sig 		: STD_LOGIC ;
		signal DATA_CMD_sig		: STD_LOGIC_VECTOR (15 DOWNTO 0);
		signal START_sig		:  std_logic ;
		signal STOP_sig 		:  std_logic ;
		signal as_write_sig 		:  std_logic ;


begin
 
fifo_inst : entity work.fifo(SYN) PORT MAP (
		clock	 => Clk,
		data	 => data_sig,
		rdreq	 => rdreq_sig,
		sclr	 => sclr_sig,
		wrreq	 => wrreq_sig,
		almost_empty	 => almost_empty_sig,
		almost_full	 => almost_full_sig,
		empty	 => empty_sig,
		full	 => full_sig,
		q	 => q_sig,
		usedw	 => usedw_sig
	);

   
MasterSlaveInterface : entity work.MasterSlaveInterface(behav) PORT MAP(  
 	--slave interface to top level
 	Clk => Clk,
	as_nReset =>as_nReset,
 	as_Address => as_Address,
 	as_ChipSelect => as_ChipSelect,
 	as_Read => as_Read,
 	as_Write => as_Write,
	as_ReadData => as_ReadData,
 	as_WriteData => as_WriteData,
		
 	-- master interface to top level
   	am_address  => am_address,
   	am_byteEenable  => am_byteEenable,
   	am_read  => am_read,
   	am_readData  => am_readData,
   	am_write  => am_write,
   	am_writeData  => am_writeData,
   	am_waitrequest  => am_waitrequest,
   	am_ReadDataValid  => am_ReadDataValid,
   	am_BurstCount  => am_BurstCount,


 	--interface to fifo
   	f_almost_full  => almost_full_sig,
   	wrreq	 => wrreq_sig,
   	f_empty	 => empty_sig,
   	f_data	 => data_sig,
   	f_usedw	 => usedw_sig,

 	--interface to LCD Control
     	DCXi_out  => DCXi_sig,
	DATA_CMD_out => DATA_CMD_sig,
	START_out => START_sig,
	STOP_out => STOP_sig,
	as_write_out => as_write_sig

);

		
LCD_Control : entity work.LCD_Control(behav) PORT MAP (
		--interface with fifo
		Clk	 		=> Clk,
		as_nReset 		=> as_nReset,
		rdreq	 		=> rdreq_sig,
		almost_empty		=> almost_empty_sig,
		almost_full		=> almost_full_sig,
		empty	 		=> empty_sig,
		full			=> full_sig,
		q	 		=> q_sig,
		usedw			=> usedw_sig,
   		sclr	 		=> sclr_sig,
		--interface with master interface 
		DCXi_in	 		=> DCXi_sig,
		DATA_CMD_in	 	=> DATA_CMD_sig,
		START_in	 	=> START_sig,
		STOP_in	 		=> STOP_sig,
		as_write_in 		=> as_write_sig,
		--interface between Controller and ILI9341
		DCX 			=>DCX,
		WRX 			=>WRX,
		CSX			=>CSX,
		DATA_CMD_out		=>DATA_CMD_out,
		RESX			=>RESX,
		LCD_ON			=>LCD_ON,
		RDX			=>RDX

	);


end behav;

