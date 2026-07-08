library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu is
    Port ( A : in  STD_LOGIC_VECTOR (7 downto 0);
           B : in  STD_LOGIC_VECTOR (7 downto 0);
           CMD : in  STD_LOGIC_VECTOR (3 downto 0);
           C_in : in  STD_LOGIC;
           C_out : out  STD_LOGIC; -- qual a diferena de C_out e OVERFLOW?
           FLAGS : out  STD_LOGIC_VECTOR (4 downto 0);
           S : out  STD_LOGIC_VECTOR (7 downto 0));
end alu;

architecture Behavioral of alu is


begin

    -- FLAGS TRANSLATION
    -- from MSB to LSB:
    -- ZERO
    -- GREATER -- quando essas outras flags so levantadas? em toda operao?
    -- EQUAL
    -- SMALLER
    -- OVERFLOW
    
    cmd_dec: process(CMD, A, B, C_in)
		variable temp_sum : unsigned(8 downto 0) := (others => '0');
		variable op1, op2, op3      : unsigned(8 downto 0);
		variable sum : STD_LOGIC_VECTOR(8 downto 0) := (others => '0');	
    begin
    -- no tem nenhum sinal de "dispara" no?
	 FLAGS(0) <= '0';
	 FLAGS(4) <= '0'; 
    case CMD is
    when "0000" => -- add
        op1 := unsigned('0' & A);
		op2 := unsigned('0' & B);
		--op3 := unsigned(std_logic_vector("00000000") & C_in); -- não conseguimos resolver infelizmente
		temp_sum := op1 + op2;
        sum := std_logic_vector(temp_sum);
            
        S <= sum(7 downto 0);
        C_out <= sum(8);
        
		  
        if sum(8) = '1' then
            FLAGS(0) <= '1';
        else
			FLAGS(0) <= '0';
		end if;
		
		if sum(7 downto 0) = "00000000" then
			FLAGS(4) <= '1';
		else
			FLAGS(4) <= '0';
		end if;
		
		if unsigned(A) > unsigned(B) then
			FLAGS(3) <= '1';
			FLAGS(2) <= '0';
			FLAGS(1) <= '0';
		elsif unsigned(A) < unsigned(B) then
			FLAGS(3) <= '0';
			FLAGS(2) <= '0';
			FLAGS(1) <= '1';
		else -- EQUAL
			FLAGS(3) <= '0';
			FLAGS(2) <= '1';
			FLAGS(1) <= '0';
		end if;
        
    when "0001" => -- subtraction
        
		op1 := unsigned('1' & A);
		op2 := unsigned('0' & B);
		-- op3 := unsigned("00000000" & C_in); não conseguimos fazer funcionar
        -- falta verificar se isso no crasha quando o resultado daria negativo
		  temp_sum := op1 - op2;
        sum := std_logic_vector(temp_sum);
            
        S <= sum(7 downto 0);
        if sum(8) = '0' then
            C_out <= '1';
            FLAGS(0) <= '1';
        else
            FLAGS(0) <= '0';
			C_out <= '0';
        end if;
		  
		if sum(7 downto 0) = "00000000" then
			FLAGS(4) <= '1';
		else
			FLAGS(4) <= '0';
		end if;
		
		if unsigned(A) > unsigned(B) then
			FLAGS(3) <= '1';
			FLAGS(2) <= '0';
			FLAGS(1) <= '0';
		elsif unsigned(A) < unsigned(B) then
			FLAGS(3) <= '0';
			FLAGS(2) <= '0';
			FLAGS(1) <= '1';
		else -- EQUAL
			FLAGS(3) <= '0';
			FLAGS(2) <= '1';
			FLAGS(1) <= '0';
		end if;
        
    when "0010" => -- increment by 1
		
		temp_sum := ('0' & unsigned(A)) + 1;
        sum := std_logic_vector(temp_sum); -- provavelmente poderia ser s 1
        
        S <= sum(7 downto 0);
        C_out <= sum(8);
        
        
		  
        if sum(8) = '1' then
            FLAGS(0) <= '1';
        else
			FLAGS(0) <= '0';
		end if;
		
		if sum(7 downto 0) = "00000000" then
			FLAGS(4) <= '1';
		else
			FLAGS(4) <= '0';
		end if;
		
		if unsigned(A) > unsigned(B) then
			FLAGS(3) <= '1';
			FLAGS(2) <= '0';
			FLAGS(1) <= '0';
		elsif unsigned(A) < unsigned(B) then
			FLAGS(3) <= '0';
			FLAGS(2) <= '0';
			FLAGS(1) <= '1';
		else -- EQUAL
			FLAGS(3) <= '0';
			FLAGS(2) <= '1';
			FLAGS(1) <= '0';
		end if;
    
    when "0011" => -- and

		temp_sum := unsigned('0' & A) and unsigned('0' & B);
        sum(7 downto 0) := A and B;
        S <= sum(7 downto 0);
		  
		  
        
		  
        if sum(8) = '1' then
            FLAGS(0) <= '1';
        else 
			FLAGS(0) <= '0';
		end if;
		
		if sum(7 downto 0) = "00000000" then
			FLAGS(4) <= '1';
		else
			FLAGS(4) <= '0';
		end if;
		
		if unsigned(A) > unsigned(B) then
			FLAGS(3) <= '1';
			FLAGS(2) <= '0';
			FLAGS(1) <= '0';
		elsif unsigned(A) < unsigned(B) then
			FLAGS(3) <= '0';
			FLAGS(2) <= '0';
			FLAGS(1) <= '1';
		else -- EQUAL
			FLAGS(3) <= '0';
			FLAGS(2) <= '1';
			FLAGS(1) <= '0';
		end if;
    when "0100" => -- or
		temp_sum := unsigned('0' & A) or unsigned('0' & B);
        sum(7 downto 0) := A or B;
        S <= sum(7 downto 0);
		  
		  
        
		  
        if sum(8) = '1' then
            FLAGS(0) <= '1';
        else
			FLAGS(0) <= '0';
		end if;
		
		if sum(7 downto 0) = "00000000" then
			FLAGS(4) <= '1';
		else
			FLAGS(4) <= '0';
		end if;
		
		if unsigned(A) > unsigned(B) then
			FLAGS(3) <= '1';
			FLAGS(2) <= '0';
			FLAGS(1) <= '0';
		elsif unsigned(A) < unsigned(B) then
			FLAGS(3) <= '0';
			FLAGS(2) <= '0';
			FLAGS(1) <= '1';
		else -- EQUAL
			FLAGS(3) <= '0';
			FLAGS(2) <= '1';
			FLAGS(1) <= '0';
		end if;
    when "0101" => -- not
		temp_sum := not unsigned('0' & A);
        sum(7 downto 0) := not A;
        S <= sum(7 downto 0);
		  
		  
        
		  
        if sum(8) = '1' then
            FLAGS(0) <= '1';
        else
			FLAGS(0) <= '0';
		end if;
		
		if sum(7 downto 0) = "00000000" then
			FLAGS(4) <= '1';
		else
			FLAGS(4) <= '0';
		end if;
		
		if unsigned(A) > unsigned(B) then
			FLAGS(3) <= '1';
			FLAGS(2) <= '0';
			FLAGS(1) <= '0';
		elsif unsigned(A) < unsigned(B) then
			FLAGS(3) <= '0';
			FLAGS(2) <= '0';
			FLAGS(1) <= '1';
		else -- EQUAL
			FLAGS(3) <= '0';
			FLAGS(2) <= '1';
			FLAGS(1) <= '0';
		end if;
    when "0110" => -- xor
		temp_sum := unsigned('0' & A) xor unsigned('0' & B);
        sum(7 downto 0) := A xor B;
        S <= sum(7 downto 0);
		  
        
		  
        if sum(8) = '1' then
            FLAGS(0) <= '1';
        else
			FLAGS(0) <= '0';
		end if;
		  
		if sum(7 downto 0) = "00000000" then
			FLAGS(4) <= '1';
		else
			FLAGS(4) <= '0';
		end if;
		
		if unsigned(A) > unsigned(B) then
			FLAGS(3) <= '1';
			FLAGS(2) <= '0';
			FLAGS(1) <= '0';
		elsif unsigned(A) < unsigned(B) then
			FLAGS(3) <= '0';
			FLAGS(2) <= '0';
			FLAGS(1) <= '1';
		else -- EQUAL
			FLAGS(3) <= '0';
			FLAGS(2) <= '1';
			FLAGS(1) <= '0';
		end if;
    when "0111" => -- rotate left 
		temp_sum := unsigned('0' & A(6 downto 0) & A(7));
        sum(7 downto 0) := A(6 downto 0) & A(7);
        S <= sum(7 downto 0);
		  
        
		  
        if sum(8) = '1' then
            FLAGS(0) <= '1';
        else
			FLAGS(0) <= '0';
		end if;
		  
		if sum(7 downto 0) = "00000000" then
			FLAGS(4) <= '1';
		else
			FLAGS(4) <= '0';
		end if;
		
		if unsigned(A) > unsigned(B) then
			FLAGS(3) <= '1';
			FLAGS(2) <= '0';
			FLAGS(1) <= '0';
		elsif unsigned(A) < unsigned(B) then
			FLAGS(3) <= '0';
			FLAGS(2) <= '0';
			FLAGS(1) <= '1';
		else -- EQUAL
			FLAGS(3) <= '0';
			FLAGS(2) <= '1';
			FLAGS(1) <= '0';
		end if;
    when "1000" => -- rotate right
		temp_sum := unsigned('0' & A(0) & A(7 downto 1));
        sum(7 downto 0) := A(0) & A(7 downto 1);
        S <= sum(7 downto 0);
		  
        
		  
        if sum(8) = '1' then
            FLAGS(0) <= '1';
        else
			FLAGS(0) <= '0';
		end if;
		
		if sum(7 downto 0) = "00000000" then
		FLAGS(4) <= '1';
		else
			FLAGS(4) <= '0';
		end if;
		
		if unsigned(A) > unsigned(B) then
			FLAGS(3) <= '1';
			FLAGS(2) <= '0';
			FLAGS(1) <= '0';
		elsif unsigned(A) < unsigned(B) then
			FLAGS(3) <= '0';
			FLAGS(2) <= '0';
			FLAGS(1) <= '1';
		else -- EQUAL
			FLAGS(3) <= '0';
			FLAGS(2) <= '1';
			FLAGS(1) <= '0';
		end if;
    when "1001" => -- shift and lose left
		temp_sum := unsigned('0' & A(6 downto 0) & '0');
        sum(7 downto 0) := A(6 downto 0) & '0';
        S <= sum(7 downto 0);
		  
        
		  
        if sum(8) = '1' then
            FLAGS(0) <= '1';
        else
			FLAGS(0) <= '0';
		end if;
		
		if sum(7 downto 0) = "00000000" then
		FLAGS(4) <= '1';
		else
			FLAGS(4) <= '0';
		end if;
		
		if unsigned(A) > unsigned(B) then
			FLAGS(3) <= '1';
			FLAGS(2) <= '0';
			FLAGS(1) <= '0';
		elsif unsigned(A) < unsigned(B) then
			FLAGS(3) <= '0';
			FLAGS(2) <= '0';
			FLAGS(1) <= '1';
		else -- EQUAL
			FLAGS(3) <= '0';
			FLAGS(2) <= '1';
			FLAGS(1) <= '0';
		end if;
    when "1010" => -- shift and lose right
		temp_sum := unsigned('0' & A(0) & A(7 downto 1));
        sum(7 downto 0) := '0' & A(7 downto 1);
        S <= sum(7 downto 0);
		  
        
		  
        if sum(8) = '1' then
            FLAGS(0) <= '1';
        else 
			FLAGS(0) <= '0';
		end if;
		
		if sum(7 downto 0) = "00000000" then
		FLAGS(4) <= '1';
		else
			FLAGS(4) <= '0';
		end if;
		
		if unsigned(A) > unsigned(B) then
			FLAGS(3) <= '1';
			FLAGS(2) <= '0';
			FLAGS(1) <= '0';
		elsif unsigned(A) < unsigned(B) then
			FLAGS(3) <= '0';
			FLAGS(2) <= '0';
			FLAGS(1) <= '1';
		else -- EQUAL
			FLAGS(3) <= '0';
			FLAGS(2) <= '1';
			FLAGS(1) <= '0';
		end if;
    when "1011" => -- decrement by 1
        -- falta verificar se isso no crasha quando o resultado daria negativo
		temp_sum := ('1' & unsigned(A)) - unsigned'("000000001");
        sum := std_logic_vector(temp_sum);
            
        S <= sum(7 downto 0);
        if sum(8) = '0' then
            C_out <= '1';
            FLAGS(0) <= '1';
        else
			FLAGS(0) <= '0';
			C_out <= '0';
		end if;
			
		if sum(7 downto 0) = "00000000" then
		FLAGS(4) <= '1';
		else
			FLAGS(4) <= '0';
		end if;
		
		if unsigned(A) > unsigned(B) then
			FLAGS(3) <= '1';
			FLAGS(2) <= '0';
			FLAGS(1) <= '0';
		elsif unsigned(A) < unsigned(B) then
			FLAGS(3) <= '0';
			FLAGS(2) <= '0';
			FLAGS(1) <= '1';
		else -- EQUAL
			FLAGS(3) <= '0';
			FLAGS(2) <= '1';
			FLAGS(1) <= '0';
		end if;
    
    when others => -- nothing
    end case;
    
    end process cmd_dec;


end Behavioral;

