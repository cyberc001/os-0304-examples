code segment
	assume cs:code, ds:data, ss:astack

; Timer interrupt handler (0x09 interrupt vector)
int_hndl proc far
	jmp  .int_start

	backup_psp	dw ?
	backup_ip	dw 0
	backup_cs	dw 0
	int9_vec	dd ?
	int_magic	dw 0BEEFh

	backup_ss	dw ?
	backup_sp	dw ?
	backup_ax	dw ?
	int_stack	dw 32 dup (?)
	int_stack_end	dw ?
	teststr		db 'key "A" was pressed'
	required_key	db 1Eh

	; compare currently pressed key scan to required one

	.int_start:

	mov  backup_ss, ss
	mov  backup_sp, sp
	mov  backup_ax, ax
	mov  ax, cs
	mov  ss, ax
	mov  sp, offset int_stack_end
	push ax
	push bx
	push cx
	push dx

	in   al, 60h
	cmp  al, required_key
	je   .hint_hndl

	pop  dx
	pop  cx
	pop  bx
	pop  ax

	mov  ax, backup_ss
	mov  ss, ax
	mov  ax, backup_ax
	mov  sp, backup_sp
	jmp  dword ptr cs:[int9_vec]

	; required hardware interrupt handling
	.hint_hndl:
	in   al, 61h
	mov  ah, al
	or   al, 80h
	out  61h, al
	xchg ah, al
	out  61h, al
	mov  al, 20h
	out  20h, al

	; write out symbol in the keyboard buffer
	.write_kb_buf:
	mov  ah, 05h
	mov  cl, 'A'
	mov  ch, 0h
	int  16h
	or   al, al	; check for buffer overflow
	jz   .no_overflow

	; clear keyboard buffer and try again
	push ds
	mov  ax, 0040h
	mov  ds, ax
	mov  ax, [001Ah]
	mov  bx, 001Ch
	mov  [bx], ax
	pop  ds
	jmp .write_kb_buf

	.no_overflow:
	; display that the key is pressed
        push es
        push bp
        mov  ax, seg teststr
        mov  es, ax
        mov  ax, offset teststr
        mov  bp, ax
        mov  al, 0h     ; write mode
        mov  ah, 13h    ; string output function
        mov  bh, 0h     ; video page number
        mov  bl, 2h     ; color
        mov  cx, 19     ; character count
        mov  dh, 0h     ; row
        mov  dl, 0h     ; column
        int  10h
        pop  bp
        pop  es

	; exit
	.int_exit:
	pop  dx
	pop  cx
	pop  bx
	pop  ax

	mov  ax, backup_ss
	mov  ss, ax
	mov  ax, backup_ax
	mov  sp, backup_sp
	iret
resident_end:
int_hndl endp

; Loads an interrupt vector at 0x09, remembering the old one.
; Arguments     | none
; Trashed       | none
; Saved on stack| ax bx dx
; Return value  | none
load_int proc near
	push ax
	push bx
	push dx

	; remember CS:IP of the 0x09 vector
	mov  ah, 35h
	mov  al, 09h
	int  21h
	mov  backup_psp, ds
	mov  backup_cs, es
	mov  backup_ip, bx
	mov  word ptr int9_vec + 2, es
	mov  word ptr int9_vec, bx

	; load the new one
	push ds
	mov  dx, offset int_hndl
	mov  ax, seg int_hndl
	mov  ds, ax
	mov  ah, 25h		; interrupt vector set function
	mov  al, 09h
	int  21h
	pop  ds

	lea  dx, resident_end
	mov  cl, 4h
	shr  dx, cl
	inc  dx
	mov  ax, cs
	sub  ax, backup_psp
	add  dx, ax
	xor  ax, ax
	mov  ah, 31h
	int  21h

	pop  dx
	pop  bx
	pop  ax
	ret
load_int endp

