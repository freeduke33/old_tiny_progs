include tsr.inc
MAIN    proc
	mov	bp,offset prg
	LEA	DX,TITL
	MOV	AH,9
	INT	21h
find [9ah],'SD',olready
	jmp	short command

OLREADY:
	mov	si,offset str+2
	mov	[si],offset reinit
	mov	[si+4],offset del
	mov	[si+12],offset reinit
	LEA	DX,RESIDENT
	MOV	AH,9
	INT	21h
	mov	dx, es:[offset sav +2]
	cmp	byte ptr es:[swith],0ffh
	jne	e1
	mov	dx,es:[offset sav ]
e1:
	int	21h

command:
	MOV	SI,81h
	MOV	Cl,[SI-1]
	mov	di,offset str
LOC:
	LODSB
	CMP	AL,'/'
	JNE	LOC1
	LODSB
loc2:
	CMP	AL,[di]
	Je	jms
	CMP	AL,[di+1]
	JE	jms
	add	di,4
	cmp	di,offset endstr
	jb	loc2
EXIT:

	LEA	DX,HELP
sexit:
	mov	ah,9
	INT	21h
	INT	20h
LOC1:
	cmp	al,' '
	jne	exit
	LOOP	LOC
	JMP	short EXIT
jms:
	mov	ax,[di+2]
	push	si
	push	ax
	ret

option:
	mov	bx,offset cod - 1
opt:
	xor	ah,ah
	lea	di,set
        lodsb
	cmp	al,' '
	je	opt
	mov	cx,3
	cmp	al,0dh
	jne	se1
	ret
se1:
	cmp	[di],al
	je	se0
	cmp	[di+1],al
	je	se0
	add	di,6
	loop	se1
	jmp	short exit
se0:
	cmp	bx,offset cod - 1
	jne	se8
	mov	al,[di+3]
	add	bx,ax
	mov	ax,[di+4]
even
        mov     es:[bp + offset sav],ax
	jmp	short opt
even
se8:
	mov	al,[di+2]
	add	bx,ax
	mov	ax,[di+4]
	mov	es:[bp + offset sav + 2],ax
	mov	di,offset tc1 + 1
	mov	ax,[bx]
	mov	byte ptr es:[bp+di],al
	mov	byte ptr es:[bp+di+4],ah
	mov	al,[bx+2]
	mov	byte ptr es:[bp+di+7],al

	ret
; ============== save setup in program =============
even
setup:
	push	cs
	pop	es
	pop	si
	call	option
	call	newcode
	mov	si,offset str+2
	mov	[si],offset init
	mov	[si+4],offset notdel
	lea	dx,write
	mov	ah,9
	int	21h
	mov	si,2ch
	mov	ds,cs:[si]
	xor	si,si
se:
	dec	si
	lodsw
	cmp	ax,0
	jne	se
	add	si,2
	mov	ax,3d01h
	mov	dx,si
	int	21h
	jc	error
	mov	bx,ax
	mov	ah,40h
	push	cs
	pop	ds
	mov	dx,100h
	mov	cx,offset top - 100h
	int	21h
	jc	error
	mov	ah,3eh
	int	21h
	jc	error
done:
	lea	dx,ok
	mov	ah,9
	int	21h
	int	20h
error:
	push	cs
	pop	ds
	lea	dx,err
	mov	ah,9
	int	21h
	int	20h

; =========== release in memory ===============
verf:
	mov	ah,35h
	int	21h
	mov	ax,es
	cmp	ax,cx
	jne	error
	ret

del:
	lea	dx,erase
	mov	ah,9
	int	21h

        push    es
	mov	cx,es
	mov	al,09h
	call	verf
	mov	al,1ch
	call	verf
	mov	al,2fh
	call	verf
        pop     es

deleteID es:
	mov	al,09h
	mov	ds,es:seg09
	mov	dx,es:offset09
	int	21h

	mov	al,1ch
	mov	ds,es:seg1c
	mov	dx,es:offset1c
	int	21h


        mov     ah,49h
	int	21h
	push	cs
	pop	ds
	jmp	short done

notdel:
	lea	dx,notresid
	push	cs
	pop	ds
	jmp	sexit

; =========== init in environment =============
init_e:
	push	es
	mov	es,cs:[2ch]
	mov	ah,49h
	int	21h
	pop	es
	jmp	short init


; =========== reinit installing program =======

reinit:
	pop	si
even
        xor     bp,bp
	call	option
	call	newcode
	int	20h

; =========== init program in memory ==========

sv	= 0dh
init:
	pop	si
	call	option
copy sv,prg
	mov	al,[9ah]
	mov	es:[num],al
	mov	byte ptr es:[swith],0ffh
	xor	bp,bp
	call	newcode

        push    es
	pop	ds
setID
intr 1ch,save1c,offset1c
intr 09h,save09,offset09

	push	cs
	pop	ds

	LEA	DX,STAY
	MOV	AH,9
	INT	21h
	mov	ax,4c01h
	int	21h

newcode:
	lea	dx,reset
	mov	ah,9
	int	21h
	mov	dx,es:[bp + offset sav]
	int	21h
	lea	dx,to
	int	21h
	mov	dx,es:[bp + offset sav + 2]
	int	21h
	ret


; SI - offset to save INT , AL - num INT , DX - new offset INT

defsetint

; ******************* DATA *****************

str:	db	'Ii'
	dw	offset init
	db	'Rr'
	dw	offset notdel
	db	'Ss'
	dw	offset setup
	db	'Ee'
	dw	offset init_e
