library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cpu is
    port (
        CLK             : in     STD_LOGIC;
        RESET           : in  STD_LOGIC;
        -- Instrucao para o LCD
        IR_OUT          : out std_logic_vector(7 downto 0); -- Exporta a instrução atual
        -- CPU / RAM
        RAM_DIN         : out std_logic_vector(7 downto 0);
        RAM_DOUT        : in  std_logic_vector(7 downto 0);
        RAM_ADDR        : out std_logic_vector(7 downto 0);
        WE              : out std_logic;
        -- FLAGS
        FLAG_ZERO       : out std_logic;
        FLAG_CARRY      : out std_logic;
        FLAG_EQUAL      : out std_logic;
        FLAG_GREATER    : out std_logic;
        FLAG_SMALLER    : out std_logic
    );
end cpu;
-- TODO: criar top level que integre com memória e lcd, e alterar o lcd para receber valores da memoria
architecture Behavioral of cpu is        
    
    -- registradores
    signal SP  : UNSIGNED(7 downto 0) := to_unsigned(254, 8);
    signal IR  : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal PC  : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal MAR : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal MBR : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    
    
    type reg_t is array (natural range <>) of STD_LOGIC_VECTOR(7 downto 0);
    signal REG       : reg_t(3 downto 0); -- 4 regs (REG D,C,B,A)
    
    -- FSM para as operacoes da cpu
    type FSM_CPU is (FETCH, DECODE_1, DECODE_2, EXECUTE);
    signal STATE : FSM_CPU := FETCH;
    
    type FSM_OPS is (MEM, ALU, JUMP, HALT);
    type FSM_MEMORY is (PUSH, POP, ST, LD, LDR, STR, MOV, MEM_READ, MEM_WRITE); -- Apesar de serem muitos estados, prefiro deixar assim para facilitar a leitura do código, e não ter que ficar criando variáveis auxiliares para cada operação de memória.
    type FSM_ALU is (GENERIC_OP, DEC, SHIFT); 
    type FSM_JUMP is (JMP, JMPR, BZ, BNZ, BCS, BCC, BEQ, BNEQ, BGT, BLT);  

    signal CURRENT_OP : FSM_OPS := JUMP;
    signal MEMORY_OP  : FSM_MEMORY := MEM_WRITE;
    signal ALU_OP     : FSM_ALU := GENERIC_OP;
    signal JUMP_OP    : FSM_JUMP := JMP;

    signal ALU_A     : STD_LOGIC_VECTOR(7 downto 0) := x"00";
    signal ALU_B     : STD_LOGIC_VECTOR(7 downto 0) := x"00";
    signal ALU_S     : STD_LOGIC_VECTOR(7 downto 0) := x"00";
    signal ALU_FLAGS : STD_LOGIC_VECTOR(4 downto 0) := "00000";
    signal ALU_CMD   : STD_LOGIC_VECTOR(3 downto 0) := x"0";
    signal ALU_CIN   : STD_LOGIC := '0';
    signal ALU_COUT  : STD_LOGIC := '0';

    signal zero_flag_reg, carry_flag_reg, equal_flag_reg, greater_flag_reg, smaller_flag_reg : boolean := false;
    
    -- Variaveis e sinais de memória:
    signal pos_255_reg : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

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
    -- u_ram : entity work.RAM_8x256(rtl)
    --     port map (
    --         CLK     => CLK,
    --         DIN     => RAM_DIN,
    --         ADDR    => RAM_ADDR,
    --         WE      => WE,
    --         DOUT    => RAM_DOUT,
    --         POS_255 => pos_255_reg
    --     );
            
    
    p_fsm_cycle : process(CLK)
		

		 variable opcode : STD_LOGIC_VECTOR(3 downto 0) := "0000";
		 variable op1, op2 : STD_LOGIC_VECTOR(1 downto 0) := "00";

		 variable exec_done : boolean := false;
    begin
        if rising_edge(CLK) then
            WE <= '0';
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
                MAR           <= x"00";
                MBR           <= x"00";
                -- SP = 254 !!
                SP            <= to_unsigned(254, 8);
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
                        if opcode(3) = '0' then -- instruções de ALU
                            CURRENT_OP <= ALU;
                            if opcode = "0010" and op2 = "01" then
                                -- DEC
                                ALU_A <= REG( to_integer(unsigned(op1)) );
                                ALU_CMD <= "1011";
                                ALU_OP <= DEC;
                            elsif opcode = "0111" then
                                -- shift operations
                                ALU_A <= REG( to_integer(unsigned(op1)) );
                                ALU_CMD <= std_logic_vector(unsigned(opcode) + (unsigned'("00") & unsigned(op2)));
                                ALU_OP <= SHIFT;
                            else
                                -- all other operations
                                ALU_A <= REG( to_integer(unsigned(op1)) );
                                ALU_B <= REG( to_integer(unsigned(op2)) );
                                ALU_CMD <= opcode;
                                ALU_OP <= GENERIC_OP;
                            end if;
                        
                        elsif opcode(3 downto 2) = "10" then 
                            CURRENT_OP <= MEM;
                            
                            case opcode is
                                when "1000" => 
                                    case op2 is 
                                        when "00" => -- push
                                            MEMORY_OP <= PUSH;
                                            MAR <= std_logic_vector(SP); -- ele é unsigned, por isso precisa converter para std_logic_vector
                                        when "01" => -- pop
                                            MEMORY_OP <= POP;
                                            MAR <= std_logic_vector(SP + 1);
                                        when "10" => -- st
                                            MEMORY_OP <= ST;
                                            MAR <= std_logic_vector(unsigned(PC) + 1);
                                        when "11" => -- ld
                                            MEMORY_OP <= LD;
                                            MAR <= std_logic_vector(unsigned(PC) + 1);
                                        when others => null;
                                    end case;
                                    
                                when "1001" => -- ldr
                                    MEMORY_OP <= LDR;
                                    MAR <= REG(to_integer(unsigned(op2)));
                                    
                                when "1010" => -- str
                                    MEMORY_OP <= STR;
                                    MAR <= REG(to_integer(unsigned(op2)));
                                    
                                when "1011" => -- mov
                                    MEMORY_OP <= MOV;
                                    
                                when others => null;
                            end case;
                            
                        
                        else -- instrução de salto ou halt
                        
                            if opcode = "1111" then
                                -- instrução de parada
                                CURRENT_OP <= HALT;
                            else
                                CURRENT_OP <= JUMP;
                                if IR(3 downto 0) = "0000" then -- jump para o endereço PC+1
                                    JUMP_OP <= JMP;
                                end if;
                                
                                -- jump para endereço em Rx
                                if opcode = "1100" then
                                    if op2 = "01" then -- jmpr
                                        JUMP_OP <= JMPR;
                                    elsif op2 = "10" then -- bz
                                        JUMP_OP <= BZ;
                                    elsif op2 = "11" then -- bnz
                                        JUMP_OP <= BNZ;
                                    end if;
                                elsif opcode = "1101" then
                                    if op2 = "00" then -- bcs
                                        JUMP_OP <= BCS;
                                    elsif op2 = "01" then -- bcc
                                        JUMP_OP <= BCC;
                                    elsif op2 = "10" then -- beq
                                        JUMP_OP <= BEQ;
                                    elsif op2 = "11" then -- bneq
                                        JUMP_OP <= BNEQ;
                                    end if;
                                elsif opcode = "1110" then
                                    if op2 = "00" then -- bgt
                                        JUMP_OP <= BGT;
                                    elsif op2 = "01" then -- blt
                                        JUMP_OP <= BLT;
                                    end if;
                                end if;  
                            end if;
                        end if;
                        STATE <= DECODE_2;

                    -- DECODE fetched opcode 
                    when DECODE_2 =>
                    -- apenas nos casos que precisa de PC+1
                        case CURRENT_OP is
                            when ALU =>
                                NULL;
                            when MEM =>
                                if MEMORY_OP = PUSH or MEMORY_OP = STR then
                                    MBR <= REG(to_integer(unsigned(op1))); -- Dado vai pro Buffer
                                    WE <= '1';
                                elsif MEMORY_OP = ST then
                                    MAR <= RAM_DOUT; -- Endereço destino vai pro Address Register
                                    MBR <= REG(to_integer(unsigned(op1))); -- Dado vai pro Buffer
                                    WE <= '1';
                                end if;
                            when JUMP =>
                                if JUMP_OP = JMP then
                                    MAR <= std_logic_vector(unsigned(PC) + 1);
                                end if;
                            when HALT =>
                                NULL;
                            when others =>
                                NULL;
                        end case;
                        
                        STATE <= EXECUTE;

                    -- EXECUTE instruction
                    when EXECUTE =>

                        case CURRENT_OP is

                            when ALU =>
                                case ALU_OP is
                                    when GENERIC_OP =>
                                        REG( to_integer(unsigned(IR(3 downto 2))) ) <= ALU_S;
                                    when DEC =>
                                        REG( to_integer(unsigned(IR(3 downto 2))) ) <= ALU_S;
                                    when SHIFT =>
                                        REG( to_integer(unsigned(IR(3 downto 2))) ) <= ALU_S;
                                end case;
                                -- seta as flags logicas de acordo com o resultado da operacao
                                zero_flag_reg <= (ALU_FLAGS(4) = '1');
                                greater_flag_reg <= (ALU_FLAGS(3) = '1');
                                equal_flag_reg <= (ALU_FLAGS(2) = '1');
                                smaller_flag_reg <= (ALU_FLAGS(1) = '1');
                                carry_flag_reg <= (ALU_FLAGS(0) = '1');
                                -- incrementa o PC e MAR para a proxima instrucao
                                PC <= std_logic_vector(unsigned(PC) + 1);
                                MAR <= std_logic_vector(unsigned(PC) + 1);
                                exec_done := true;

                            when MEM =>
                                case MEMORY_OP is
                                    when PUSH =>
                                        SP <= SP - 1;
                                        PC <= std_logic_vector(unsigned(PC) + 1);
                                        MAR <= std_logic_vector(unsigned(PC) + 1);
                                        
                                    when POP =>
                                        -- No POP, LD e LDR, o dado lido vai da RAM direto pro Registrador
                                        REG(to_integer(unsigned(op1))) <= RAM_DOUT;
                                        SP <= SP + 1;
                                        PC <= std_logic_vector(unsigned(PC) + 1);
                                        MAR <= std_logic_vector(unsigned(PC) + 1);
                                        
                                    when ST =>
                                        PC <= std_logic_vector(unsigned(PC) + 2);
                                        MAR <= std_logic_vector(unsigned(PC) + 2);
                                        
                                    when LD =>
                                        REG(to_integer(unsigned(op1))) <= RAM_DOUT;
                                        PC <= std_logic_vector(unsigned(PC) + 2);
                                        MAR <= std_logic_vector(unsigned(PC) + 2);
                                        
                                    when LDR | STR | MOV =>
                                        if MEMORY_OP = LDR then
                                            REG(to_integer(unsigned(op1))) <= RAM_DOUT;
                                        elsif MEMORY_OP = MOV then
                                            REG(to_integer(unsigned(op1))) <= REG(to_integer(unsigned(op2)));
                                        end if;
                                        PC <= std_logic_vector(unsigned(PC) + 1);
                                        MAR <= std_logic_vector(unsigned(PC) + 1);
                                        
                                    when others => null;
                                end case;
                                exec_done := true;

                            when JUMP =>
                                case JUMP_OP is
                                    when JMP =>
                                        PC <= RAM_DOUT;
                                        MAR <= RAM_DOUT;
                                    when JMPR =>
                                        PC <= REG(to_integer(unsigned(op1)));
                                        MAR <= REG(to_integer(unsigned(op1)));
                                    when BZ =>
                                        if zero_flag_reg then
                                            PC <= REG(to_integer(unsigned(op1)));
                                            MAR <= REG(to_integer(unsigned(op1)));
                                        else
                                            PC <= std_logic_vector(unsigned(PC) + 1);
                                            MAR <= std_logic_vector(unsigned(PC) + 1);
                                        end if;
                                    when BNZ =>
                                        if not zero_flag_reg then
                                            PC <= REG(to_integer(unsigned(op1)));
                                            MAR <= REG(to_integer(unsigned(op1)));
                                        else
                                            PC <= std_logic_vector(unsigned(PC) + 1);
                                            MAR <= std_logic_vector(unsigned(PC) + 1);
                                        end if;
                                    when BCS =>
                                        if carry_flag_reg then
                                            PC <= REG(to_integer(unsigned(op1)));
                                            MAR <= REG(to_integer(unsigned(op1)));
                                        else
                                            PC <= std_logic_vector(unsigned(PC) + 1);
                                            MAR <= std_logic_vector(unsigned(PC) + 1);
                                        end if;
                                    when BCC =>
                                        if not carry_flag_reg then
                                            PC <= REG(to_integer(unsigned(op1)));
                                            MAR <= REG(to_integer(unsigned(op1)));
                                        else
                                            PC <= std_logic_vector(unsigned(PC) + 1);
                                            MAR <= std_logic_vector(unsigned(PC) + 1);
                                        end if;
                                    when BEQ =>
                                        if equal_flag_reg then
                                            PC <= REG(to_integer(unsigned(op1)));
                                            MAR <= REG(to_integer(unsigned(op1)));
                                        else
                                            PC <= std_logic_vector(unsigned(PC) + 1);
                                            MAR <= std_logic_vector(unsigned(PC) + 1);
                                        end if;
                                    when BNEQ =>
                                        if not equal_flag_reg then
                                            PC <= REG(to_integer(unsigned(op1)));
                                            MAR <= REG(to_integer(unsigned(op1)));
                                        else
                                            PC <= std_logic_vector(unsigned(PC) + 1);
                                            MAR <= std_logic_vector(unsigned(PC) + 1);
                                        end if;
                                    when BGT =>
                                        if greater_flag_reg then
                                            PC <= REG(to_integer(unsigned(op1)));
                                            MAR <= REG(to_integer(unsigned(op1)));
                                        else
                                            PC <= std_logic_vector(unsigned(PC) + 1);
                                            MAR <= std_logic_vector(unsigned(PC) + 1);
                                        end if;
                                    when BLT =>
                                        if smaller_flag_reg then
                                            PC <= REG(to_integer(unsigned(op1)));
                                            MAR <= REG(to_integer(unsigned(op1)));
                                        else
                                            PC <= std_logic_vector(unsigned(PC) + 1);
                                            MAR <= std_logic_vector(unsigned(PC) + 1);
                                        end if;
                                    when others => 
                                        -- incrementa o PC e MAR para a proxima instrucao por segurança
                                        -- para evitar ficar preso em um loop infinito caso 
                                        -- a instrução de salto não seja reconhecida
                                        PC <= std_logic_vector(unsigned(PC) + 1);
                                        MAR <= std_logic_vector(unsigned(PC) + 1);
                                end case;
                                exec_done := true;

                            when HALT =>
                                exec_done := false;
                        end case;

                        if exec_done = true then
                            exec_done := false;
                            STATE <= FETCH;
                        end if;
                        
                    when others =>
                        STATE <= FETCH;
                        
                end case;
            end if;
        end if;
    end process p_fsm_cycle;
    
    RAM_ADDR <= MAR;
    RAM_DIN  <= MBR;
    IR_OUT   <= IR;
    FLAG_ZERO    <= '1' when zero_flag_reg = true else    '0';
    FLAG_CARRY   <= '1' when carry_flag_reg = true else   '0';
    FLAG_EQUAL   <= '1' when equal_flag_reg = true else   '0';
    FLAG_GREATER <= '1' when greater_flag_reg = true else '0';
    FLAG_SMALLER <= '1' when smaller_flag_reg = true else '0';
    
end Behavioral;
