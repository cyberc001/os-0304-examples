testpc segment
	assume cs:testpc, ds:testpc, es:nothing, ss:nothing
	org 100h
start: jmp begin

; Prints supplied byte in hexadecimal form via BIOS interrupts.
; Arguments	| cl: byte to print
; Trashed	| cx
; Saved on stack| ax bx dx
; Return value	| none
print_hex_byte proc near
	push ax
	push bx
	push dx

	; print higher 4 bits
	mov  bl, cl	; shift out 4 lower bits

	push cx
	mov  al, bl
	mov  cl, 4
	shr  al, cl
	mov  bl, al
	pop  cx

	cmp  bl, 10
	jae  .addhex_1
	add  bl, '0'
	jmp .out_1
	.addhex_1:
	sub  bl, 10
	add  bl, 'A'
	.out_1:
	xor  ax, ax
	mov  ah, 2h
	mov  dl, bl
	int  21h

	; print lower 4 bits
	mov  bl, cl	; mask out 4 higher bits
	and  bl, 0fh
	cmp  bl, 10
	jae  .addhex_2
	add  bl, '0'
	jmp .out_2
	.addhex_2:
	sub  bl, 10
	add  bl, 'A'
	.out_2:
	mov  ah, 2h
	mov  dl, bl
	int  21h

	pop dx
	pop bx
	pop ax
	ret
print_hex_byte endp


; Prints supplied word in hexadecimal form via BIOS interrupts.
; Arguments	| cx: word to print
; Trashed	| cx
; Saved on stack| none
; Return value	| none
print_hex_word proc near

	push cx
	mov  cl, ch
	call print_hex_byte
	pop  cx
	call print_hex_byte

	ret
print_hex_word endp


; Prints supplied word in decimal form via BIOS interrupts
; Arguments     | cx: word to print
; Trashed       | cx
; Saved on stack| ax bx dx di
; Return value  | none
print_dec_word proc near
	push ax
	push bx
	push dx
	push di

        ; reset output string
	xor  di, di	; di - index in output string
	.reset_loop:
		mov  [print_dec_word_outstr + di], '0'
	inc  di
	cmp  di, 5
	jne .reset_loop


	mov  di, 5      ; di - index in output string

	.div_loop:
		xor  dx, dx
		mov  ax, cx
		mov  bx, 10
		div  bx         ; dx = cx % 10, ax = cx / 10
		mov  cx, ax     ; cx <-- cx / 10 (ax)
		add  dl, '0'    ; output the digit in dx
		mov  [print_dec_word_outstr + di], dl   ; output character in string
	dec  di
	cmp  cx, 0
	jne .div_loop

	lea  dx, print_dec_word_outstr + 1
	add  dx, di
	mov  ah, 9h
	int 21h

	pop  di
	pop  dx
	pop  bx
	pop  ax

	ret
print_dec_word endp


; Prints supplied dword in decimal form via BIOS interrupts.
; Breaks if cd:dx / 1000 is bigger than a word.
; Arguments     | cx:dx: dword to print
; Trashed       | cx dx
; Saved on stack| di
; Return value  | none
print_dec_dword proc near
	push di

	mov  ax, dx
	mov  dx, cx
	mov  di, 10000		; 000'000
	div  di			;  ax:dx
	cmp  ax, 0h
	je   .print_2nd_part
	mov  cx, ax
	call print_dec_word
	.print_2nd_part:
	mov  cx, dx
	call print_dec_word

	pop  di
	ret
print_dec_dword endp


; Prints null-terminated string.
; Arguments     | di: string address
; Trashed       | di
; Saved on stack| ax bx cx dx
; Return value  | none
print_str_nullterm proc near
        push ax
	push bx
        push cx
        push dx

	xor  bx, bx
	.seek_loop:
		mov  cl, [di + bx]
		cmp  cl, 0
		je  .seek_loop_end
		inc  bx
		jmp .seek_loop
	.seek_loop_end:

        mov  cl, [di + bx]              ; save byte being replaced by '$'
        mov  byte ptr [di + bx], 24h	; '$'

        mov  dx, di
        mov  ah, 9h
        int  21h

        mov  [di + bx], cl              ; restore the byte

        pop  dx
        pop  cx
	pop  bx
        pop  ax
        ret
