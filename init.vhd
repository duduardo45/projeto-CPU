library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity init is
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           data_out : out  STD_LOGIC_VECTOR (3 downto 0);
           init_done : out  STD_LOGIC;
           rw: out STD_LOGIC;
           enable: out STD_LOGIC
   );
end init;

architecture Behavioral of init is
     

    signal data_out_reg: STD_LOGIC_VECTOR (3 downto 0):= (others => '0');
    signal done_reg, rw_reg, enable_reg: STD_LOGIC:= '0';
    
    constant interval_a: NATURAL:= 750000;
    constant interval_c: NATURAL:= 205000;
    constant interval_e: NATURAL:= 5000;
    constant interval_g: NATURAL:= 2000;
    constant interval_i: NATURAL:= 2000;
    constant bits_interval: NATURAL:= 12;
    signal counter: UNSIGNED (19 downto 0):= (others => '0');
    
    type state_t is (a, b, c, d, e, f, g, h, i, idle);-- states
    signal state: state_t:= a;
    
begin

    process(clk)
    begin
        if clk'event and clk = '1' then
            if reset = '1' then
                counter <= to_unsigned(0,20);
                state <= idle;
                data_out_reg <= (others => '0'); -- rever
                enable_reg <= '0';
                rw_reg <= '1';
                init_done <= '0';
            else 
                case state is
                    when a =>
                        if counter < interval_a then
                            counter <= counter + 1;
                        else 
                            state <= b;
                            rw_reg <= '0';
                            enable_reg <= '1';
                            data_out <= "0011";
                            counter <= (others => '0');
                        end if;
                    when b =>
                        if counter < bits_interval then
                            counter <= counter + 1;
                        else 
                            state <= c;
                            enable_reg <= '0';
                            data_out <= "ZZZZ";
                            counter <= (others => '0');
                        end if;
                    when c =>
                        if counter < interval_c then
                            counter <= counter + 1;
                        else 
                            state <= d;
                            enable_reg <= '1';
                            data_out <= "0011";
                            counter <= (others => '0');
                        end if;
                    when d => 
                        if counter < bits_interval then
                            counter <= counter + 1;
                        else 
                            state <= e;
                            enable_reg <= '0';
                            data_out <= "ZZZZ";
                            counter <= (others => '0');
                        end if;
                    when e =>
                        if counter < interval_e then
                            counter <= counter + 1;
                        else 
                            state <= f;
                            enable_reg <= '1';
                            data_out <= "0011";
                            counter <= (others => '0');
                        end if;
                    when f => 
                        if counter < bits_interval then
                            counter <= counter + 1;
                        else 
                            state <= g;
                            enable_reg <= '0';
                            data_out <= "ZZZZ";
                            counter <= (others => '0');
                        end if;
                    when g =>
                        if counter < interval_g then
                            counter <= counter + 1;
                        else 
                            state <= h;
                            enable_reg <= '1';
                            data_out <= "0010";
                            counter <= (others => '0');
                        end if;
                    when h => 
                        if counter < bits_interval then
                            counter <= counter + 1;
                        else 
                            state <= i;
                            enable_reg <= '0';
                            data_out <= "ZZZZ";
                            counter <= (others => '0');
                        end if;
                    when i =>
                        if counter < interval_i then
                            counter <= counter + 1;
                        else 
                            state <= idle;
                            enable_reg <= '0';
                            init_done <= '1';
                            data_out <= "ZZZZ";
                            counter <= (others => '0');
                        end if;
                        
                    when idle =>
                        if reset = '1' then
                            state <= a;
                        end if;
                    when others => state <= idle;
                end case;
            end if;
        end if;
    end process;
    rw <= rw_reg;
    enable <= enable_reg;
    


end Behavioral;

