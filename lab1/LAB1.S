org 100h
jmp start

%define endstr	0xD, 0xA, '$'

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

; Prints supplied byte in decimal form via BIOS interrupts, ignoring the leftmost digit
; Arguments	| cl: byte to print
; Trashed	| cx
; Saved on stack| ax bx dx di
; Return value	| none
print_dec_byte.outstr db '000', '$'
print_dec_byte:
	push ax
	push bx
	push dx
	push di

	; reset output string
	mov  byte [print_dec_byte.outstr], '0'
	mov  byte [print_dec_byte.outstr + 1], '0'
	mov  byte [print_dec_byte.outstr + 2], '0'

	mov  di, 2	; di - index in output string

	.div_loop:
		xor  dx, dx
		mov  ax, cx
		mov  bx, 10
		div  bx		; dx = cx % 10, ax = cx / 10
		mov  cx, ax	; cx <-- cx / 10 (ax)
		add  dl, '0'	; output the digit in dx
		mov  [print_dec_byte.outstr + di], dl	; output character in string
		dec  di
	cmp cx, 0
	jne .div_loop

	mov  dx, print_dec_byte.outstr + 1	; output format string, ignoring the leftmost digit
	mov  ah, 0x9
	int 0x21

	pop di
	pop dx
	pop bx
	pop ax

	ret


; Prints supplied PC type to screen via BIOS interrupts.
; Arguments 	| cx: PC type
; Trashed 	| cx
; Saved on stack| ax dx
; Return value 	| none
print_pc_type:
	push ax
	push dx

	;jmp  .print_hex
	cmp  cx, 0xF8	; check whether cx is out of range (cx >= 0x8F)
	jb   .print_hex

	.print_string:
	mov  ah, 0x9
	mov  dx, pctypestr
	int  0x21
	sub  cx, 0xF8	; cx -= 0xF8 (get offset into PC string table)
	mov  bx, cx	; bx <-- cx (cx is not addressable)
	shl  bx, 1	; bx *= 2 (to get offset in words)

	mov  dx, [pcstrtable + bx]	; get string address
	mov  ah, 0x9			; call to display resulting string
	int 0x21
	jmp .finish

	.print_hex:
	mov  dx, pchexstr
	mov  ah, 0x9
	int 0x21
	call print_hex_byte
	mov  dx, strend
	int 0x21

	.finish:
	pop dx
	pop ax
	ret

; Gets and prints MSDOS info via BIOS interrupts.
; Arguments	| none
; Trashed	| none
; Saved on stack| ax bx cx dx
; Return value	| none
print_msdos_info:
	push  ax
	push  bx
	push  cx
	push  dx

	; get info from an interrupt
	mov  ah, 0x30
	int  0x21
	; save some of it
	push cx
	push bx

	;print version number
	mov  ah, 0x9
	mov  dx, dosverstr
	int  0x21

	xor  cx, cx
	mov  cl, al	; cl <-- major version number
	call print_dec_byte
	mov  cl, ah	; cl <-- modification number
	mov  ah, 0x2	; print '.' separator
	mov  dl, '.'
	int  0x21
	call print_dec_byte
	mov  ah, 0x9	; print new line
	mov  dx, strend
	int  0x21

	; print OEM serial number
	mov  ah, 0x9
	mov  dx, oemserstr
	int  0x21
	pop  bx
	mov  cl, bh	; cl <-- OEM serial number
	call print_hex_byte
	mov  ah, 0x9
	mov  dx, strend
	int  0x21

	; print user serial number
	mov  ah, 0x9
	mov  dx, userserstr
	int  0x21
	pop  dx		; pop into dx instead of cx, to preserve cx register for print_hex_byte argument
	mov  cl, bl
	call print_hex_byte
	mov  cl, dh
	call print_hex_byte
	mov  cl, dl
	call print_hex_byte
	mov  ah, 0x9
	mov  dx, strend
	int  0x21

	pop  dx
	pop  cx
	pop  bx
	pop  ax
	ret


start:
	; print PC type
	mov  bx, ds		; save data segment
	mov  cx, 0xF000
	mov  ds, cx		; set data segment to 0xF000 (BIOS ROM)
	xor  cx, cx
	mov  cl, [0xFFFE]	; cl <-- PC type
	mov  ds, bx		; restore data segment

	call print_pc_type

	; print system version
	call print_msdos_info

	int  0x20

section .data

	; strings
	strend   	db endstr
	pchexstr 	db 'Unkown PC type: 0x', '$'
	pctypestr	db 'PC type: ', '$'
	dosverstr	db 'DOS version: ', '$'
	oemserstr	db 'OEM serial number: ', '$'
	userserstr	db 'User serial number: ', '$'

	; PC type strings
	pcstr0	db 'PS2 model 80', endstr	; 0xF8
	pcstr1	db 'PC Convertible', endstr	; 0xF9
	pcstr2	db 'PS2 model 30', endstr	; 0xFA
	pcstr3	db 'PC/XT', endstr		; 0xFB
	pcstr4	db 'PS2 module 50 or 60', endstr; 0xFC
	pcstr5  db 'PCjr', endstr		; 0xFD
	pcstr6	db 'PC/XT', endstr		; 0xFE
	pcstr7	db 'PC', endstr			; 0xFF

	; PC type string table
	pcstrtable:
	%assign i 0
	%rep 8
		dw pcstr%+i
	%assign i i+1
	%endrep
