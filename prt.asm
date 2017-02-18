main	proc
	jmp	start
save    proc
num	= 99h
save2f:
	cmp	ah,cs:[num]
	jne	int2f
	mov	bx,'Ps'
	iret
int2f:
	db	0eah
offset2f	dw	0
seg2f		dw	0

save17:
	push	bx
	push	ds
	cmp	ah,0
	jne	org
; *********** print char ************
        cmp     byte ptr cs:cmd,0
	je	else
setc:
	dec	byte ptr cs:cmd
	jmp	short org
else:
	call	findcmd
; *********** not command of prn ******
	cmp	al,7fh
	ja	rus
	cmp	al,41h
	jb	org
	mov	bl,0
	call	chtab
	jmp	short org
rus:
	mov	bl,1
	call	chtab
	push	cs
	pop	ds
	mov	bx,offset tabl - 80h
        xlat
org:
	pop	ds
	pop	bx
	call	int17a
	iret
int17:
	xor	ah,ah
int17a:
	pushf
	db	09ah
offset17	dw	0
seg17		dw	0
	ret
tab	db	0h
chtab:
	push	ax
	mov	al,27
	call	int17
	mov	al,'R'
	call	int17
	mov	al,bl
	call	int17
	pop	ax
	ret
cmd:	db	0h
findcmd:
	lea	si,tabc1
	mov	al,cs:[si]


	ret
tabc1:	db 'S','W','!','-','3','A','J','j','N','Q',0
tabc2:	db '
tabl:
	db 61h,62h,77h,67h,64h,65h,76h,7ah
        db 69h,6ah,6bh,6ch,6dh,6eh,6fh,70h
	db 72h,73h,74h,75h,66h,68h,63h,7eh
	db 7bh,7dh,78h,79h,78h,7ch,60h,71h
	db 41h,42h,57h,47h,44h,45h,56h,5ah
	db 49h,4ah,4bh,4ch,4dh,4eh,4fh,50h
	db 24h,24h,24h,21h,2bh,2bh,2bh,2bh
	db 2bh,2bh,21h,2bh,2bh,2bh,2bh,2bh
	db 2bh,2bh,2bh,2bh,2dh,2bh,2bh,2bh
	db 2bh,2bh,2bh,2bh,2bh,3dh,2bh,2bh
	db 2bh,2bh,2bh,2bh,2bh,2bh,2bh,2bh
	db 2bh,2bh,2bh,2ah,2ah,2ah,2ah,2ah
	db 52h,53h,54h,55h,46h,48h,43h,5eh
	db 5bh,5dh,58h,59h,58h,5ch,40h,51h
	db 65h,45h,28h,29h,28h,29h,3eh,22h
	db 22h,22h,22h,22h,22h,22h,22h,20h
save	endp
start:
	lea	dx,titl
	mov	ah,9
	int	21H

	mov	ah,0ffh
get:
	xor	al,al
	int	2fh
	cmp	bx,'Ps'
	je	OLREADY
	cmp	al,0
	jne	get1
	mov	[num],ah
get1:
	dec	ah
	cmp	ah,79h
	ja	get

        mov     al,17h
	lea	si,offset17
	lea	dx,save17
	call	setint
	mov	al,2fh
	lea	si,offset2f
	lea	dx,save2f
	call	setint
	lea	dx,start
	int	27h
olready:
	mov	dx,offset ttl2
	mov	ah,9
	int	21h
	int	20h

setint:
	MOV	AH,35h
	INT	21h
	MOV	[SI],BX
	MOV	[SI+2],ES
	MOV	AH,25h
	INT	21h
	ret

titl    db      'Robotron printer simulation v1.00 by Jim & Company 1990'
	db	0ah,0dh,24h
ttl2	db	'Olready install',0ah,0dh,24h
main	endp
