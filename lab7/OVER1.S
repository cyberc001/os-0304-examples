over1 segment
	assume cs:over1, ds:nothing, ss:nothing, es:nothing

main proc far
	push ax
	push cx
	push dx
	push ds
	push es

	mov  ax, cs
	mov  ds, ax

	lea  dx, load_msg
	mov  ah, 9h
	int  21h

	lea  dx, seg_msg
	int  21h
	mov  cx, cs
	call print_hex_word
	lea  dx, newline_str
	int  21h

	.ret:
	pop  es
	pop  ds
	pop  dx
	pop  cx
	pop  ax
	retf
main endp


; Prints supplied byte in hexadecimal form via BIOS interrupts.
; Arguments     | cl: byte to print
print_hex_byte proc near
        push ax
        push bx
	push cx
        push dx

        ;print higher 4 bits
        mov  bl, cl     ; shift out 4 lower bits

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
        mov  bl, cl     ; mask out 4 higher bits

        push cx
        mov  al, bl
        mov  cl, 4
        shl  al, cl
        shr  al, cl
        mov  bl, al
        pop  cx

        cmp  bl, 10
        jae  .addhex_2
        add  bl, '0'
        jmp .out_2
        .addhex_2:
        sub  bl, 10
        add  bl, 'A'
        .out_2:
        xor  ax, ax
        mov  ah, 2h
        mov  dl, bl
        int  21h

        pop  dx
	pop  cx
        pop  bx
        pop  ax
        ret
print_hex_byte endp

; Prints supplied word in hexadecimal form via BIOS interrupts.
; Arguments     | cx: byte to print
print_hex_word proc near
	push bx

	push cx
	mov  bx, cx
	mov  cl, 8h
	shr  bx, cl
	mov  cx, bx
	call print_hex_byte
	pop  cx
	call print_hex_byte

	pop  bx
	ret
print_hex_word endp


; data
	newline_str	db 0Dh, 0Ah, '$'
	load_msg	db 'Overlay #1 is loaded', 0Dh, 0Ah, '$'
	seg_msg		db 'Overlay #1 segment: 0x$'

over1 ends
end main
