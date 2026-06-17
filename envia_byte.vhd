library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity envia_byte is
    Port ( byte_in : in  STD_LOGIC_VECTOR (7 downto 0);
           clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           busy : out  STD_LOGIC;
           send  : in  STD_LOGIC;
           data_out : out  STD_LOGIC_VECTOR (3 downto 0);
           rw: out STD_LOGIC;
           enable: out STD_LOGIC
          );
end envia_byte;

architecture Behavioral of envia_byte is

    signal data_reg: STD_LOGIC_VECTOR (3 downto 0):= "0000";
    signal rw_reg: STD_LOGIC:= '0';
    signal enable_reg: STD_LOGIC:= '0';
    --Time Constants:
    
    constant enable_interval: NATURAL:= 12;
    constant send_interval: NATURAL:= 2000;
    constant bits_interval: NATURAL:= 50;
    signal counter: UNSIGNED (10 downto 0):= (others => '0');
    type state_t is (idle, pre_first, first_nibble, inter_nibble, pre_second, second_nibble, busy_state);
    signal state: state_t := idle;
    
begin

    send_byte: process(clk)
    
        begin
        
            if clk'event and clk = '1' then
                if reset = '1' then
                    counter <= to_unsigned(0,11);
                    state <= idle;
                    data_reg <= (others => '0');
                else 
                    case state is 
                        when idle => 
                            if send = '1' then
                                data_reg <= byte_in(7 downto 4);
                                rw_reg <= '0';
                                busy <= '1';
                                counter <= (others => '0');
                                state <= pre_first;
                            else 
                                busy <= '0';
                            end if;
                        when pre_first =>
                            if counter < 2 then
                                counter <= counter + 1;
                            else 
                                enable_reg <= '1';
                                state <= first_nibble;
                                counter <= (others => '0');
                            end if;
                        when first_nibble =>
                            if counter < enable_interval then
                                counter <= counter + 1;
                            else 
                                enable_reg <= '0';
                                rw_reg <= '1'; --testar ele sempre em zero depois
                                state <= inter_nibble;
                                counter <= (others => '0');
                            end if;
                        when inter_nibble =>
                            if counter < bits_interval then
                                counter <= counter + 1;
                            else 
                                state <= pre_second;
                                data_reg <= byte_in(3 downto 0);
                                rw_reg <= '0';
                                counter <= (others => '0');
                            end if;
                        when pre_second =>
                            if counter < 2 then
                                counter <= counter + 1;
                            else 
                                enable_reg <= '1';
                                state <= second_nibble;
                                counter <= (others => '0');
                            end if;
                       when second_nibble =>
                            if counter < enable_interval then
                                counter <= counter + 1;
                            else 
                                enable_reg <= '0';
                                rw_reg <= '1'; --testar ele sempre em zero depois
                                state <= busy_state;
                                counter <= (others => '0');
                            end if; 
                       when busy_state =>
                            if counter < send_interval then
                                counter <= counter + 1;
                            else 
                                state <= idle;
                                busy <= '0';
                                counter <= (others => '0');
                            end if; 
                        
                    end case;
                end if;
            end if;
        end process send_byte;
        
        data_out <= data_reg;
        rw <= rw_reg;
        enable <= enable_reg;

end Behavioral;

