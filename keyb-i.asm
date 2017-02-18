include tsr.inc
MAIN    proc
	lea	dx,titl
	mov	ah,09
	int	21h

	mov	ah,0ffh
get:
	xor	al,al
	int	2fh
	cmp	bx,'Kb'
	je	OLREADY
	cmp	al,0
	jne	get1
	mov	[num],ah
get1:
	dec	ah
	cmp	ah,079h
	ja	get

sv = 6
	copy	sv,prg
	mov	al,[num]
	mov	es:[num],al
	push	es
	pop	ds

	lea	si,offset09
	lea	dx,save09
	mov	al,09h
	call	setint


	lea	si,offset2f
	lea	dx,save2f
	mov	al,2fh
	call	setint
	push	cs
	pop	ds

        lea     dx,ini
	mov	ah,09
	int	21h
	mov	ax,4c00h
	int	21h

olready:
	lea	dx,memory
	mov	ah,09
	int	21h
	mov	ax,4c02h
	int	21h

setint:
	MOV	AH,35h
	INT	21h
	MOV	[SI],BX
	MOV	[SI+2],ES
	MOV	AH,25h
	INT	21h
	ret

titl	db	'Keyboard driver for `Iskra 1030` v1.00'
	db	' by Dmitry Kokorev SamPI (C) 1991.',0ah,0dh,024h
memory	db	7,'Olready stay in memory.',0ah,00dh,024h
ini	db	'Alt + [ ] - swith keyboard table, '
        db      '[P/L] - swith font.',0dh,0ah,24h
prg:

SAVE    proc
org   0
num	db	0
init	db	0
save2f:
	cmp	ah,cs:[num]
	jne	int2f
	mov	bx,'Kb'
	iret
int2f:
	db	0eah
offset2f	dw	0
seg2f		dw	0

; *************** int 09 ***************


save09:
	push	ds
	push	si
	push	ax
	mov	si,40h
	mov	ds,si
	mov	al,[17h]
	test	al,00001000b	; alt is pressed
	je	noini
	in	al,60h
	cmp	al,7fh
	jne	noini
	not	byte ptr cs:[init]
noini:
	mov	si,[1ch]	;end of list
; call to original interrupt
	pushf
	db	9ah	; CALL far
offset09	dw	0
seg09		dw	0
	cmp	byte ptr cs:[init],0
	jne	exit
; change new key of buffer
	cmp	si,[1ch]
	je	exit
	mov	ax,[si]
	cmp	al,0b0h
	jb	exit
	cmp	al,0dfh
	ja	exit
	sub	byte ptr [si],30h
exit:
	pop	ax
	pop	si
	pop	ds
	iret
; *************** end int 09 *************

SAVE    endp

MAIN    endp

