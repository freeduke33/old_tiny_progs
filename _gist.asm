.model small

PUBLIC _GistogramPtr
PUBLIC _SumPtr
PUBLIC _LenLine
PUBLIC _Shift_Gist

.data
_GistogramPtr 	dd 0
_SumPtr 	dd 0
_LenLine	db 0

.code

;
; AX= current line
;

_Shift_Gist proc far

	mov dx,ax
	mov bl,cs:_LenLine
	mov cl,bl
	xor ch,ch
	mul bl
	les bx,cs:_GistogramPtr
	add bx,ax
	stc
	pushf
loop_1:
	popf
	ror byte ptr es:[bx],1
	pushf
	inc	bx
	loop loop_1
	les bx,cs:_SumPtr
	add bx,dx
	add bx,dx
	mov ax,es:[bx]
	popf
	sbb ax,0
	inc ax
	mov es:[bx],ax
	ret
 endp _Shift_Gist

;
; AX = size of current line
;
;
 end