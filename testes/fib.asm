.equ LOOP_COUNT, 0x03
.equ FIB_STOP, 0x60
.equ IO, 0xFF
.equ SHIFT_INIT_VALUE, 0xFE
.equ DEC_INIT_VALUE, 0x0A

.org 0x00

start:

ld Ra, 0
push Ra
push Ra
push Ra

loop:
	pop Ra
	pop Ra
	pop Ra
	
	inc Ra
	
	push Ra
	push Ra
	push Ra

	ld Rd, @LOOP_COUNT
	and Rd, Ra
	ld Rd, @end_loop
	beq Rd

	loop_fib:
		ld Rd, @FIB_STOP
		and Rd, Ra
		ld Rd, @loop
		blt Rd

		pop Rb
		pop Ra
		push Ra
		pop Rc
		
		add Ra, Rb
		ld Rd, @IO
		str Ra, [Rd]

		push Ra
		push Rc

		jmp @loop_fib

	
end_loop:

	pop Ra
	pop Ra
	pop Ra

	ld Ra, @SHIFT_INIT_VALUE
	
shift_loop:
	
	ld Rd, @IO
	str Ra, [Rd]
	lsr Ra
	
	ld Rd, 0
	and Rd, Ra
	ld Rd, @shift_loop
	bneq Rd

	ld Ra, 10
	push Ra
	push Ra
	
	add Rd, Ra
	
fib_loop2:
	
	ld Rd, @end_fib_loop2
	bcs Rd
	
	pop Rb
	pop Ra
	push Ra
	pop Rc
	
	add Ra, Rb
	ld Rd, @IO
	str Ra, [Rd]

	push Ra
	push Rc
	
	jmp @fib_loop2
	
end_fib_loop2:

	pop Rd
	pop Rd

	ld Ra, @DEC_INIT_VALUE
	lsl Ra
	ld Rd, @IO
	ld Rc, @end_dec_loop
	
dec_loop:
		
	bz Rc
	
	str Ra, [Rd]
	dec Ra
	
	jmp @dec_loop
	
end_dec_loop:
	
	halt
	