LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
USE ieee.numeric_std.ALL;
 
ENTITY comunica_lcd_tb IS
END comunica_lcd_tb;
 
ARCHITECTURE behavior OF comunica_lcd_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT comunica_lcd
    PORT(
         clk : IN  std_logic;
         reset : IN  std_logic;
         data_out : OUT  std_logic_vector(3 downto 0);
         rw : OUT  std_logic;
         rs : OUT  std_logic;
         lcd_e : OUT  std_logic;
         sf_ce0 : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal reset : std_logic := '0';

 	--Outputs
   signal data_out : std_logic_vector(3 downto 0);
   signal rw : std_logic;
   signal rs : std_logic;
   signal lcd_e : std_logic;
   signal sf_ce0 : std_logic;

   -- Clock period definitions
   constant clk_period : time := 20 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: comunica_lcd PORT MAP (
          clk => clk,
          reset => reset,
          data_out => data_out,
          rw => rw,
          rs => rs,
          lcd_e => lcd_e,
          sf_ce0 => sf_ce0
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ms;
      reset <= '1';
      wait for 10 ms;
      reset <= '0';
      
      

      wait for clk_period*15;

      -- insert stimulus here 
      report "End of Test" severity Failure;
      wait;
   end process;

END;
