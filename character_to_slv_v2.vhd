-- ASCII_A_INT <= character'pos('a'); --returns the 'a' ascii value (integer)

TYPE rom_str IS ARRAY(0 TO 31) OF std_logic_vector(3 DOWNTO 0); -- linha com 16 chars / 32bits

FUNCTION to_std_logic_vector(a : STRING) RETURN rom_str IS
    VARIABLE chr2slv               : std_logic_vector(7 DOWNTO 0);
    VARIABLE ret                   : rom_str;
BEGIN
    FOR i IN a'RANGE LOOP
        chr2slv              := std_logic_vector(to_unsigned(CHARACTER'pos(a(i)), 8));
        ret(2 * (i - 1) + 0) := chr2slv(7 DOWNTO 4);
        ret(2 * (i - 1) + 1) := chr2slv(3 DOWNTO 0);
    END LOOP;
    RETURN ret;
END FUNCTION to_std_logic_vector;
 
CONSTANT STR_ADD  : rom_str := to_std_logic_vector("add Rx, Ry      ");
CONSTANT STR_SUB  : rom_str := to_std_logic_vector("sub Rx, Ry      ");
CONSTANT STR_INC  : rom_str := to_std_logic_vector("inc Rx          ");
CONSTANT STR_INCC : rom_str := to_std_logic_vector("incc Rx         ");
CONSTANT STR_DEC  : rom_str := to_std_logic_vector("dec Rx          ");
CONSTANT STR_DECC : rom_str := to_std_logic_vector("decc Rx         ");
CONSTANT STR_AND  : rom_str := to_std_logic_vector("AND Rx, Ry      ");
CONSTANT STR_OR   : rom_str := to_std_logic_vector("OR Rx, Ry       ");
CONSTANT STR_NOT  : rom_str := to_std_logic_vector("NOT Rx          ");
CONSTANT STR_XOR  : rom_str := to_std_logic_vector("XOR Rx, Ry      ");
CONSTANT STR_ROL  : rom_str := to_std_logic_vector("ROL Rx          ");
CONSTANT STR_ROR  : rom_str := to_std_logic_vector("ROR Rx          ");
CONSTANT STR_LSL  : rom_str := to_std_logic_vector("lsl Rx          ");
CONSTANT STR_LSR  : rom_str := to_std_logic_vector("lsr Rx          ");
CONSTANT STR_PUSH : rom_str := to_std_logic_vector("push Rx         ");
CONSTANT STR_POP  : rom_str := to_std_logic_vector("pop Rx          ");
CONSTANT STR_LD   : rom_str := to_std_logic_vector("ld Rx, 0x--     ");
CONSTANT STR_LDR  : rom_str := to_std_logic_vector("ldr Rx, [Ry]    ");
CONSTANT STR_STR  : rom_str := to_std_logic_vector("str Rx, [Ry]    ");
CONSTANT STR_JMP  : rom_str := to_std_logic_vector("jmp 0x--        ");
CONSTANT STR_JMPR : rom_str := to_std_logic_vector("jmpr Rx         ");
CONSTANT STR_BZ   : rom_str := to_std_logic_vector("bz Rx           ");
CONSTANT STR_BNZ  : rom_str := to_std_logic_vector("bnz Rx          ");
CONSTANT STR_BCS  : rom_str := to_std_logic_vector("bcs Rx          ");
CONSTANT STR_BCC  : rom_str := to_std_logic_vector("bcc Rx          ");
CONSTANT STR_BEQ  : rom_str := to_std_logic_vector("beq Rx          ");
CONSTANT STR_BNEQ : rom_str := to_std_logic_vector("bneq Rx         ");
CONSTANT STR_BGT  : rom_str := to_std_logic_vector("bgt Rx          ");
CONSTANT STR_BGEZ : rom_str := to_std_logic_vector("bgez Rx         ");
CONSTANT STR_BLT  : rom_str := to_std_logic_vector("blt Rx          ");
CONSTANT STR_BLEZ : rom_str := to_std_logic_vector("blez Rx         "); 
CONSTANT STR_HALT : rom_str := to_std_logic_vector("halt            ");


    function to_std_logic_vector(a : string) return std_logic_vector is
        variable ret : std_logic_vector(a'length*8-1 downto 0);
    begin
        for i in a'range loop
            ret(i*8+7 downto i*8) := std_logic_vector(to_unsigned(character'pos(a(i)), 8));
        end loop;
        return ret;
    end function to_std_logic_vector;

    type TEXT_MAP_ROM_t is array (0 to 255) of std_logic_vector(8*16-1 downto 0);

    constant TEXT_MAP_ROM : TEXT_MAP_ROM_t := (
        -- add Rx, Ry
          0 => to_std_logic_vector("add RA, RA      "),
          1 => to_std_logic_vector("add RA, RB      "),
          2 => to_std_logic_vector("add RA, RC      "),
          3 => to_std_logic_vector("add RA, RD      "),
          4 => to_std_logic_vector("add RB, RA      "),
          5 => to_std_logic_vector("add RB, RB      "),
          6 => to_std_logic_vector("add RB, RC      "),
          7 => to_std_logic_vector("add RB, RD      "),
          8 => to_std_logic_vector("add RC, RA      "),
        -- halt
        240 => to_std_logic_vector("halt            "),
        others => to_std_logic_vector("invalid instr.  ")
    );

FUNCTION to_bcd(Binary : unsigned) RETURN unsigned IS
    VARIABLE b             : unsigned(Binary'LENGTH - 1 DOWNTO 0) := Binary;
    CONSTANT DIGITS        : NATURAL := decimal_size(2 ** Binary'LENGTH - 1);
    VARIABLE bcd           : unsigned(DIGITS * 4 - 1 DOWNTO 0) := (OTHERS => '0');
BEGIN
    FOR i IN b'RANGE LOOP
        -- iterate over each group of 4 bits that comprise a digit
        FOR d IN 0 TO DIGITS - 1 LOOP
            IF bcd(d * 4 + 3 DOWNTO d * 4) >= 5 THEN -- will be 10 to 18 on next shift
                -- add 3 to make it carry over to next digit on next shift
                -- (5+3)*2 = 16 = 2#1_0000#
                bcd(d * 4 + 3 DOWNTO d * 4) := bcd(d * 4 + 3 DOWNTO d * 4) + 3;
            END IF;
        END LOOP;
        -- shift left -> multiply by 2
        bcd := bcd(bcd'LEFT - 1 DOWNTO 0) & b(b'left);
        b   := b(b'LEFT - 1 DOWNTO 0) & '0';
    END LOOP; RETURN bcd;
END FUNCTION;