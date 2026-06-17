library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity comunica_lcd is
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           data_out : out  STD_LOGIC_VECTOR (3 downto 0);
           rw : out  STD_LOGIC; -- precisa ser definido mesmo no init
           rs : out  STD_LOGIC;
           lcd_e: out STD_LOGIC;
           sf_ce0 : out  STD_LOGIC
    );
end comunica_lcd;

architecture Behavioral of comunica_lcd is
    
    signal byte_in_reg: STD_LOGIC_VECTOR (7 downto 0):= (others => '0');
    signal data_out_reg: STD_LOGIC_VECTOR (3 downto 0):= (others => '0');
    signal rw_init, rw_envia: STD_LOGIC:= '0';
    signal enable_init, enable_envia: STD_LOGIC:= '0';
    signal busy_send, busy_reg, send_cmd : STD_LOGIC := '0';
    
    signal init_data: STD_LOGIC_VECTOR (3 downto 0):= (others => '0');
    signal init_done: STD_LOGIC := '0';
    constant wait_interval: NATURAL:= 82000;
    signal counter : unsigned (16 downto 0) := (others => '0');
    type state_t is (init, state_reset,state_on);
    signal state: state_t:= init; 
    type byte_to_send_t is (fun_set, entry_set, display_on, clear, wait_clear);
    signal state_send: byte_to_send_t:= fun_set; 
    signal byte_to_send : STD_LOGIC_VECTOR (7 downto 0):= x"28";
    
    type byte_array is array (natural range <>) of std_logic_vector(7 downto 0);
    constant CARPE : byte_array := (x"43", x"61", x"72", x"70", x"65"); -- "Carpe"
    constant DIEM  : byte_array := (x"64", x"69", x"65", x"6D");        -- "diem"
    constant LOREM : byte_array := (x"4C", x"6F", x"72", x"65", x"6D"); -- "Lorem"
    constant IPSUM : byte_array := (x"49", x"70", x"73", x"75", x"6D"); -- "Ipsum"
    signal idx_msg : natural := 0;
    
    type msg_state_t is (c,esp1,d,esp2,l,esp3,i, idle);
    signal state_msg : msg_state_t := c;

