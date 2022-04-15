_stack segment stack
	dw 64 dup(?)
_stack ends


data segment
	param_block	dw 0	; environment segment
			dd 0	; cmd segment:offset
			dd 0	; FCB segment:offset
			dd 0

	backup_ss 	dw 0
	backup_sp 	dw 0

	module_path 	db 64 dup (0)
	module_fname 	db 'LAB2.COM', 0h

	newline_str	db 0Dh, 0Ah, '$'

	launch_str	db 'Launching module $'

	strerr_dosmodl	db 'Error: cant find module file$'

	strerr_dos7	db 'Error: memory control blocks destroyed$'
	strerr_dos8	db 'Error: insufficient memory$'
	strerr_dos9	db 'Error: invalid memory block address$'

	strret_dos0	db 'Normal termination, code: 0x$'
	strret_dos1	db 'Ctrl-Break termination$'
	strret_dos2	db 'Critical device error$'
	strret_dos3	db 'Termination by int 21, 31$'
data ends


code segment
	assume cs:code, ds:data, ss:_stack

; Prints supplied byte in hexadecimal form via BIOS interrupts.
; Arguments	| cl: byte to print
print_hex_byte proc near
	push ax
	push bx
	push dx

	;print higher 4 bits
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

	pop dx
	pop bx
	pop ax
	ret
print_hex_byte endp

; Prints a null-terminated string.
; Arguments	| di: string address
print_nullterm_string proc near
	push ax
	push dx

	mov  ah, 2h
	.nullterm_loop:
		mov  dl, es:[di]
		cmp  dl, 0h
		je  .nullterm_end

		int  21h
		inc  di
		jmp  .nullterm_loop
	.nullterm_end:

	pop  dx
	pop  ax
	ret
print_nullterm_string endp

set_params proc near
	mov  ax, es:[2Ch]		; getting environment segment
	mov  param_block, ax
	mov  param_block + 2, es	; setting cmd segment
	mov  param_block + 4, 80h	; and offset
set_params endp

free_mem proc near
	push ax
	push bx
	push cx

	lea  bx, exec_end
	mov  ax, es
	sub  bx, ax
	mov  cl, 4
	shr  bx, cl
	inc  bx

	mov  ah, 4Ah
	int  21h
	jnc  .free_mem_cleanup

	lea  dx, strerr_dos7
	cmp  ax, 7h
	je  .print_err
	lea  dx, strerr_dos8
	cmp  ax, 8h
	je  .print_err
	lea  dx, strerr_dos9
	cmp  ax, 9h
	je  .print_err

	jmp .free_mem_cleanup
	.print_err:
	mov  ah, 09h
	int  21h

	.free_mem_cleanup:
	pop  cx
	pop  bx
	pop  ax
	ret
free_mem endp

set_module_name proc near
	push ax
	push bx
	push cx
	push dx
	push es

	mov  es, es:[2Ch]
	xor  di, di
	.str_nullterm_loop:
		mov  al, es:[di]
		cmp  al, 0h
		je   .str_nullterm_end
		inc  di
		jmp  .str_nullterm_loop
	.str_nullterm_end:
	inc  di
	mov  al, es:[di]
	cmp  al, 0h	; check for double zero
	jne  .str_nullterm_loop

	add  di, 3h
	mov  cx, di	; save current module path

	; write out current module path
	xor  bx, bx	; loaded module path index
	.mpath_write_loop:
		mov  al, es:[di]
		cmp  al, 0h
		je  .mpath_write_end
		mov  module_path[bx], al
		inc  di
		inc  bx
		jmp  .mpath_write_loop
	.mpath_write_end:

	; find the last '\'
	.mpath_slash_loop:
		mov  al, module_path[bx]
		cmp  al, '\'
		je   .mpath_slash_end
		dec  bx
		jmp  .mpath_slash_loop
	.mpath_slash_end:

	inc  bx
	; now bx is the index past the slash; write out loaded module name
	xor  di, di
	.lpath_write_loop:
		mov  al, module_fname[di]
		cmp  al, 0h
		je  .lpath_write_end
		mov  module_path[bx], al
		inc  di
		inc  bx
		jmp  .lpath_write_loop
	.lpath_write_end:

	lea  dx, launch_str
	mov  ah, 09h
	int  21h

	lea  di, module_path
	mov  cx, ds
	mov  es, cx
	call print_nullterm_string

	lea  dx, newline_str
	int  21h

	pop  es
	pop  dx
	pop  cx
	pop  bx
	pop  ax
	ret
set_module_name endp

launch_module proc near
	push ax
	push bx
	push dx

	lea  dx, newline_str
	mov  ah, 09h
	int  21h

	; save stack
	push ds
	push es
	mov  backup_sp, sp
	mov  backup_ss, ss
	mov  ax, ds
	mov  es, ax

	; launch the module
	lea  dx, module_path
	lea  bx, param_block
	mov  ax, 4B00h
	int 21h

	; restore stack
	mov  ss, backup_ss
	mov  sp, backup_sp
	pop  es
	pop  ds

	; handle loading errors
	jc  .launch_module_cleanup

	; handle return code
	.ret_handle:
	lea  dx, newline_str
	mov  ah, 09h
	int  21h

	mov  ax, 4D00h 		; get return code
	int  21h

	mov  cx, ax
	lea  dx, strret_dos0
	cmp  ch, 0h
	je   .print_ret
	lea  dx, strret_dos1
	cmp  ch, 1h
	je   .print_ret
	lea  dx, strret_dos2
	cmp  ch, 2h
	je   .print_ret
	jmp  .launch_module_cleanup

	.print_ret:
	mov  ah, 09h
	int  21h

	cmp  ch, 0h
	jne  .launch_module_cleanup
	call print_hex_byte

	clc
	.launch_module_cleanup:
	jnc  .ret
	lea  dx, strerr_dosmodl
	mov  ah, 09h
	int  21h

	.ret:
	lea  dx, newline_str
	mov  ah, 09h
	int  21h

	pop  dx
	pop  bx
	pop  ax
	ret
launch_module endp


main proc far
	xor  ax, ax
	push ax
	mov  ax, data
	mov  ds, ax

	call free_mem
	call set_params
	call set_module_name
	call launch_module

	xor  al, al
	mov  ah, 4Ch
	int 21h
main endp

exec_end:
code ends
end main
