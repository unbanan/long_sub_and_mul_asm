QWORD_SIZE: 		equ				8 ;qword size in bytes
QWORD_NUMBER:		equ				128 ;maximum qword in number
PROD_QWORD_NUMBER:	equ				256
LONG_NUMBER:		equ				4
MEM_SIZE:		equ				QWORD_NUMBER * QWORD_SIZE * LONG_NUMBER
MEM_SIZE_QWORDS:	equ				QWORD_NUMBER * LONG_NUMBER
LONG_LENGTH:		equ				QWORD_NUMBER * QWORD_SIZE
PROD_LENGTH:		equ				PROD_QWORD_NUMBER * QWORD_SIZE
					section         .text

					global          _start
_start:
		sub             rsp, MEM_SIZE
		call 		make_zero
		lea             rdi, [rsp + LONG_LENGTH]
		mov             rcx, QWORD_NUMBER
		call            read_long
		mov             rdi, rsp
		call            read_long
		lea             rsi, [rsp + LONG_LENGTH]
		mov		rcx, 128
		call            mul_long_long
		mov		rcx, PROD_QWORD_NUMBER
		call            write_long
		mov             al, 0x0a
		call            write_char
		jmp             exit
		
		
make_zero:
		lea		rdi, [rsp + 2 * LONG_LENGTH]
		mov		rcx, PROD_QWORD_NUMBER
		call 		set_zero
		ret

; adds two long number
;    rdi -- address of summand #1 (long number)
;    rsi -- address of summand #2 (long number)
;    rcx -- length of long numbers in qwords
; result:
;    sum is written to rdi
add_long_long:
		push            rdi
		push            rsi
		push            rcx

		clc
.loop:
		mov             rax, [rsi]
		lea             rsi, [rsi + QWORD_SIZE]
		adc             [rdi], rax
		lea             rdi, [rdi + QWORD_SIZE]
		dec             rcx
		jnz             .loop

		pop             rcx
		pop             rsi
		pop             rdi
		ret

; multiplies two long number
;    rdi -- address of number #1 (long number)
;    rsi -- address of number #2 (long number)
;    rcx -- length of long numbers in qwords
; result:
;    result is written to rdi

mul_long_long:
		mov		r15, rcx ;save for function reuse
		lea		r14, [rsp + PROD_LENGTH + 8] ;+8 because call pushes the return address onto the stack (r14 is the beginning of the response)
		push		rcx 
		xor		r13, r13 ;block index in 1st number
		clc
.outer_loop:			
		mov		r9, r15 ;number length
		xor		r12, r12 ;block index in 2nd number
		mov		r10, r14 
		add		r10, r13
		clc
		;r10 is responsible for the current response index
.inner_loop:	
		mov		rax, [rdi + r13]
		add		[r10], r8
		mov		r8, 0
		adc		r8, 0
		mul		qword[rsi + r12] ;multiply + accounting for overflow
		add		[r10], rax
		adc		r8, rdx
		add		r12, QWORD_SIZE	
		add		r10, QWORD_SIZE
		dec		r9
		jnz             .inner_loop
		add		r13, QWORD_SIZE 
		mov		[r10], r8 
		xor		r8, r8
		dec		rcx
		jnz             .outer_loop 
		pop		rcx 
		mov		rdi, r14
		ret


; adds 64-bit number to long number
;    rdi -- address of summand #1 (long number)
;    rax -- summand #2 (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    sum is written to rdi
add_long_short:
		push            rdi
		push            rcx
		push            rdx

		xor             rdx,rdx
.loop:
		add             [rdi], rax
		adc             rdx, 0
		mov             rax, rdx
		xor             rdx, rdx
		add             rdi, 8
		dec             rcx
		jnz             .loop

		pop             rdx
		pop             rcx
		pop             rdi
		ret

; multiplies long number by a short
;    rdi -- address of multiplier #1 (long number)
;    rbx -- multiplier #2 (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    product is written to rdi
mul_long_short:
		push            rax
		push            rdi
		push            rcx

		xor             rsi, rsi
.loop:
		mov             rax, [rdi]
		mul             rbx
		add             rax, rsi
		adc             rdx, 0
		mov             [rdi], rax
		add             rdi, 8
		mov             rsi, rdx
		dec             rcx
		jnz             .loop

		pop             rcx
		pop             rdi
		pop             rax
		ret