begin
    
    lcd_init : entity work.init(Behavioral)
       port map(
           clk => clk,
           reset => reset,
           data_out => init_data,
           init_done => init_done,
           rw => rw_init,
           enable => enable_init
       ); 
       
     envia_byte : entity work.envia_byte(Behavioral)
       port map(
           byte_in => byte_in_reg,
           clk => clk,
           reset => reset,
           busy => busy_send,
           send  => send_cmd,
           data_out => data_out_reg,
           rw => rw_envia,
           enable => enable_envia
       );
    
    process(clk)
        variable finished_byte, finished_msg : STD_LOGIC := '0';
        procedure envia_dados(
            constant dado      : in  STD_LOGIC_VECTOR(7 downto 0);
            signal busy        : in  STD_LOGIC;
            signal busy_reg_p  : inout STD_LOGIC;
            signal send_cmd_p  : out STD_LOGIC;
            signal byte_reg_p  : out STD_LOGIC_VECTOR(7 downto 0);
            variable pronto    : out STD_LOGIC
        ) is
        begin
            pronto := '0';
            if busy = '0' and busy_reg_p = '0' then
                send_cmd_p <= '1';
                byte_reg_p <= dado;
                busy_reg_p <= busy;
            elsif busy = '1' then
                send_cmd_p <= '0';
                busy_reg_p <= '1';
            elsif busy = '0' and busy_reg_p = '1' then
                busy_reg_p <= '0';
                pronto := '1';
            end if;
        end procedure;
        
        procedure envia_sequencia(
            constant msg       : in  byte_array;
            signal   idx       : inout NATURAL;
            variable completa  : out STD_LOGIC
        ) is
            variable byte_pronto : boolean := false;
        begin
            completa := '0';
            
            if idx <= msg'high then
                envia_dados(msg(idx), busy_send, busy_reg, send_cmd, byte_in_reg, finished_byte);
                if finished_byte = '1' then
                    idx <= idx + 1;
                    
                end if;
            else
                completa := '1';
            end if;
        end procedure;
        
        variable v_byte_to_send : STD_LOGIC_VECTOR (7 downto 0);
    begin
    
            if clk'event and clk = '1' then
                if reset = '1' then
                    byte_in_reg <= (others => '0');
                    
                    counter <= (others => '0');
                    state <= init; --rever estado de inicializacao
                    state_send <= fun_set;
                    send_cmd <= '0';
                else 
                    case state is 
                    when init =>
                        if init_done = '1' then 
                            state <= state_reset;
                        end if;
                    when state_reset =>
                        case state_send is --(fun_set, entry_set, display_on, clear);
                            when fun_set =>
                                --v_byte_to_send := x"28";
                                --byte_to_send <= x"28";
                                envia_dados(x"28", busy_send, busy_reg, send_cmd, byte_in_reg, finished_byte);
                                if finished_byte = '1' then
                                   state_send <= entry_set;
                                   finished_byte := '0';
                                end if;
                            when entry_set =>
                                v_byte_to_send := x"06";
                                --byte_to_send <= x"06";
                                envia_dados(v_byte_to_send, busy_send, busy_reg, send_cmd, byte_in_reg, finished_byte);
                                if finished_byte = '1' then
                                   state_send <= display_on;
                                   finished_byte := '0';
                                end if;
                            when display_on =>
                                v_byte_to_send := x"0F";
                                --byte_to_send <= x"0F";
                                envia_dados(v_byte_to_send, busy_send, busy_reg, send_cmd, byte_in_reg, finished_byte);
                                if finished_byte = '1' then
                                   state_send <= clear;
                                   finished_byte := '0';
                                end if;
                            when clear =>
                                v_byte_to_send := x"01";
                                --byte_to_send <= x"01";
                                envia_dados(v_byte_to_send, busy_send, busy_reg, send_cmd, byte_in_reg, finished_byte);
                                if finished_byte = '1' then
                                   state_send <= wait_clear;
                                   finished_byte := '0';
                                end if;
                            when wait_clear =>
                                if counter < wait_interval then
                                   counter <= counter + 1;
                                else
                                    v_byte_to_send := x"28";
                                    --byte_to_send <= x"28";
                                    --envia_dados(v_byte_to_send, busy_send, busy_reg, send_cmd, byte_in_reg, finished_byte);
                                    state_send <= fun_set;
                                    counter <= (others => '0');
                                    state <= state_on;
                                end if;
                            when others => -- nao faz nada
                            end case;
                        --envia_dados(v_byte_to_send, busy_send, busy_reg, send_cmd, byte_in_reg, finished_byte);

                    when state_on =>
                        case state_msg is -- (c,esp1,d,esp2,l,esp3,i, idle)
                        when c =>
                            envia_sequencia(CARPE, idx_msg, finished_msg);
                            if finished_msg = '1' then
                                state_msg <= esp1;
                                finished_msg := '0'; -- MUDEI
                                idx_msg <= 0;
                            end if;
                        when esp1 =>
                            envia_dados(x"20", busy_send, busy_reg, send_cmd, byte_in_reg, finished_byte);
                            if finished_byte = '1' then
                                state_msg <= d;
                                finished_byte := '0';
                            end if;
                        when d =>
                            envia_sequencia(DIEM, idx_msg, finished_msg);
                            if finished_msg = '1' then
                                state_msg <= esp2;
                                finished_msg := '0';
                                idx_msg <= 0;
                            end if;
                        when esp2 =>
                            envia_dados(x"20", busy_send, busy_reg, send_cmd, byte_in_reg, finished_byte);
                            if finished_byte = '1' then
                                state_msg <= l;
                                finished_byte := '0';
                            end if;
                        when l =>
                            envia_sequencia(LOREM, idx_msg, finished_msg);
                            if finished_msg = '1' then
                                state_msg <= esp3;
                                finished_msg := '0';
                                idx_msg <= 0;
                            end if;
                        when esp3 =>
                            envia_dados(x"20", busy_send, busy_reg, send_cmd, byte_in_reg, finished_byte);
                            if finished_byte = '1' then
                                state_msg <=i;
                                finished_byte := '0';
                            end if;
                        when i =>
                            envia_sequencia(IPSUM, idx_msg, finished_msg);
                            if finished_msg = '1' then
                                state_msg <= idle;
                                finished_msg := '0';
                                idx_msg <= 0;
                            end if;
                        when idle =>
                            if reset = '1' then
                                state <= state_reset;
                            end if;
                        when others => -- não precisa fazer nada
                        end case;
                    end case;
                end if;
            end if;

    end process;
    sf_ce0 <= '1';
    
    data_out <= init_data when state = init else 
                data_out_reg when state = state_on else
                data_out_reg when state = state_reset else
                (others => 'Z');
                
    rw <= rw_init when state = init else
          rw_envia when state = state_on else
          rw_envia when state = state_reset else
          '0';
          
    lcd_e <= enable_init when state = init else
          enable_envia when state = state_on else
          enable_envia when state = state_reset else
          '0';
          
    rs <= '0' when state = init else
          '0' when state = state_reset else
          '1' when state = state_on else
          '0';
    
end Behavioral;

