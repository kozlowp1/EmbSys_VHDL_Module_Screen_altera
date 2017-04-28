library ieee ;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.all;

entity LCD_Control_bck is 
port(  
		
		signal Clk 		: IN std_logic;
		signal as_nReset	: IN std_logic;

		--interface with fifo
		signal rdreq		: OUT STD_LOGIC ;
		signal sclr		: OUT STD_LOGIC ;
		signal almost_empty	: IN STD_LOGIC ;
		signal almost_full	: IN STD_LOGIC ;
		signal empty		: IN STD_LOGIC ;
		signal full		: IN STD_LOGIC ;
		signal q		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		signal usedw		: IN STD_LOGIC_VECTOR (8 DOWNTO 0);
		--interface with slave/master
		signal DCXi_in : IN STD_LOGIC ;
		signal DATA_CMD_in: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		signal START_in : IN  std_logic ;
		signal STOP_in : IN  std_logic ;
		signal as_write_in : IN  std_logic;
		--interface between lcd control and LCD Driver
		signal DCX : OUT  std_logic ;
		signal WRX : OUT  std_logic ;
		signal CSX : OUT  std_logic ;
		signal LCD_ON : OUT  std_logic ;
		signal RESX : OUT  std_logic ;
		signal RDX : OUT  std_logic ;
		signal DATA_CMD_out: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
				


);
end LCD_Control_bck;

architecture behav of LCD_Control_bck is  

  signal DATA_CMD_register: STD_LOGIC_VECTOR (15 DOWNTO 0);
  --FSM-Transfer of CMD/Data--------
  --------------
  TYPE State_type2 IS (IDLE2,ST1_DATAREG_LOW,ST2_DATAREG_LOW,
ST3_DATAREG_HIGH,ST4_DATAREG_HIGH,ST1_DATAPIX_LOW,ST2_DATAPIX_LOW,ST3_DATAPIX_HIGH,
ST4_DATAPIX_HIGH,ST1_CMD_LOW,ST2_CMD_LOW, ST3_CMD_HIGH,ST4_CMD_HIGH,FINISH_ST);
	SIGNAL State2,NextState2 : State_Type2;  

  signal CSX_reg:  std_logic ; 
  signal DCX_reg:  std_logic ; 
  signal WRX_reg:  std_logic ; 
  signal finished:  std_logic ; 

  --FSM-Transfer of pixels from fifo--------
  --------------
  TYPE State_type3 IS (IDLE3, CHECK, SEND_PIXEL,SEND_PIXEL2,SEND_PIXEL3,SEND_PIXEL4_DELAY);  
	SIGNAL State3,NextState3 : State_Type3;  
  signal start_transfer_of_pixel:  std_logic ; 

  --needed for the mux (mux is used to choose the source of data - slave register or fifo)
  signal sel:  std_logic ; 
begin
--DATA_CMD_out<=DATA_CMD_register;
DATA_CMD_out<=DATA_CMD_register;
RDX<='1';
DCX<=DCX_reg;
WRX<=WRX_reg;
CSX<=CSX_reg;
LCD_ON<='1';
RESX<=as_nReset;
sclr<='0';
--MUX
mux : process(sel,q,DATA_CMD_in) is
begin
	case sel is 
	when '0' => DATA_CMD_register <= DATA_CMD_in;
	when '1' => DATA_CMD_register <= q;
	when others => DATA_CMD_register <= DATA_CMD_in;
	end case;
end process mux;
	


--Sending Commands/data to LCD Controller
--1.Send Data/CMD FSM


