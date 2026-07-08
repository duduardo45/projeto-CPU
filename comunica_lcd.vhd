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
    constant L2_TXT : byte_array(0 to 9) := (x"4D", x"45", x"4D", x"5B", x"32", x"35", x"35", x"5D", x"3A", x"20"); -- o que é esse texto? 

    
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

    -- Função 2: Converte String de Texto para Vetor de Bits (Corrigida)
    function to_std_logic_vector(a : string) return std_logic_vector is
        variable ret : std_logic_vector(a'length*8-1 downto 0);
    begin
        for i in a'range loop
            -- a'high é o tamanho máximo (ex: 16). 
            -- Quando i=1 (primeira letra), vai para os bits 127 downto 120.
            -- Quando i=16 (última letra), vai para os bits 7 downto 0.
            ret((a'high - i)*8 + 7 downto (a'high - i)*8) := std_logic_vector(to_unsigned(character'pos(a(i)), 8));
        end loop;
        return ret;
    end function to_std_logic_vector;

    -- A Tabela ROM (O "Dicionário" do professor Calliari)
    type TEXT_MAP_ROM_t is array (0 to 255) of std_logic_vector(8*16-1 downto 0);
    constant TEXT_MAP_ROM : TEXT_MAP_ROM_t := (
        -- === OPERAÇÕES ARITMÉTICAS (0000 a 0010) ===
        -- add Rx, Ry (0000 Rx Ry)
        0 => to_std_logic_vector("add RA, RA      "),
        1 => to_std_logic_vector("add RA, RB      "),
        2 => to_std_logic_vector("add RA, RC      "),
        3 => to_std_logic_vector("add RA, RD      "),
        4 => to_std_logic_vector("add RB, RA      "),
        5 => to_std_logic_vector("add RB, RB      "),
        6 => to_std_logic_vector("add RB, RC      "),
        7 => to_std_logic_vector("add RB, RD      "),
        8 => to_std_logic_vector("add RC, RA      "),
        9 => to_std_logic_vector("add RC, RB      "),
        10 => to_std_logic_vector("add RC, RC      "),
        11 => to_std_logic_vector("add RC, RD      "),
        12 => to_std_logic_vector("add RD, RA      "),
        13 => to_std_logic_vector("add RD, RB      "),
        14 => to_std_logic_vector("add RD, RC      "),
        15 => to_std_logic_vector("add RD, RD      "),

        -- sub Rx, Ry (0001 Rx Ry)
        16 => to_std_logic_vector("sub RA, RA      "),
        17 => to_std_logic_vector("sub RA, RB      "),
        18 => to_std_logic_vector("sub RA, RC      "),
        19 => to_std_logic_vector("sub RA, RD      "),
        20 => to_std_logic_vector("sub RB, RA      "),
        21 => to_std_logic_vector("sub RB, RB      "),
        22 => to_std_logic_vector("sub RB, RC      "),
        23 => to_std_logic_vector("sub RB, RD      "),
        24 => to_std_logic_vector("sub RC, RA      "),
        25 => to_std_logic_vector("sub RC, RB      "),
        26 => to_std_logic_vector("sub RC, RC      "),
        27 => to_std_logic_vector("sub RC, RD      "),
        28 => to_std_logic_vector("sub RD, RA      "),
        29 => to_std_logic_vector("sub RD, RB      "),
        30 => to_std_logic_vector("sub RD, RC      "),
        31 => to_std_logic_vector("sub RD, RD      "),

        -- inc Rx / dec Rx (0010 Rx YY)
        32 => to_std_logic_vector("inc RA          "), -- 0010 00 00
        33 => to_std_logic_vector("dec RA          "), -- 0010 00 01

        34 => to_std_logic_vector("0x22          NA"), -- 0010 00 10 (não usado)
        35 => to_std_logic_vector("0x23          NA"), -- 0010 00 11 (não usado)

        36 => to_std_logic_vector("inc RB          "), -- 0010 01 00
        37 => to_std_logic_vector("dec RB          "), -- 0010 01 01

        38 => to_std_logic_vector("0x26          NA"), -- 0010 01 10 (não usado)
        39 => to_std_logic_vector("0x27          NA"), -- 0010 01 11 (não usado)

        40 => to_std_logic_vector("inc RC          "), -- 0010 10 00
        41 => to_std_logic_vector("dec RC          "), -- 0010 10 01

        42 => to_std_logic_vector("0x2A          NA"), -- 0010 10 10 (não usado)
        43 => to_std_logic_vector("0x2B          NA"), -- 0010 10 11 (não usado)

        44 => to_std_logic_vector("inc RD          "), -- 0010 11 00
        45 => to_std_logic_vector("dec RD          "), -- 0010 11 01

        46 => to_std_logic_vector("0x2E          NA"), -- 0010 11 10 (não usado)
        47 => to_std_logic_vector("0x2F          NA"), -- 0010 11 11 (não usado)


        -- === OPERAÇÕES LÓGICAS (0011 a 0111) ===
        -- and Rx, Ry (0011 Rx Ry)
        48 => to_std_logic_vector("and RA, RA      "),
        49 => to_std_logic_vector("and RA, RB      "),
        50 => to_std_logic_vector("and RA, RC      "),
        51 => to_std_logic_vector("and RA, RD      "),
        52 => to_std_logic_vector("and RB, RA      "),
        53 => to_std_logic_vector("and RB, RB      "),
        54 => to_std_logic_vector("and RB, RC      "),
        55 => to_std_logic_vector("and RB, RD      "),
        56 => to_std_logic_vector("and RC, RA      "),
        57 => to_std_logic_vector("and RC, RB      "),
        58 => to_std_logic_vector("and RC, RC      "),
        59 => to_std_logic_vector("and RC, RD      "),
        60 => to_std_logic_vector("and RD, RA      "),
        61 => to_std_logic_vector("and RD, RB      "),
        62 => to_std_logic_vector("and RD, RC      "),
        63 => to_std_logic_vector("and RD, RD      "),

        -- or Rx, Ry (0100 Rx Ry)
        64 => to_std_logic_vector("or RA, RA       "),
        65 => to_std_logic_vector("or RA, RB       "),
        66 => to_std_logic_vector("or RA, RC       "),
        67 => to_std_logic_vector("or RA, RD       "),
        68 => to_std_logic_vector("or RB, RA       "),
        69 => to_std_logic_vector("or RB, RB       "),
        70 => to_std_logic_vector("or RB, RC       "),
        71 => to_std_logic_vector("or RB, RD       "),
        72 => to_std_logic_vector("or RC, RA       "),
        73 => to_std_logic_vector("or RC, RB       "),
        74 => to_std_logic_vector("or RC, RC       "),
        75 => to_std_logic_vector("or RC, RD       "),
        76 => to_std_logic_vector("or RD, RA       "),
        77 => to_std_logic_vector("or RD, RB       "),
        78 => to_std_logic_vector("or RD, RC       "),
        79 => to_std_logic_vector("or RD, RD       "),

        -- not Rx (0101 Rx 00)
        80 => to_std_logic_vector("not RA          "),

        81 => to_std_logic_vector("0x51          NA"), -- 0101 00 01 (não usado)
        82 => to_std_logic_vector("0x52          NA"), -- 0101 00 10 (não usado)
        83 => to_std_logic_vector("0x53          NA"), -- 0101 00 11 (não usado)
        
        84 => to_std_logic_vector("not RB          "),
        
        85 => to_std_logic_vector("0x55          NA"), -- 0101 01 01 (não usado)
        86 => to_std_logic_vector("0x56          NA"), -- 0101 01 10 (não usado)
        87 => to_std_logic_vector("0x57          NA"), -- 0101 01 11 (não usado)
        
        88 => to_std_logic_vector("not RC          "),
        
        89 => to_std_logic_vector("0x59          NA"), -- 0101 10 01 (não usado)
        90 => to_std_logic_vector("0x5A          NA"), -- 0101 10 10 (não usado)
        91 => to_std_logic_vector("0x5B          NA"), -- 0101 10 11 (não usado)
        
        92 => to_std_logic_vector("not RD          "),

        93 => to_std_logic_vector("0x5D          NA"), -- 0101 11 01 (não usado)
        94 => to_std_logic_vector("0x5E          NA"), -- 0101 11 10 (não usado)
        95 => to_std_logic_vector("0x5F          NA"), -- 0101 11 11 (não usado)
        
        -- xor Rx, Ry (0110 Rx Ry)
        96 => to_std_logic_vector("xor RA, RA      "),
        97 => to_std_logic_vector("xor RA, RB      "),
        98 => to_std_logic_vector("xor RA, RC      "),
        99 => to_std_logic_vector("xor RA, RD      "),
        100 => to_std_logic_vector("xor RB, RA      "),
        101 => to_std_logic_vector("xor RB, RB      "),
        102 => to_std_logic_vector("xor RB, RC      "),
        103 => to_std_logic_vector("xor RB, RD      "),
        104 => to_std_logic_vector("xor RC, RA      "),
        105 => to_std_logic_vector("xor RC, RB      "),
        106 => to_std_logic_vector("xor RC, RC      "),
        107 => to_std_logic_vector("xor RC, RD      "),
        108 => to_std_logic_vector("xor RD, RA      "),
        109 => to_std_logic_vector("xor RD, RB      "),
        110 => to_std_logic_vector("xor RD, RC      "),
        111 => to_std_logic_vector("xor RD, RD      "),

        -- Deslocamentos rol/ror/lsl/lsr (0111 Rx YY)
        112 => to_std_logic_vector("rol RA          "), -- 0111 00 00
        113 => to_std_logic_vector("ror RA          "), -- 0111 00 01
        114 => to_std_logic_vector("lsl RA          "), -- 0111 00 10
        115 => to_std_logic_vector("lsr RA          "), -- 0111 00 11
        116 => to_std_logic_vector("rol RB          "), -- 0111 01 00
        117 => to_std_logic_vector("ror RB          "), -- 0111 01 01
        118 => to_std_logic_vector("lsl RB          "), -- 0111 01 10
        119 => to_std_logic_vector("lsr RB          "), -- 0111 01 11
        120 => to_std_logic_vector("rol RC          "), -- 0111 10 00
        121 => to_std_logic_vector("ror RC          "), -- 0111 10 01
        122 => to_std_logic_vector("lsl RC          "), -- 0111 10 10
        123 => to_std_logic_vector("lsr RC          "), -- 0111 10 11
        124 => to_std_logic_vector("rol RD          "), -- 0111 11 00
        125 => to_std_logic_vector("ror RD          "), -- 0111 11 01
        126 => to_std_logic_vector("lsl RD          "), -- 0111 11 10
        127 => to_std_logic_vector("lsr RD          "), -- 0111 11 11

        -- === MEMÓRIA (1000 a 1011) ===
        -- push/pop/st/ld (1000 Rx YY)
        128 => to_std_logic_vector("push RA         "), -- 1000 00 00
        129 => to_std_logic_vector("pop RA          "), -- 1000 00 01
        130 => to_std_logic_vector("st RA, 0x--     "), -- 1000 00 10
        131 => to_std_logic_vector("ld RA, 0x--     "), -- 1000 00 11
        132 => to_std_logic_vector("push RB         "), -- 1000 01 00
        133 => to_std_logic_vector("pop RB          "), -- 1000 01 01
        134 => to_std_logic_vector("st RB, 0x--     "), -- 1000 01 10
        135 => to_std_logic_vector("ld RB, 0x--     "), -- 1000 01 11
        136 => to_std_logic_vector("push RC         "), -- 1000 10 00
        137 => to_std_logic_vector("pop RC          "), -- 1000 10 01
        138 => to_std_logic_vector("st RC, 0x--     "), -- 1000 10 10
        139 => to_std_logic_vector("ld RC, 0x--     "), -- 1000 10 11
        140 => to_std_logic_vector("push RD         "), -- 1000 11 00
        141 => to_std_logic_vector("pop RD          "), -- 1000 11 01
        142 => to_std_logic_vector("st RD, 0x--     "), -- 1000 11 10
        143 => to_std_logic_vector("ld RD, 0x--     "), -- 1000 11 11

        -- ldr Rx, [Ry] (1001 Rx Ry)
        144 => to_std_logic_vector("ldr RA, [RA]    "),
        145 => to_std_logic_vector("ldr RA, [RB]    "),
        146 => to_std_logic_vector("ldr RA, [RC]    "),
        147 => to_std_logic_vector("ldr RA, [RD]    "),
        148 => to_std_logic_vector("ldr RB, [RA]    "),
        149 => to_std_logic_vector("ldr RB, [RB]    "),
        150 => to_std_logic_vector("ldr RB, [RC]    "),
        151 => to_std_logic_vector("ldr RB, [RD]    "),
        152 => to_std_logic_vector("ldr RC, [RA]    "),
        153 => to_std_logic_vector("ldr RC, [RB]    "),
        154 => to_std_logic_vector("ldr RC, [RC]    "),
        155 => to_std_logic_vector("ldr RC, [RD]    "),
        156 => to_std_logic_vector("ldr RD, [RA]    "),
        157 => to_std_logic_vector("ldr RD, [RB]    "),
        158 => to_std_logic_vector("ldr RD, [RC]    "),
        159 => to_std_logic_vector("ldr RD, [RD]    "),

        -- str Rx, [Ry] (1010 Rx Ry)
        160 => to_std_logic_vector("str RA, [RA]    "),
        161 => to_std_logic_vector("str RA, [RB]    "),
        162 => to_std_logic_vector("str RA, [RC]    "),
        163 => to_std_logic_vector("str RA, [RD]    "),
        164 => to_std_logic_vector("str RB, [RA]    "),
        165 => to_std_logic_vector("str RB, [RB]    "),
        166 => to_std_logic_vector("str RB, [RC]    "),
        167 => to_std_logic_vector("str RB, [RD]    "),
        168 => to_std_logic_vector("str RC, [RA]    "),
        169 => to_std_logic_vector("str RC, [RB]    "),
        170 => to_std_logic_vector("str RC, [RC]    "),
        171 => to_std_logic_vector("str RC, [RD]    "),
        172 => to_std_logic_vector("str RD, [RA]    "),
        173 => to_std_logic_vector("str RD, [RB]    "),
        174 => to_std_logic_vector("str RD, [RC]    "),
        175 => to_std_logic_vector("str RD, [RD]    "),

        -- mov Rx, Ry (1011 Rx Ry)
        176 => to_std_logic_vector("mov RA, RA      "),
        177 => to_std_logic_vector("mov RA, RB      "),
        178 => to_std_logic_vector("mov RA, RC      "),
        179 => to_std_logic_vector("mov RA, RD      "),
        180 => to_std_logic_vector("mov RB, RA      "),
        181 => to_std_logic_vector("mov RB, RB      "),
        182 => to_std_logic_vector("mov RB, RC      "),
        183 => to_std_logic_vector("mov RB, RD      "),
        184 => to_std_logic_vector("mov RC, RA      "),
        185 => to_std_logic_vector("mov RC, RB      "),
        186 => to_std_logic_vector("mov RC, RC      "),
        187 => to_std_logic_vector("mov RC, RD      "),
        188 => to_std_logic_vector("mov RD, RA      "),
        189 => to_std_logic_vector("mov RD, RB      "),
        190 => to_std_logic_vector("mov RD, RC      "),
        191 => to_std_logic_vector("mov RD, RD      "),

        -- === SALTOS / JUMPS (1100 a 1110) ===
        -- Incondicional e Condicionais (Grupo 1: 1100 Rx YY)
        192 => to_std_logic_vector("jmp 0x--        "), -- 1100 00 00 (Rx ignorado)
        193 => to_std_logic_vector("jmpr RA         "), -- 1100 00 01
        194 => to_std_logic_vector("bz RA           "), -- 1100 00 10
        195 => to_std_logic_vector("bnz RA          "), -- 1100 00 11
        
        196 => to_std_logic_vector("0xC4          NA"), -- 1100 01 00 (não usado)

        197 => to_std_logic_vector("jmpr RB         "), -- 1100 01 01
        198 => to_std_logic_vector("bz RB           "), -- 1100 01 10
        199 => to_std_logic_vector("bnz RB          "), -- 1100 01 11

        200 => to_std_logic_vector("0xC8          NA"), -- 1100 10 00 (não usado)
        
        201 => to_std_logic_vector("jmpr RC         "), -- 1100 10 01
        202 => to_std_logic_vector("bz RC           "), -- 1100 10 10
        203 => to_std_logic_vector("bnz RC          "), -- 1100 10 11

        204 => to_std_logic_vector("0xCC          NA"), -- 1100 11 00 (não usado)
        
        205 => to_std_logic_vector("jmpr RD         "), -- 1100 11 01
        206 => to_std_logic_vector("bz RD           "), -- 1100 11 10
        207 => to_std_logic_vector("bnz RD          "), -- 1100 11 11

        -- Condicionais (Grupo 2: 1101 Rx YY)
        208 => to_std_logic_vector("bcs RA          "), -- 1101 00 00
        209 => to_std_logic_vector("bcc RA          "), -- 1101 00 01
        210 => to_std_logic_vector("beq RA          "), -- 1101 00 10
        211 => to_std_logic_vector("bneq RA         "), -- 1101 00 11
        212 => to_std_logic_vector("bcs RB          "), -- 1101 01 00
        213 => to_std_logic_vector("bcc RB          "), -- 1101 01 01
        214 => to_std_logic_vector("beq RB          "), -- 1101 01 10
        215 => to_std_logic_vector("bneq RB         "), -- 1101 01 11
        216 => to_std_logic_vector("bcs RC          "), -- 1101 10 00
        217 => to_std_logic_vector("bcc RC          "), -- 1101 10 01
        218 => to_std_logic_vector("beq RC          "), -- 1101 10 10
        219 => to_std_logic_vector("bneq RC         "), -- 1101 10 11
        220 => to_std_logic_vector("bcs RD          "), -- 1101 11 00
        221 => to_std_logic_vector("bcc RD          "), -- 1101 11 01
        222 => to_std_logic_vector("beq RD          "), -- 1101 11 10
        223 => to_std_logic_vector("bneq RD         "), -- 1101 11 11

        -- Condicionais (Grupo 3: 1110 Rx YY)
        224 => to_std_logic_vector("bgt RA          "), -- 1110 00 00
        225 => to_std_logic_vector("blt RA          "), -- 1110 00 01
        
        226 => to_std_logic_vector("0xE2          NA"), -- 1110 00 10 (não usado)
        227 => to_std_logic_vector("0xE3          NA"), -- 1110 00 11 (não usado)
        
        228 => to_std_logic_vector("bgt RB          "), -- 1110 01 00
        229 => to_std_logic_vector("blt RB          "), -- 1110 01 01
        
        230 => to_std_logic_vector("0xE6          NA"), -- 1110 01 10 (não usado)
        231 => to_std_logic_vector("0xE7          NA"), -- 1110 01 11 (não usado)
        
        232 => to_std_logic_vector("bgt RC          "), -- 1110 10 00
        233 => to_std_logic_vector("blt RC          "), -- 1110 10 01
        
        234 => to_std_logic_vector("0xEA          NA"), -- 1110 10 10 (não usado)
        235 => to_std_logic_vector("0xEB          NA"), -- 1110 10 11 (não usado)
        
        236 => to_std_logic_vector("bgt RD          "), -- 1110 11 00
        237 => to_std_logic_vector("blt RD          "), -- 1110 11 01

        238 => to_std_logic_vector("0xEE          NA"), -- 1110 11 10 (não usado)
        239 => to_std_logic_vector("0xEF          NA"), -- 1110 11 11 (não usado)
        
        -- === CONTROLE (1111) ===
        240 => to_std_logic_vector("halt            "), -- 1111 00 00

        241 => to_std_logic_vector("0xF1          NA"), -- 1111 00 01 (não usado)
        242 => to_std_logic_vector("0xF2          NA"), -- 1111 00 10 (não usado)
        243 => to_std_logic_vector("0xF3          NA"), -- 1111 00 11 (não usado)
        244 => to_std_logic_vector("0xF4          NA"), -- 1111 01 00 (não usado)
        245 => to_std_logic_vector("0xF5          NA"), -- 1111 01 01 (não usado)
        246 => to_std_logic_vector("0xF6          NA"), -- 1111 01 10 (não usado)
        247 => to_std_logic_vector("0xF7          NA"), -- 1111 01 11 (não usado)
        248 => to_std_logic_vector("0xF8          NA"), -- 1111 10 00 (não usado)
        249 => to_std_logic_vector("0xF9          NA"), -- 1111 10 01 (não usado)
        250 => to_std_logic_vector("0xFA          NA"), -- 1111 10 10 (não usado)
        251 => to_std_logic_vector("0xFB          NA"), -- 1111 10 11 (não usado)
        252 => to_std_logic_vector("0xFC          NA"), -- 1111 11 00 (não usado)
        253 => to_std_logic_vector("0xFD          NA"), -- 1111 11 01 (não usado)
        254 => to_std_logic_vector("0xFE          NA"), -- 1111 11 10 (não usado)
        255 => to_std_logic_vector("0xFF          NA"), -- 1111 11 11 (não usado)

        -- Qualquer OpCode não mapeado
        others => to_std_logic_vector("INVALID OPCODE  ")
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
          rs_reg when state = state_on else
          rs_reg;
    
end Behavioral;

