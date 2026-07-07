library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity main is
    Port (
        CLK      : in  STD_LOGIC; -- 50 MHz vindo da placa
        RESET    : in  STD_LOGIC; -- Botão de reset
        
        -- Pinos físicos do LCD (conforme o arquivo .ucf)
        DATA_OUT : out STD_LOGIC_VECTOR (3 downto 0);
        RW       : out STD_LOGIC;
        RS       : out STD_LOGIC;
        LCD_E    : out STD_LOGIC;
        SF_CE0   : out STD_LOGIC
    );
end main;

architecture Behavioral of main is

    --  Sinais do Divisor de Clock
    signal clk_cpu      : STD_LOGIC := '0';
    -- Contador até 50 milhões (50 MHz = 1 segundo em '0' e 1 segundo em '1' = 2s período)
    signal clk_counter  : integer range 0 to 50000000 := 0; 

    -- Registradores para interligar CPU e RAM
    signal ram_din_reg  : std_logic_vector(7 downto 0);
    signal ram_dout_reg : std_logic_vector(7 downto 0);
    signal ram_addr_reg : std_logic_vector(7 downto 0);
    signal we_reg       : std_logic;
    
    signal ir_reg       : std_logic_vector(7 downto 0);
    signal pos255_reg   : std_logic_vector(7 downto 0);

begin

    -- INSTANCIAÇÃO DA CPU
    u_cpu : entity work.cpu(Behavioral)
        port map (
            CLK      => clk_cpu,      -- CPU roda lenta (~2s)
            RESET    => RESET,
            RAM_DIN  => ram_din_reg,
            RAM_DOUT => ram_dout_reg,
            RAM_ADDR => ram_addr_reg,
            WE       => we_reg,
            IR_OUT   => ir_reg        -- Pega a instrução atual
        );

    -- INSTANCIAÇÃO DA MEMÓRIA RAM
    u_memory : entity work.RAM_8x256(rtl)
        port map (
            CLK     => clk_cpu,       -- RAM acompanha o clock lento da CPU
            DIN     => ram_din_reg,
            ADDR    => ram_addr_reg,
            WE      => we_reg,
            DOUT    => ram_dout_reg,
            POS_255 => pos255_reg     -- Pega o conteúdo da posição 255
        );

    -- INSTANCIAÇÃO DO LCD
    u_lcd : entity work.comunica_lcd(Behavioral)
        port map (
            clk      => CLK,          -- LCD precisa dos 50 MHz originais!
            reset    => RESET,
            data_out => DATA_OUT,
            rw       => RW,
            rs       => RS,
            lcd_e    => LCD_E,
            sf_ce0   => SF_CE0

        );

    -- PROCESSO: DIVISOR DE CLOCK
    p_clock_divider: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                clk_counter <= 0;
                clk_cpu <= '0';
            else
                if clk_counter = 49_999_999 then 
                    clk_counter <= 0;
                    clk_cpu <= not clk_cpu; -- Faz transição
                else
                    clk_counter <= clk_counter + 1;
                end if;
            end if;
        end if;
    end process p_clock_divider;

end Behavioral;