library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity comunica_lcd is
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           
           ir_in : in  STD_LOGIC_VECTOR (7 downto 0); -- Instrução atual da CPU
           pos_255_in : in  STD_LOGIC_VECTOR (7 downto 0);

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
    signal idx_msg : natural := 0;
    
    -- Sinais para controlar o RS dinamicamente e salvar os dados
    signal rs_reg : STD_LOGIC := '0';
    signal current_instr_str : std_logic_vector(127 downto 0);
    signal bcd_val : unsigned(11 downto 0);
    
    -- Nova máquina de estados para atualizar a tela
    type msg_state_t is (update_lcd, print_l1, cmd_l2, print_l2_txt, print_l2_num, delay_frame);
    signal state_msg : msg_state_t := update_lcd;

    -- Texto "MEM[255]: " para a segunda linha
    type byte_array is array (natural range <>) of std_logic_vector(7 downto 0);
    constant L2_TXT : byte_array(0 to 9) := (x"4D", x"45", x"4D", x"5B", x"32", x"35", x"35", x"5D", x"3A", x"20");

    
    -- FUNÇÕES E ROM DO PROFESSOR (Para traduzir Binário -> Texto -> BCD)
    
    -- Converte Binário de 8 bits em 3 dígitos decimais (BCD)
    function to_bcd(Binary : unsigned(7 downto 0)) return unsigned is
        variable b   : unsigned(7 downto 0) := Binary;
        variable bcd : unsigned(11 downto 0) := (others => '0');
    begin
        for i in 0 to 7 loop
            for d in 0 to 2 loop
                if bcd(d*4+3 downto d*4) >= 5 then
                    bcd(d*4+3 downto d*4) := bcd(d*4+3 downto d*4) + 3;
                end if;
            end loop;
            bcd := bcd(10 downto 0) & b(7);
            b   := b(6 downto 0) & '0';
        end loop;
        return bcd;
    end function;

    -- Função 2: Converte String de Texto para Vetor de Bits (Do arquivo do professor)
    function to_std_logic_vector(a : string) return std_logic_vector is
        variable ret : std_logic_vector(a'length*8-1 downto 0);
    begin
        for i in a'range loop
            ret(i*8+7 downto i*8) := std_logic_vector(to_unsigned(character'pos(a(i)), 8));
        end loop;
        return ret;
    end function to_std_logic_vector;

    -- A Tabela ROM (O "Dicionário" do professor Calliari)
    type TEXT_MAP_ROM_t is array (0 to 255) of std_logic_vector(8*16-1 downto 0);
    constant TEXT_MAP_ROM : TEXT_MAP_ROM_t := (
        0 => to_std_logic_vector("add RA, RA      "),
        1 => to_std_logic_vector("add RA, RB      "),
        2 => to_std_logic_vector("add RA, RC      "),
        3 => to_std_logic_vector("add RA, RD      "),
        4 => to_std_logic_vector("add RB, RA      "),
        -- (NOTA: Você pode adicionar os outros opcodes aqui depois!)
        128 => to_std_logic_vector("push RA         "), -- 1000 00 00 (0x80)
        130 => to_std_logic_vector("st RA, 0x--     "), -- 1000 00 10 (0x82)
        131 => to_std_logic_vector("ld RA, 0x--     "), -- 1000 00 11 (0x83)
        240 => to_std_logic_vector("halt            "), -- 1111 00 00 (0xF0)
        others => to_std_logic_vector("invalid instr.  ")
    );
    );

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
                    
                        case state_msg is 
                            
                            when update_lcd =>
                                -- Puxa a string da ROM baseada no OpCode atual (ir_in)
                                current_instr_str <= TEXT_MAP_ROM(to_integer(unsigned(ir_in)));
                                -- Converte o valor da memória 255 em 3 dígitos decimais
                                bcd_val <= to_bcd(unsigned(pos_255_in));
                                idx_msg <= 0;
                                state_msg <= print_l1;

                            when print_l1 =>
                                rs_reg <= '1'; -- Avisa o LCD que vamos mandar TEXTO
                                if idx_msg < 16 then
                                    -- Corta a letra exata da string gigante e envia
                                    v_byte_to_send := current_instr_str( (15 - idx_msg)*8 + 7 downto (15 - idx_msg)*8 );
                                    envia_dados(v_byte_to_send, busy_send, busy_reg, send_cmd, byte_in_reg, finished_byte);
                                    if finished_byte = '1' then
                                        idx_msg <= idx_msg + 1;
                                        finished_byte := '0';
                                    end if;
                                else
                                    state_msg <= cmd_l2;
                                end if;

                            when cmd_l2 =>
                                rs_reg <= '0'; -- Avisa o LCD que vamos mandar um COMANDO
                                envia_dados(x"C0", busy_send, busy_reg, send_cmd, byte_in_reg, finished_byte); -- Comando 0xC0: Pula para a 2ª linha
                                if finished_byte = '1' then
                                    state_msg <= print_l2_txt;
                                    idx_msg <= 0;
                                    finished_byte := '0';
                                end if;

                            when print_l2_txt =>
                                rs_reg <= '1'; -- Texto novamente
                                envia_sequencia(L2_TXT, idx_msg, finished_msg);
                                if finished_msg = '1' then
                                    state_msg <= print_l2_num;
                                    idx_msg <= 0;
                                    finished_msg := '0';
                                end if;

                            when print_l2_num =>
                                rs_reg <= '1'; -- Texto
                                if idx_msg = 0 then
                                    v_byte_to_send := "0011" & std_logic_vector(bcd_val(11 downto 8)); -- Imprime Centena
                                elsif idx_msg = 1 then
                                    v_byte_to_send := "0011" & std_logic_vector(bcd_val(7 downto 4));  -- Imprime Dezena
                                elsif idx_msg = 2 then
                                    v_byte_to_send := "0011" & std_logic_vector(bcd_val(3 downto 0));  -- Imprime Unidade
                                end if;
                                
                                envia_dados(v_byte_to_send, busy_send, busy_reg, send_cmd, byte_in_reg, finished_byte);
                                if finished_byte = '1' then
                                    idx_msg <= idx_msg + 1;
                                    finished_byte := '0';
                                end if;
                                
                                if idx_msg = 3 then
                                    state_msg <= delay_frame;
                                    counter <= (others => '0');
                                end if;

                            when delay_frame =>
                                rs_reg <= '0';
                                -- Espera um tempinho pra tela não piscar loucamente
                                if counter < wait_interval then
                                    counter <= counter + 1;
                                else
                                    -- Comando 0x80: Volta o cursor para o começo da 1ª linha
                                    envia_dados(x"80", busy_send, busy_reg, send_cmd, byte_in_reg, finished_byte); 
                                    if finished_byte = '1' then
                                        state_msg <= update_lcd;
                                        finished_byte := '0';
                                    end if;
                                end if;

                            when others => null;
                        
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
          
    rs <= rs_reg;
    
end Behavioral;

