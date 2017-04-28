library ieee ;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.all;

entity MasterSlaveInterface is 
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

 --interface to fifo
  signal f_almost_full  : in std_logic;
  signal wrreq		: OUT STD_LOGIC ;
  signal f_empty	: IN STD_LOGIC ;
  signal f_data		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
  signal f_usedw	: IN STD_LOGIC_VECTOR (8 DOWNTO 0);

 --interface to LCD Control
	signal DCXi_out : OUT STD_LOGIC ;
	signal DATA_CMD_out: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
	signal START_out : OUT  std_logic ;
	signal STOP_out : OUT  std_logic ;
	signal as_write_out : OUT  std_logic 



);
end MasterSlaveInterface;

architecture behav of MasterSlaveInterface is  
  --registers---
  --------------
  signal StartAddress: std_logic_vector(31 downto 0);
  signal PictureLength: std_logic_vector(31 downto 0); -- state
  signal StartAddress_modified: std_logic_vector(31 downto 0);
  signal PictureLength_modified: std_logic_vector(31 downto 0); -- state
  signal DATA_CMD: std_logic_vector(15 downto 0);
  signal START:  std_logic ;      --to start FSM  
  signal STOP:  std_logic ;      --to stop FSM 
  signal DCXi:  std_logic ;      --to indicate if it is a command or argument
  --signal switch: std_logic ;     -- to trigger fsm every cycle

  --FSM-Loading FIFO--------
  --------------
  TYPE State_type IS (IDLE, WAITING, MASTER_BURST,WAITING_EXTENDED,FINISHED);  
	SIGNAL State,NextState : State_Type;  
  --used for the control of the burst
  signal burst_cycles_left : unsigned(7 downto 0); -- the cycles that have left to do to finish one burst
  signal burstIntermediate: std_logic_vector(15 downto 0); -- used for conversion from 32 to 16 bit 
  signal burstMode:  std_logic ;
  signal asserted:  std_logic ;
  --used for the slave interface (conversion to vector)
  signal as_ReadData_t : std_logic_vector(31 downto 0);

  





begin
--signals that need initalisation

f_data<=burstIntermediate;
DCXi_out<=DCXi;
DATA_CMD_out<=DATA_CMD;
START_out<=START;
STOP_out<=STOP;
am_byteEenable<="1111";



PROCESS (Clk,as_nReset,PictureLength_modified) 
  BEGIN 
        if as_nReset='0' then   
                STOP <= '0';
 	elsif rising_edge(Clk) then
 		if unsigned( PictureLength_modified )=0 then
			STOP<='1';
		else
			null;
		end if;
 	end if;
END PROCESS;

PROCESS (Clk,as_nReset,State,START,f_empty,f_almost_full,STOP,am_ReadDataValid) 
  BEGIN 
--wrreq - signal to send data to fifo


 if (as_nReset ='0') then
	State <= IDLE;	
 elsif rising_edge(Clk) then