; Unloads the interrupt vector at 0x09, restoring the old one
; Arguments     | none
; Trashed       | none
; Saved on stack| ax bx dx
; Return value  | none
unload_int proc near
	push ax
	push bx
	push cx

	push es
	mov  ax, backup_psp
	mov  es, ax
	mov  dx, word ptr es:int9_vec
	mov  ax, word ptr es:int9_vec + 2
	mov  backup_ip, dx
	mov  backup_cs, ax
	pop  es

	cli
	push ds

	mov  ah, 35h
	mov  al, 09h
	int  21h

	mov  si, offset backup_ip
	sub  si, offset int_hndl
	mov  dx, es:[bx + si]
	mov  ax, es:[bx + si + 2]
	mov  ds, ax
	mov  ah, 25h
	mov  al, 09h
	int  21h

	pop  ds

	; freeing memory
	mov  ax, es:[bx + si - 2]
	mov  es, ax
	push es

	mov  ax, es:[2Ch]
	mov  es, ax
	mov  ah, 49h
	int  21h

	pop  es
	mov  ah, 49h
	int  21h
	sti

	pop  cx
	pop  bx
	pop  ax
	ret
unload_int endp

; Gets interrupt vector at 0x09 and compares it to int_hndl signature.
; Arguments	| none
; Trashed	| none
; Saved on stack| bx es
; Return value	| ax : 0 if signature does not match, 1 if it does
test_int proc near
	push bx
	push es
	push si

	mov  ah, 35h
	mov  al, 09h
	int  21h

	mov  si, offset int_magic
	sub  si, offset int_hndl
	mov  dx, es:[bx + si]
	cmp  dx, 0BEEFh
	jne  .end_false
	mov  ax, 1
	jmp  .end2
	.end_false:
	mov  ax, 0

	.end2:
	pop  si
	pop  es
	pop  bx
	ret
test_int endp

; Gets PSP cmd arguments and checks whether /un flag is present.
; Also resets DS to the end of the data segment.
; Arguments	| none
; Trashed	| none
; Saved on stack| bx cx di
; Return value	| ax : 0 if /un is not present, 1 if it is
test_should_unload proc near
	push bx
	push cx
	push di

	mov  di, 82h
	mov  bl, [80h]
	cmp  bl, 3
	jb   .end_false2
	mov  cl, [di]
	cmp  cl, '/'
	jne  .end_false2
	mov  cl, [di + 1]
	cmp  cl, 'u'
	jne  .end_false2
	mov  cl, [di + 2]
	cmp  cl, 'n'
	jne  .end_false2

	mov  ax, data
	mov  ds, ax
	mov  ax, 1
	jmp  .end

	.end_false2:
	mov  ax, data
	mov  ds, ax
	mov  ax, 0

	.end:
	pop  di
	pop  cx
	pop  bx
	ret
test_should_unload endp


start proc far
	xor  ax, ax
	push ds
	mov  ax, data
	mov  ds, ax

	call test_int
	cmp  ax, 1
	je   .already_loaded	; already loaded

	.not_loaded:
	pop  ds
	push ds
	call test_should_unload
	cmp  ax, 1
	je   .exit

	lea  dx, installedstr
	mov  ah, 9h
	int  21h
	pop  ds
	call load_int
	jmp  .exit

	.already_loaded:
	pop  ds
	call test_should_unload
	cmp  ax, 1
	jne  .do_not_unload

	.unload:
	call unload_int
	lea  dx, unloadstr
	mov  ah, 9h
	int  21h
	jmp  .exit

	.do_not_unload:
	lea  dx, alreadystr
	mov  ah, 9h
	int  21h

	.exit:
	; exit, leaving memory allocated for resident interrupt routine
	mov  ah, 4Ch
	int  21h
start endp

code ends

astack segment stack
	dw 128 dup(?)
astack ends

data segment
	alreadystr	db 'Resident interrupt at 0x9 already installed', 0Dh, 0Ah, '$'
	installedstr	db 'Resident interrupt at 0x9 installed', 0Dh, 0Ah, '$'
	unloadstr	db 'Unloaded interrupt at 0x9', 0Dh, 0Ah, '$'
data ends

end start