; divides long number by a short
;    rdi -- address of dividend (long number)
;    rbx -- divisor (64-bit unsigned)
;    rcx -- length of long number in qwords
; result:
;    quotient is written to rdi
;    rdx -- remainder
div_long_short:
		push            rdi
		push            rax
		push            rcx

		lea             rdi, [rdi + 8 * rcx - 8]
		xor             rdx, rdx

.loop:
		mov             rax, [rdi]
		div             rbx
		mov             [rdi], rax
		sub             rdi, 8
		dec             rcx
		jnz             .loop

		pop             rcx
		pop             rax
		pop             rdi
		ret

; assigns a zero to long number
;    rdi -- argument (long number)
;    rcx -- length of long number in qwords
set_zero:
		push            rax
		push            rdi
		push            rcx
		xor             rax, rax
		rep 		stosq
		pop             rcx
		pop             rdi
		pop             rax
		ret

; checks if a long number is a zero
;    rdi -- argument (long number)
;    rcx -- length of long number in qwords
; result:
;    ZF=1 if zero
is_zero:
		push            rax
		push            rdi
		push            rcx
		xor             rax, rax
		rep		scasq
		pop             rcx
		pop             rdi
		pop             rax
		ret

; read long number from stdin
;    rdi -- location for output (long number)
;    rcx -- length of long number in qwords
read_long:
		push            rcx
		push            rdi
		call            set_zero
.loop:
		call            read_char
		or              rax, rax
		js              exit
		cmp             rax, 0x0a
		je              .done
		cmp             rax, '0'
		jb              .invalid_char
		cmp             rax, '9'
		ja              .invalid_char
		sub             rax, '0'
		mov             rbx, 10
		call            mul_long_short
		call            add_long_short
		jmp             .loop

.done:
		pop             rdi
		pop             rcx
		ret

.invalid_char:
		mov             rsi, invalid_char_msg
		mov             rdx, invalid_char_msg_size
		call            print_string
		call            write_char
		mov             al, 0x0a
		call            write_char

.skip_loop:
		call            read_char
		or              rax, rax
		js              exit
		cmp             rax, 0x0a
		je              exit
		jmp             .skip_loop

; write long number to stdout
;    rdi -- argument (long number)
;    rcx -- length of long number in qwords
write_long:
		push            rax
		push            rcx
		mov             rax, 20
		mul             rcx
		mov             rbp, rsp
		sub             rsp, rax
		mov             rsi, rbp
.loop:
		mov             rbx, 10
		call            div_long_short
		add             rdx, '0'
		dec             rsi
		mov             [rsi], dl
		call            is_zero
		jnz             .loop
		mov             rdx, rbp
		sub             rdx, rsi
		call            print_string
		mov             rsp, rbp
		pop             rcx
		pop             rax
		ret

; read one char from stdin
; result:
;    rax == -1 if error occurs
;    rax \in [0; 255] if OK
read_char:
		push            rcx
		push            rdi
		sub             rsp, 1
		xor             rax, rax
		xor             rdi, rdi
		mov             rsi, rsp
		mov             rdx, 1
		syscall
		cmp             rax, 1
		jne             .error
		xor             rax, rax
		mov             al, [rsp]
		add             rsp, 1
		pop             rdi
		pop             rcx
		ret
.error:
		mov             rax, -1
		add             rsp, 1
		pop             rdi
		pop             rcx
		ret

; write one char to stdout, errors are ignored
;    al -- char
write_char:
		sub             rsp, 1
		mov             [rsp], al

		mov             rax, 1
		mov             rdi, 1
		mov             rsi, rsp
		mov             rdx, 1
		syscall
		add             rsp, 1
		ret

exit:
		mov             rax, 60
		xor             rdi, rdi
		syscall

; print string to stdout
;    rsi -- string
;    rdx -- size
print_string:
		push            rax

		mov             rax, 1
		mov             rdi, 1
		syscall
		pop             rax
		ret
		section         .rodata
invalid_char_msg:
		db              "Invalid character: "
invalid_char_msg_size: equ             $ - invalid_char_msg