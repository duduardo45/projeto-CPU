library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cpu is
    port (
        CLK            : in     STD_LOGIC;
        -- CPU / RAM
        RAM_DIN         : out std_logic_vector(7 downto 0);
        RAM_DOUT        : in  std_logic_vector(7 downto 0);
        RAM_ADDR        : out std_logic_vector(7 downto 0);
        WE              : out std_logic
        -- 
        
    );
end cpu;
-- TODO: criar top level que integre com memória e lcd, e alterar o lcd para receber valores da memoria
architecture Behavioral of cpu is        
    
    -- registradores
    signal SP  : UNSIGNED(7 downto 0) := to_unsigned(254, 8);
    signal IR  : STD_LOGIC_VECTOR(7 downto 0) := to_unsigned(0, 8);
    signal PC  : STD_LOGIC_VECTOR(7 downto 0) := to_unsigned(0, 8);
    signal MAR : STD_LOGIC_VECTOR(7 downto 0) := to_unsigned(0, 8);
    signal MBR : STD_LOGIC_VECTOR(7 downto 0) := to_unsigned(0, 8);
    
    
    type reg_t is array (natural range <>) of STD_LOGIC_VECTOR(7 downto 0);
    signal REG       : reg_t(3 downto 0); -- 4 regs (REG D,C,B,A)
    
    -- FSM para as operacoes da cpu
    type FSM_CPU is (FETCH, DECODE_1, DECODE_2, EXECUTE);
    signal STATE : FSM_CPU := FETCH;

    signal ALU_A     : STD_LOGIC_VECTOR(7 downto 0) := x"00";
    signal ALU_B     : STD_LOGIC_VECTOR(7 downto 0) := x"00";
    signal ALU_S     : STD_LOGIC_VECTOR(7 downto 0) := x"00";
    signal ALU_FLAGS : STD_LOGIC_VECTOR(4 downto 0) := "00000";
    signal ALU_CMD   : STD_LOGIC_VECTOR(3 downto 0) := x"0";
    signal ALU_CIN   : STD_LOGIC := '0';
    signal ALU_COUT  : STD_LOGIC := '0';

    variable opcode : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    variable op1, op2 : STD_LOGIC_VECTOR(1 downto 0) := "00";

begin

    u_alu : entity work.alu(Behavioral)
        port map (
            A         => ALU_A,
            B         => ALU_B,
            CMD       => ALU_CMD,
            C_in      => ALU_CIN,
            C_out     => ALU_COUT,
            FLAGS     => ALU_FLAGS,
            S         => ALU_S
        );
    
    p_fsm_cycle : process(CLK)
    begin
        if rising_edge(CLK) then
            if (RESET = '1') then
                -- registradores
                REG(3)            <= x"00"; -- D
                REG(2)            <= x"00"; -- C
                REG(1)            <= x"00"; -- B
                REG(0)            <= x"00"; -- A
                -- ... IR, PC, MAR...
                IR            <= x"00";
                PC            <= x"00";
                MAR           <= x"00";
                MBR           <= x"00";
                -- SP = 254 !!
                SP            <= x"FE";
                STATE         <= FETCH;
            else
                case STATE is
                    -- FETCH instruction from ram
                    when FETCH =>
                        IR <= RAM_DOUT;
                        STATE <= DECODE_1;
                    
                    -- DECODE fetched opcode
                    when DECODE_1 =>
                        
                        opcode := IR(7 downto 4);
                        op1 := IR(3 downto 2);
                        op2 := IR(1 downto 0);
                        
                        -- add Rx, Ry
                        -- OPCODE "0000" & Rx & Ry
                        -- Rx <- Rx + Ry, pc <- pc + 1
                        if opcode(3) = "0" then -- instruções de ALU
                        
                            if opcode = "0010" and op2 = "01" then
                                -- DEC
                                ALU_A <= REG( to_integer(unsigned(op1)) );
                                ALU_CMD <= "1011";
                                
                            elsif opcode = "0111" then
                                -- shift operations
                                ALU_A <= REG( to_integer(unsigned(op1)) );
                                ALU_CMD <= std_logic_vector(unsigned(opcode) + unsigned("00" & op2)); 
                            else
                                -- all other operations
                                ALU_A <= REG( to_integer(unsigned(op1)) );
                                ALU_B <= REG( to_integer(unsigned(op2)) );
                                ALU_CMD <= opcode;
                            end if;
                        
                        elsif opcode(2) = '0' then -- instrução de memória
                        
                        -- TODO: preencher as operações de memória
                        
                        else -- instrução de salto ou halt
                        
                            if opcode = "1111" then
                            
                                -- instrução de parada
                            
                            end if;
                        
                            -- TODO: preencher estas operações
                            
                        end if;
                        STATE <= DECODE_2;

                    -- DECODE fetched opcode 
                    when DECODE_2 =>
                        if IR(7) = "0" then -- instruções de ALU
                            NULL; -- iremos salvar o dado da operação com a ALU no estado EXECUTE
                        end if;
                        
                        STATE <= EXECUTE;

                    -- EXECUTE instruction
                    when EXECUTE =>
                        -- add Rx, Ry
                        -- OPCODE "0000" & Rx & Ry
                        -- Rx <- Rx + Ry, pc <- pc + 1
                        if IR(7) = "0" then -- instruções de ALU
                            REG( to_integer(unsigned(IR(3 downto 2))) ) <= ALU_S;
                            PC <= PC + 1;
                            MBR <= PC + 1;
                        end if;

                        STATE <= FETCH;
                        
                    when others =>
                        STATE <= FETCH;
                        
                end case;
            end if;
        end if;
    end process;
    
    RAM_ADDR <= MBR;
    
end Behavioral;
