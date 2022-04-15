_stack segment stack
	dw 64 dup(?)
_stack ends

data segment
	overlay_path		db 64 dup (0)
	overlay_fname1		db 'OVER1.COM', 0h
	overlay_fname2		db 'OVER2.COM', 0h

	launch_params		dw 0, 0
	launch_addr		dd 0

        newline_str     	db 0Dh, 0Ah, '$'
        load_str      		db 'Loading overlay $'

	strerr_dosunknown	db ': unknown error', 0Dh, 0Ah, '$'
	strerr_dos2		db 'Error: file not found', 0Dh, 0Ah, '$'
	strerr_dos3		db 'Error: path not found', 0Dh, 0Ah, '$'
        ;strerr_dos7     	db 'Error: memory control blocks destroyed', 0Dh, 0Ah, '$'
        strerr_dos7     	db m'$'
        strerr_dos8     	db 'Error: insufficient memory', 0Dh, 0Ah, '$'
        strerr_dos9     	db 'Error: invalid memory block address', 0Dh, 0Ah, '$'
	strerr_dos12		db 'Error: no more files (file not found)', 0Dh, 0Ah, '$'

	strerr_mem		db 'Error: could not allocate memory$'

	set_overlay_name_last	dw 0

	overlay_file_data	db 64 dup (0)
data ends

code segment
	assume cs:code, ds:data, ss:_stack

; Prints supplied byte in hexadecimal form via BIOS interrupts.
; Arguments     | cl: byte to print
print_hex_byte proc near
        push ax
        push bx
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

        pop dx
        pop bx
        pop ax
        ret
print_hex_byte endp

; Prints a null-terminated string.
; Arguments     | di: string address
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

; Sets up a string which contains full path to overlay
; Arguments	| si: module file name
set_overlay_name proc near
        push ax
        push bx
        push cx
        push dx
        push es
	push di

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
        cmp  al, 0h     ; check for double zero
        jne  .str_nullterm_loop

        add  di, 3h
        mov  cx, di     ; save current overlay path

        ; write out current overlay path
        xor  bx, bx     ; loaded overlay path index
        .mpath_write_loop:
                mov  al, es:[di]
                cmp  al, 0h
                je  .mpath_write_end
                mov  overlay_path[bx], al
                inc  di
                inc  bx
                jmp  .mpath_write_loop
        .mpath_write_end:

        ; find the last '\'
        .mpath_slash_loop:
                mov  al, overlay_path[bx]
                cmp  al, '\'
                je   .mpath_slash_end
                dec  bx
                jmp  .mpath_slash_loop
        .mpath_slash_end:

        inc  bx
        ; now bx is the index past the slash; write out loaded overlay name
	mov  di, si
        .lpath_write_loop:
                mov  al, [di]
                cmp  al, 0h
                je  .lpath_write_end
                mov  overlay_path[bx], al
                inc  di
                inc  bx
                jmp  .lpath_write_loop
        .lpath_write_end:
	mov  al, 0h
	mov  overlay_path[bx], al

        lea  dx, load_str
        mov  ah, 09h
        int  21h

	cmp  set_overlay_name_last, si
	je   .ret2
	lea  di, overlay_path
	mov  cx, ds
	mov  es, cx
	call print_nullterm_string

        lea  dx, newline_str
        int  21h

	.ret2:
	mov  set_overlay_name_last, si
	pop  di
        pop  es
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
set_overlay_name endp

get_overlay_size proc near
	push ax
	push bx
	push cx
	push dx
	push si

	; set disk transfer address
	mov  ah, 1Ah
	lea  dx, overlay_file_data
	int  21h

	; find first file matching overlay path
	mov  ah, 4Eh
	lea  dx, overlay_path
	mov  cx, 0h		; no attributes
	int  21h
	jnc  .ofile_found

	; handle a file search error
	lea  dx, strerr_dos2
	cmp  ax, 2h
	je   .print_err2
	lea  dx, strerr_dos3
	cmp  ax, 3h
	je  .print_err2
	lea  dx, strerr_dos12
	cmp  ax, 12h
	je  .print_err2
	lea  dx, strerr_dosunknown
	mov  cl, al
	call print_hex_byte

	.print_err2:
	mov  ah, 9h
	int  21h
	jmp  .ret

	; handle memory allocation
	.ofile_found:
	mov  si, offset overlay_file_data
	add  si, 1Ah		; get file size
	mov  bx, [si]
	mov  cl, 4
	shr  bx, cl		; translate size in bytes to size in paragraphs
	mov  ax, [si + 2]	; get second word of file size
	mov  cl, 12
	shl  ax, cl		; and translate it to paragraphs
	add  bx, ax
	add  bx, 2
	; allocate memory for the overlay file being loaded
	mov  ah, 48h
	int  21h
	jnc  .set_launch_params

	; handle memory allocation errors
	lea  dx, strerr_mem
	mov  ah, 9h
	int  21h
	jmp  .ret

	.set_launch_params:
	mov  launch_params, ax
	mov  launch_params + 2, ax

	.ret:
	pop  si
	pop  dx
	pop  cx
	pop  bx
	pop  ax
	ret
get_overlay_size endp

load_overlay proc near
	push ax
	push dx
	push es

	; memory is allocated, loading overlay into memory
	lea  dx, overlay_path
	mov  ax, ds
	mov  es, ax
	lea  bx, launch_params
	mov  ax, 4B03h
	int  21h
	jnc  .overlay_launch

	lea  dx, strerr_dos2
	cmp  ax, 2h
	je   .print_err3
	lea  dx, strerr_dos3
	cmp  ax, 3h
	je   .print_err3
	lea  dx, strerr_dos8
	cmp  ax, 8h
	je   .print_err3
	lea  dx, strerr_dosunknown
	mov  cl, al
	call print_hex_byte

	.print_err3:
	mov  ah, 9h
	int  21h
	jmp  .overlay_cleanup

	.overlay_launch:
	mov  ax, launch_params
	mov  word ptr launch_addr + 2, ax
	call launch_addr
	mov  es, ax
	mov  ah, 49h
	int  21h

	.overlay_cleanup:
	pop  es
	pop  dx
	pop  ax
	ret
load_overlay endp


main proc far
	xor  ax, ax
	push ax
	mov  ax, data
	mov  ds, ax

	call free_mem

	lea  si, overlay_fname1
	call set_overlay_name
	call get_overlay_size
	call set_overlay_name
	call load_overlay

	lea  si, overlay_fname2
	call set_overlay_name
	call get_overlay_size
	call load_overlay

	xor  al, al
	mov  ah, 4Ch
	int  21h
main endp

exec_end:
code ends
end main