PROCESS (Clk,as_nReset,State2,as_write_in,start_transfer_of_pixel,DCXi_in) 
  BEGIN 

 if (as_nReset ='0') then
	State2 <= IDLE2;
 elsif rising_edge(Clk) then
	CASE State2 IS
		WHEN IDLE2 => 
			IF as_write_in ='1' and start_transfer_of_pixel='0' and DCXi_in = '0' THEN
				
				--it is cmd that has to be transferred
				DCX_reg<='0';
				WRX_reg<='0';
				CSX_reg<='0';
				finished<='0';
				State2 <= ST1_CMD_LOW;
				sel<='0';
			ELSIF as_write_in ='1' and start_transfer_of_pixel='0' and DCXi_in='1'  THEN 
				--it is data 
				DCX_reg<='1';
				WRX_reg<='0';
				CSX_reg<='0';
				State2 <= ST1_DATAREG_LOW;	
				finished<='0';
				sel<='0';
			ELSIF as_write_in ='0' and start_transfer_of_pixel='1' and DCXi_in='1' THEN
				--it is pixel
				DCX_reg<='1';
				WRX_reg<='0';
				CSX_reg<='0';
				State2 <= ST1_DATAPIX_LOW;
				--The data is assigned in another process
				finished<='0';
				sel<='1';
			Else 
				finished<='1';
				DCX_reg<='1';
				CSX_reg<='1';
				WRX_reg<='1';
				State2 <=IDLE2;
				sel<='0';
			END IF; 
		WHEN ST1_DATAREG_LOW =>  
			DCX_reg<='1';
			WRX_reg<='0';
			CSX_reg<='0';
			sel<='0'; 
			State2 <= ST2_DATAREG_LOW;
			finished<='0';
		WHEN ST2_DATAREG_LOW => 
			DCX_reg<='1';
			CSX_reg<='0'; 
			WRX_reg<='1';
			sel<='0'; 
			State2 <= ST3_DATAREG_HIGH;
			finished<='0';
		WHEN ST3_DATAREG_HIGH => 
			DCX_reg<='1';
			CSX_reg<='0'; 
			WRX_reg<='1';
			sel<='0'; 
			State2 <= ST4_DATAREG_HIGH;
			finished<='0';
		WHEN ST4_DATAREG_HIGH => 
			DCX_reg<='1';
			CSX_reg<='1';
			WRX_reg<='1';
			sel<='0';
			State2 <= FINISH_ST;
			finished<='0';
		WHEN ST1_DATAPIX_LOW =>  
			DCX_reg<='1';
			WRX_reg<='0';
			CSX_reg<='0';
			sel<='1'; 
			State2 <= ST2_DATAPIX_LOW;
			finished<='0';
		WHEN ST2_DATAPIX_LOW => 
			DCX_reg<='1';
			CSX_reg<='0'; 
			WRX_reg<='1';
			sel<='1'; 
			State2 <= ST3_DATAPIX_HIGH;
		WHEN ST3_DATAPIX_HIGH => 
			DCX_reg<='1';
			CSX_reg<='0'; 
			WRX_reg<='1';
			sel<='1'; 
			State2 <= ST4_DATAPIX_HIGH;
		WHEN ST4_DATAPIX_HIGH => 
			DCX_reg<='1';
			CSX_reg<='1';
			WRX_reg<='1';
			sel<='1';
			State2 <= FINISH_ST;
		WHEN ST1_CMD_LOW => 
			DCX_reg<='0';
			WRX_reg<='0';
			CSX_reg<='0';
			sel<='0'; 
			State2 <= ST2_CMD_LOW;
		WHEN ST2_CMD_LOW =>  
			DCX_reg<='0';
			CSX_reg<='0'; 
			WRX_reg<='1';
			sel<='0'; 
			State2 <= ST3_CMD_HIGH;
		WHEN ST3_CMD_HIGH => 
			DCX_reg<='0';
			CSX_reg<='0'; 
			WRX_reg<='1';
			sel<='0'; 
			State2 <= ST4_CMD_HIGH;
		WHEN ST4_CMD_HIGH => 
			DCX_reg<='1';
			CSX_reg<='1';
			WRX_reg<='1';
			sel<='0';
			State2 <= FINISH_ST;
		WHEN FINISH_ST => 
			State2 <= IDLE2;
			DCX_reg<='1';
			CSX_reg<='1';
			WRX_reg<='1';
			sel<='0';
			--finished<='0'; -- now the second FSM might transfer another pixel
		WHEN others =>
			DCX_reg<='1';
			CSX_reg<='1';
			WRX_reg<='1';
			sel<='0';
			State2 <=IDLE2;
			--finished<='1';
	END CASE;
	else
		null; 
     end if;
  END PROCESS;

--2.
-- Sending pixels from fifo to lcd driver
--  TYPE State_type3 IS (IDLE3, CHECK, SEND_PIXEL);  
--	SIGNAL State3,NextState3 : State_Type3;  
--


 PROCESS (Clk,as_nReset,State3,empty,finished,STOP_in,START_in) 
   BEGIN 
 if (as_nReset ='0') then
	State3 <= IDLE3;
 elsif rising_edge(Clk) then
	CASE State3 IS
		WHEN IDLE3 =>
			rdreq<='0'; 
			start_transfer_of_pixel<='0';
			IF START_in ='1' THEN
				State3<=CHECK;
			Else 
				State3 <=IDLE3;
			END IF;
		WHEN CHECK =>
			start_transfer_of_pixel<='0';   
			IF empty='0' and finished='1' and (STOP_in='1' or STOP_in='0')  THEN
				rdreq<='1';
				State3<=SEND_PIXEL;
			ELSIF  empty='1' and STOP_in='1' and finished='1' THEN
				rdreq<='0';
				State3<=IDLE3;
			Else 
				rdreq<='0';
				State3<=CHECK;
			END IF;
		WHEN SEND_PIXEL =>
			rdreq<='0';
			State3<=SEND_PIXEL2;
			start_transfer_of_pixel<='1';
		WHEN SEND_PIXEL2 =>
			rdreq<='0';
			State3<=SEND_PIXEL3;
			start_transfer_of_pixel<='1';
		WHEN SEND_PIXEL3 =>
			rdreq<='0';
			State3<=SEND_PIXEL4_DELAY;
			start_transfer_of_pixel<='1';
		WHEN SEND_PIXEL4_DELAY =>
			rdreq<='0';
			State3<=CHECK;
			start_transfer_of_pixel<='1';
		WHEN others =>
			rdreq<='0';
			State3<=IDLE3;
			start_transfer_of_pixel<='0';
	END CASE; 
	else
null; 
     end if; 
  END PROCESS;
end behav;

