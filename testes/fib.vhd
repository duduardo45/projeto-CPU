library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity FIB is
    port(
        CLK     : in std_logic;
        DIN     : in std_logic_vector(7 downto 0);
        ADDR    : in std_logic_vector(7 downto 0);
        WE      : in std_logic;
        DOUT    : out std_logic_vector(7 downto 0);
        POS_255 : out std_logic_vector(7 downto 0)
    );
end FIB;

architecture rtl of FIB is
    
    type RAM_t is array(0 to 255) of std_logic_vector(7 downto 0);
    signal read_address : std_logic_vector(7 downto 0) := (others => '0');

    -- fib.asm
    signal ram : RAM_t := (
        0   => "10000011", --  11:                   ld ra, 0
        1   => "00000000", --  11:                   0
        2   => "10000000", --  12:                   push ra
        3   => "10000000", --  13:                   push ra
        4   => "10000000", --  14:                   push ra
        5   => "10000001", --  17:                   pop ra
        6   => "10000001", --  18:                   pop ra
        7   => "10000001", --  19:                   pop ra
        8   => "00100000", --  21:                   inc ra
        9   => "10000000", --  23:                   push ra
        10  => "10000000", --  24:                   push ra
        11  => "10000000", --  25:                   push ra
        12  => "10001111", --  27:                   ld rd, @loop_count
        13  => "00000011", --  27:                   3
        14  => "00111100", --  28:                   and rd, ra
        15  => "10001111", --  29:                   ld rd, @end_loop
        16  => "00100100", --  29:                   36
        17  => "11011110", --  30:                   beq rd
        18  => "10001111", --  33:                   ld rd, @fib_stop
        19  => "01100000", --  33:                   96
        20  => "00111100", --  34:                   and rd, ra
        21  => "10001111", --  35:                   ld rd, @loop
        22  => "00000101", --  35:                   5
        23  => "11101101", --  36:                   blt rd
        24  => "10000101", --  38:                   pop rb
        25  => "10000001", --  39:                   pop ra
        26  => "10000000", --  40:                   push ra
        27  => "10001001", --  41:                   pop rc
        28  => "00000001", --  43:                   add ra, rb
        29  => "10001111", --  44:                   ld rd, @io
        30  => "11111111", --  44:                   255
        31  => "10100011", --  45:                   str ra, [rd]
        32  => "10000000", --  47:                   push ra
        33  => "10001000", --  48:                   push rc
        34  => "11000000", --  50:                   jmp @loop_fib
        35  => "00010010", --  50:                   18
        36  => "10000001", --  55:                   pop ra
        37  => "10000001", --  56:                   pop ra
        38  => "10000001", --  57:                   pop ra
        39  => "10000011", --  59:                   ld ra, @shift_init_value
        40  => "11111110", --  59:                   254
        41  => "10001111", --  63:                   ld rd, @io
        42  => "11111111", --  63:                   255
        43  => "10100011", --  64:                   str ra, [rd]
        44  => "01110011", --  65:                   lsr ra
        45  => "10001111", --  67:                   ld rd, 0
        46  => "00000000", --  67:                   0
        47  => "00111100", --  68:                   and rd, ra
        48  => "10001111", --  69:                   ld rd, @shift_loop
        49  => "00101001", --  69:                   41
        50  => "11011111", --  70:                   bneq rd
        51  => "10000011", --  72:                   ld ra, 10
        52  => "00001010", --  72:                   10
        53  => "10000000", --  73:                   push ra
        54  => "10000000", --  74:                   push ra
        55  => "00001100", --  76:                   add rd, ra
        56  => "10001111", --  80:                   ld rd, @end_fib_loop2
        57  => "01000111", --  80:                   71
        58  => "11011100", --  81:                   bcs rd
        59  => "10000101", --  83:                   pop rb
        60  => "10000001", --  84:                   pop ra
        61  => "10000000", --  85:                   push ra
        62  => "10001001", --  86:                   pop rc
        63  => "00000001", --  88:                   add ra, rb
        64  => "10001111", --  89:                   ld rd, @io
        65  => "11111111", --  89:                   255
        66  => "10100011", --  90:                   str ra, [rd]
        67  => "10000000", --  92:                   push ra
        68  => "10001000", --  93:                   push rc
        69  => "11000000", --  95:                   jmp @fib_loop2
        70  => "00111000", --  95:                   56
        71  => "10001101", --  99:                   pop rd
        72  => "10001101", -- 100:                   pop rd
        73  => "10000011", -- 102:                   ld ra, @dec_init_value
        74  => "00001010", -- 102:                   10
        75  => "01110010", -- 103:                   lsl ra
        76  => "10001111", -- 104:                   ld rd, @io
        77  => "11111111", -- 104:                   255
        78  => "10001011", -- 105:                   ld rc, @end_dec_loop
        79  => "01010101", -- 105:                   85
        80  => "11001010", -- 109:                   bz rc
        81  => "10100011", -- 111:                   str ra, [rd]
        82  => "00100001", -- 112:                   dec ra
        83  => "11000000", -- 114:                   jmp @dec_loop
        84  => "01010000", -- 114:                   80
        85  => "11110000", -- 118:                   halt
        others => (others => '0')
    );

begin

    process(CLK) is
    begin
        if falling_edge(CLK) then
            if WE = '1' then
                ram(to_integer(unsigned(ADDR))) <= DIN;
            end if;
            read_address <= ADDR;
        end if;
    end process;

    DOUT    <= ram(to_integer(unsigned(read_address)));
    POS_255 <= ram(255);

end architecture;