wrreq<='0';
am_read<='0';
burstMode<='0';
am_address<=StartAddress_modified;
am_BurstCount<=std_logic_vector(to_unsigned(16, am_BurstCount'length)); 
am_read<='0';
burstIntermediate <= am_readData(20 downto 16) & am_readData(13 downto 8) & am_readData(4 downto 0); 
	CASE State IS
		WHEN IDLE => 
			IF START='1' THEN
				State <= WAITING;

				--switch<='1';
			Else --START='0'
				State <= IDLE;
			END IF;
		WHEN WAITING =>   --moze byc problem jak memeory wysle zdjecie juz w pierszym cyklu
			IF STOP ='1' THEN
				State <= FINISHED;
			ELSIF (f_empty='1' or f_almost_full='0' ) and STOP ='0' THEN
 					State <= WAITING_EXTENDED;
					--send request to the memory (Master request)
					am_read<='1';
					--am_address<=StartAddress_modified;
					--am_BurstCount<=std_logic_vector(to_unsigned(16, am_BurstCount'length)); 
			ELSE  --fifo_almost_full='1'
					State <= WAITING;
			END IF; 
		WHEN WAITING_EXTENDED => 
				State <= MASTER_BURST;
				--send request to the memory (Master request)
				am_read<='1';
				--am_address<=StartAddress_modified;
				--am_BurstCount<=std_logic_vector(to_unsigned(16, am_BurstCount'length)); 
		WHEN MASTER_BURST => 
			if burst_cycles_left=0 then
				State <= WAITING;	
			ELSIF am_ReadDataValid='1' and burst_cycles_left/=0  THEN
				--write data to fifo queue
				burstMode<='1';
				--transform data
				wrreq<='1';
				NextState <= MASTER_BURST;
				--switch<= not switch;
			ELSE
				State <= MASTER_BURST;			
			END IF; 
		WHEN FINISHED =>
			State<=FINISHED;
		WHEN others =>
			State<=IDLE;
	END CASE;
else
null;
 end if; 
    
  END PROCESS;

--burst counter
    process (Clk, as_nReset,am_ReadDataValid,burstMode) begin
        if as_nReset='0' then
            burst_cycles_left <= to_unsigned(16, burst_cycles_left'length);
	    asserted <='0';
        elsif rising_edge(Clk) then
		IF START='1' and asserted='0' THEN
				StartAddress_modified<=StartAddress;
				PictureLength_modified<=PictureLength;
				asserted<= '1';
		ELSE
			
	    		if burst_cycles_left=0 then
				burst_cycles_left<=to_unsigned(16, burst_cycles_left'length);
				StartAddress_modified<=std_logic_vector(to_unsigned(to_integer(unsigned( StartAddress_modified )) + 64, StartAddress_modified'length));
				PictureLength_modified<=std_logic_vector(to_unsigned(to_integer(unsigned( PictureLength_modified )) - 1, PictureLength_modified'length));

	   		 else
           	 		if am_ReadDataValid='1' and burstMode='1' then
                			burst_cycles_left <= burst_cycles_left - 1;
           	 		else
               	 			null;
           	 		end if;
	    
			end if;
		END IF;
        end if;
    end process;




--slave interface processes for exchange of data
pRegWr:
process(Clk,as_nReset)
begin
If (as_nReset = '0') THEN            -- Upon reset, set the state to A
	DCXi <= '1';
	START <= '0';
elsif rising_edge(Clk) then
	as_write_out<='0';
	if as_ChipSelect = '1' and as_Write = '1' then -- Write cycle
		--as_write_out<='0';
		case as_Address(2 downto 0) is
			when "000" => StartAddress <=as_WriteData;
			when "001" => PictureLength <= as_WriteData;
			when "010" => DATA_CMD <= as_WriteData(15 downto 0);
					as_write_out <= '1';
					DCXi <= '0';
			when "011" => DATA_CMD <= as_WriteData(15 downto 0);
					as_write_out <= '1';
					DCXi <= '1';
			when "100" => START <= as_WriteData(0);
			when others => null;
		end case;
	end if;
end if;
end process pRegWr;

pRegRd:
process(Clk)
begin
--transformation of START std_logic signal to vector
as_ReadData_t <= (others => '0') ;
as_ReadData_t(0)<= START;
if rising_edge(Clk) then
	as_ReadData <= (others => '0'); -- default value
	if as_ChipSelect = '1' and as_Read = '1' then -- Read cycle
		case as_Address(2 downto 0) is
		when "000" => as_ReadData <= std_logic_vector(StartAddress);
		when "001" => as_ReadData <= std_logic_vector(PictureLength);
		when "010" => as_ReadData <= "0000000000000000" & DATA_CMD;
		when "011" => as_ReadData <= as_ReadData_t;
		when others => null;
	end case;
	end if;
end if;
end process pRegRd;

end behav;