print_str_nullterm endp


print_available_memory proc near
	push ax
	push bx
	push cx
	push dx
	push di

	mov  ah, 4Ah
	mov  bx, 0ffffh
	int  21h

	mov  ah, 9h
	lea  dx, avmemstr
	int  21h

	mov  ax, bx		; dx:ax = paragraph count * 16 bytes
	mov  di, 16
	mul  di
	mov  cx, dx
	mov  dx, ax

	call print_dec_dword

	mov  ah, 9h
	lea  dx, avmemstr2
	int  21h

	pop  di
	pop  dx
	pop  cx
	pop  bx
	pop  ax
	ret
print_available_memory endp


print_extended_memory proc near
	push ax
	push cx
	push dx

	mov  al, 30h	; CMOS port
	out  70h, al
	in   al, 71h	; read lower byte
	mov  cl, al	; extended memory size goes to cx
	mov  al, 31h	; CMOS port
	out  70h, al
	in   al, 71h	; read higher byte
	mov  ch, al

	mov  ah, 9h
	lea  dx, extmemstr
	int  21h
	call print_dec_word
	lea  dx, extmemstr2
	int  21h

	pop  dx
	pop  cx
	pop  ax
	ret
print_extended_memory endp


print_mcbs proc near
	push ax
	push bx
	push cx
	push dx
	push di
	push es

	mov  ah, 52h
	int  21h
	mov  di, es:[bx-2]	; get address of the first MCB
	mov  es, di

	.mcb_loop:
		mov  ah, 9h

		lea  dx, mcbpspstr
		int  21h
		mov  cx, es:[1h]
		call print_hex_word
		lea  dx, strend
		int  21h

		lea  dx, mcbsizestr
		int  21
		mov  ax, es:[3h]	; dx:ax = memory block size in paragraphs * 16 bytes
		mov  di, 16
		mul  di
		mov  cx, dx
		mov  dx, ax
		call print_dec_dword
		mov  ah, 9h
		lea  dx, mcbsizestr2
		int  21h

		lea  dx, mcbnamestr
		int  21h
		mov  cx, ds		; save data segment
		mov  bx, es
		mov  ds, bx		; ds <-- es
		mov  di, 8h
		mov  bx, 8h
		call print_str_nullterm
		mov  ds, cx		; restore data segment
		lea  dx, strend
		int  21h

		; check if the MCB is the last one
		mov  cl, 4Dh
		cmp  es:[0h], cl
		jne .mcb_loop_end
		; if not, go to the next MCB
		mov  di, es:[3h]	; es = es + memory chunk size in paragraphs + 1
		mov  ax, es		; (es is in paragraphs, so 1 is size of a MCB)
		add  di, ax
		inc  di
		mov  es, di
	jmp  .mcb_loop
	.mcb_loop_end:

	pop  es
	pop  di
	pop  dx
	pop  cx
	pop  bx
	pop  ax
	ret
print_mcbs endp


begin:
	call print_available_memory
	call print_extended_memory

	lea  ax, program_end
	mov  bx, 10h
	xor  dx, dx
	div  bx
	inc  ax
	mov  bx, ax
	mov  al, 0h
	mov  ah, 4Ah
	int  21h

	xor  ax, ax
	mov  ah, 48h
	mov  bx, 1000h
	int  21h

	lea  dx, strend
	mov  ah, 9h
	int  21h
	lea  dx, mcbstr
	int  21h
	call print_mcbs

	int  20h


	print_dec_word_outstr db '000000', '$'

	strend   	db 0Dh, 0Ah, '$'
	avmemstr	db 'Amount of available memory: ', '$'
	avmemstr2	db ' B', 0Dh, 0Ah, '$'
	extmemstr	db 'Amount of extended memory: ', '$'
	extmemstr2	db ' kB', 0Dh, 0Ah, '$'

	mcbstr		db 'MCB list:', 0Dh, 0Ah, '$'
	mcbtypestr	db 'MCB type: 0x', '$'
	mcbpspstr	db 'owner PSP segment address: 0x', '$'
	mcbsizestr	db 'memory chunk size: ', '$'
	mcbsizestr2	db ' B', 0Dh, 0Ah, '$'
	mcbnamestr	db 'Program name: ', '$'

program_end:
testpc ends
end start
