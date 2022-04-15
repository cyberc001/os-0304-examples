org 100h
jmp start

section .text

; Prints supplied byte in hexadecimal form via BIOS interrupts.
; Arguments	| cl: byte to print
; Trashed	| cx
; Saved on stack| ax dx
; Return value	| none
print_hex_byte:
	push ax
	push dx

	; print higher 4 bits
	mov  dl, cl	; shift out 4 lower bits
	shr  dl, 4
	cmp  dl, 10
	jae  .addhex_1
	add  dl, '0'
	jmp .out_1
	.addhex_1:
	sub  dl, 10
	add  dl, 'A'
	.out_1:
	mov  ah, 0x2
	int  0x21

	; print lower 4 bits
	mov  dl, cl	; mask out 4 higher bits
	and  dl, 0x0F
	cmp  dl, 10
	jae  .addhex_2
	add  dl, '0'
	jmp .out_2
	.addhex_2:
	sub  dl, 10
	add  dl, 'A'
	.out_2:
	mov  ah, 0x2
	int  0x21

	pop dx
	pop ax
	ret


; Prints supplied word in hexadecimal form via BIOS interrupts.
; Arguments	| cx: word to print
; Trashed	| cx
; Saved on stack| none
; Return value	| none
print_hex_word:
	push cx
	shr  cx, 8
	call print_hex_byte
	pop  cx
	call print_hex_byte
	ret


; Prints string with limited amount of characters.
; Arguments	| bx: character count, di: string address
; Trashed	| bx di
; Saved on stack| ax cx dx
; Return value	| none
print_str_limited:
	push ax
	push cx
	push dx

	mov  cl, [di + bx]		; save byte being replaced by '$'
	mov  byte [di + bx], '$'

	mov  dx, di
	mov  ah, 0x9
	int  0x21

	mov  [di + bx], cl		; restore the byte

	pop  dx
	pop  cx
	pop  ax
	ret

; Prints a null-terminated string.
; Arguments	| di: string address
; Trashed	| di
; Saved on stack| ax bx dx
; Return value	| none
print_nullterm_string:
	push ax
	push bx
	push dx

	xor  ax, ax
	xor  bx, bx
	.null_term_loop:
		cmp  byte[di + bx], 0x0
		je   .null_term_loop_end
		inc  bx
		jmp  .null_term_loop
	.null_term_loop_end:
	mov  byte [di + bx], '$'
	mov  ah, 0x9
	mov  dx, di
	int  0x21
	mov  byte [di + bx], 0x0

	pop  dx
	pop  bx
	pop  ax
	ret


; Prints PSP environment content.
; Arguments	| none (ds should point to PSP module)
; Trashed	| none
; Saved on stack| ax bx cx dx
; Return value	| di (program path, without segment offset)
print_env:
	push ax
	push bx
	push cx
	push dx

	mov  ah, 0x9		; call to print a string
	mov  cx, ds		; save ds to cx (for printing a newline after each environment variable)
	mov  ds, [0x2C]
	xor  di, di		; di points to the current string

	.string_loop:
	xor  bx, bx		; bx is string index
	.null_term_loop:	; seaching for null terminator in a loop
		cmp  byte [di + bx], 0x0
		je   .null_term_loop_end
		inc  bx
		jmp  .null_term_loop
	.null_term_loop_end:
	mov  byte [di + bx], '$'
	mov  dx, di
	int  0x21
	mov  byte [di + bx], 0x0

	cmp  bx, 0x0	; bx == 0 - double zero, end of the environment strings
	je   .ret
	inc  bx
	add  di, bx

	mov  ds, cx
	mov  dx, strend
	int  0x21
	mov  ds, [0x2C]
	jmp .string_loop

	.ret:
	add  di, 3
	mov  ds, cx
	pop  dx
	pop  cx
	pop  bx
	pop  ax
	ret


; Prints information about PSP module.
; Arguments	| none (ds should point to PSP module)
; Trashed	| none
; Saved on stack| ax cx dx di
; Return value	| none
print_psp:
	push ax
	push cx
	push dx
	push di

	mov  ah, 0x9
	mov  dx, memlimitstr
	int  0x21
	mov  cx, [0x2]
	call print_hex_word
	mov  dx, strend
	int  0x21

	mov  dx, envaddrstr
	int  0x21
	mov  cx, [0x2C]
	call print_hex_word
	mov  dx, strend
	int  0x21

	mov  dx, cmdargstr
	int  0x21
	mov  di, 0x81
	mov  bl, [0x80]
	call print_str_limited
	mov  dx, strend
	int  0x21

	mov  dx, envcontstr
	int  0x21
	call print_env

	mov  dx, progpathstr
	int  0x21
	mov  cx, ds
	mov  ds, [0x2C]
	call print_nullterm_string
	mov  ds, cx
	mov  dx, strend
	int  0x21

	pop di
	pop dx
	pop cx
	pop ax
	ret


start:
	call print_psp

	mov  ah, 0x1
	int  0x21
	mov  ah, 0x4C
	int  0x21

section .data

	; strings
	%define endstr	0xD, 0xA, '$'
	strend   	db endstr
	memlimitstr	db 'First byte of unadressable memory: 0x', '$'
	envaddrstr	db 'Environment segment address: 0x', '$'
	cmdargstr	db 'Command line arguments:', '$'
	envcontstr	db 'Environment content:', endstr
	progpathstr	db 'Path to module: ', '$'