endstr:
cod:
o2:
	db	0b0h	;o2a
	db	0bfh
	db	04h

	db	080h	;o2m
	db	0bfh
	db	04h

	db	3	;o2o
	db	2
	db	4

a2:
	db	3	;a2a
	db	2
	db	4

        db      080h    ;a2m
	db	0afh
	db	04h

	db	0e0h	;a2o
	db	0efh
	db	02ch

m2:
	db	0b0h	;m2a
	db	0dfh
	db	2ch

	db	3	;m2m
	db	2
	db	4

	db	0b0h	;m2o
	db	0efh
	db	2ch

set	db	'Oo'
	db	offset o2 - offset cod
	db	7
	dw	offset oldc
	db	'Mm'
	db	offset m2 - offset cod
	db	4
	dw	offset maic
	db	'Aa'
	db	offset a2 - offset cod
	db	1
	dw	offset altc

STAY:	DB	'Stay resident, press <rigth Shift>+<TAB> to change'
	DB	' cyrilic',0Ah,0Dh,24h
RESIDENT:
	DB	'Already stay in memory, '
	DB	'verify . . . ',24h
erase:	db	0ah,0dh,'Release processing . . . ',24h
notresid:
	db	'Don`t find program in memory.',0ah,0dh
help:	DB	07,0ah,0dh,010h,' ASDec /key [setup]',0ah,0dh
	db	'  use keys:',0dh,0ah
	db	'    /S  - store new settings',0ah,0dh
	db	'    /I  - install',0ah,0dh
	db	'    /E  - install in environment',0ah,0dh
	db	'    /R  - release program',0ah,0dh
	db	'  setup:',0dh,0ah
	db	'    it is set cyrilic in ASDec, '
	db	'first character - original',0dh,0ah
	db	'    cyrilic, second - new cyrilic '
	db	'from this program',0dh,0ah
	db	'    for example :',0dh,0ah
	db	'     OA - old is an original cyrilic,',0ah,0dh
	db	'          alternative - after pressing '
	db	'<rigth Shift>+<TAB>'0ah,0dh
	db	'          uses cyrilic: "O"ld, "A"lt, "M"ain',0ah,0dh
	db	24h

TITL	DB	'Advanced Screen Decoder v5.02 by Dmitry Kokorev SamPI'
	db	' Software (C) 1992.',0Dh,0Ah,24h
altc	db	'Alternative cyrilic ',0dh,0ah,24h
oldc	db	'Old cyrilic ',0dh,0ah,24h
maic	db	'Main cyrilic ',0dh,0ah,24h
err	db	7,'ERROR',0ah,0dh,7,24h
write	db	'Save setup . . . ',24h
ok	db	'done.',0ah,0dh,24h
reset	db	'Original - ',24h
to	db	'ASDec included - ',24h
prg:

org 0
SAVE	proc

sav     dw      offset maic
	dw	offset altc

defineID [num],'SD'

len = 160

SAVE1c:
	cmp	byte ptr cs:[swith],0ffh
	jne	continue
	iret
continue:
	not	byte ptr cs:[swith]

	push	dx
        push    ds
	push	ax
	push	cx
	push	si
	xor	dx,dx
	mov	ds,dx

	mov	al,[449h]	; current video mode
	cmp	al,7		; monochome text mode
	jne	cmp3
	mov	dh,0b0h
	jmp	short notcmp3
cmp3:
	cmp	al,3		; all text mode
	ja	popint1c
	mov	dh,0b8h

notcmp3:
	mov	ax,[044ch]	; length of video buffer
	cmp	ax,cs:[ofs]
	ja	old
	mov	cs:[ofs],ds
old:

	mov	si,cs:[ofs]
	add	si,[044eh]	; current offset from video segment
	mov	ds,dx
	cmp	dh,0b0h
	je	no_wait
	mov	dx,3dah
no_wait:
	mov	cx,len
next:
	cmp	dh,0b0h
	jae	skip1
        in      al,dx
        test    al,01
        jnz     next
	cli
wait1:
	in	al,dx
	test	al,01
	jz	wait1
skip1:
	lodsw
	sti
tc1:    cmp     al,080H
	jb	else
tc2:	cmp	al,0afh
	ja	else
tc3:	add	al,30h
	mov	ah,al
	cmp	dh,0b0h
	jae	skip2

wait2:
        in      al,dx
        test    al,8h
        jnz     wait2
	cli
wait3:
	in	al,dx
	test	al,1h
	jz	wait3
skip2:
	mov	[si-2],ah
	sti
else:
	loop	next
	mov	cs:[ofs],si

popint1c:
	pop	si
	pop	cx
	pop	ax
	pop	ds
	pop	dx

	not	byte ptr cs:[swith]
        iret

OFFSET1c	DW	0
SEG1c		DW	0

; *********************************


; *************** int 09 ***************

POP_KEY = 0Fh ; TAB

save09:
        push    ax
        in      al,60h
        cmp     al,POP_KEY
        jne      normal
        push    ds
	xor	ax,ax
	mov	ds,ax
	mov	al,[0417h]
	test	al,01h		; Rigth Shift
	pop	ds
	jz	normal
	not	byte ptr cs:[swith]
normal:
        pop     ax

        db      0eaH    ;JMP far
offset09	dw	0
seg09		dw	0

; *************** end int 09 ************
swith	= offset seg09 + 2
num	= swith + 1
OFS	= swith + 2

SAVE    endp
_lenTSR = OFS + 2
org   swith + offset prg
top:
MAIN    endp
