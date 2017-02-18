; **************************************
; *                                    *
; *           TSR - routines           *
; *                                    *
; *  by Jim & Company created 2-12-90  *
; *          editing 19-2-91           *
; *                                    *
; **************************************

;  define small memory block from end of RAM
;  copy program to small memory block
;
;  parametrs of macro :
;
;    sv - length of program to copy / 10h ( paragraph )
;    sav - offset program in DS segment
;
copy    macro   sv,sav
        mov     ax,cs
	dec	ax
	push	ds
	mov	ds,ax
	mov	ax,[3]	; length of current block
	sub	ax,sv + 1
	mov	bx,ax
	mov	ah,4ah	; free block
	int	21h
	mov	bx,sv
	mov	ah,48h	; allocate block
	int	21h
	mov	es,ax
	dec	ax
	mov	ds,ax
	mov	[1],es	; Himself
	pop	ds
	mov	si,offset sav
	xor	di,di
	mov	cx,sv * 8	; 10h / 2
	repnz movsw
copy	endm

;
;  redefine interrupt vector
;
;  parametrs
;
;       num - number of redefine vector
;       save - mark of begin new interrupt
;       store - mark of buffer to store old vector
;
intr	macro num,save,store
	mov	al,num
	MOV	DX,offset save
	MOV	SI,offset store
	CALL	SETINT
intr	endm


defsetint  macro

SETINT:
	MOV	AH,35h
	INT	21h
	MOV	[SI],BX
	MOV	[SI+2],ES
	MOV	AH,25h
	INT	21h
	RET
defsetint  endm

; find program in memory if it is install INT 2Fh
;
;  parameters:
;  num - byte ptr from store free number in DOS spuler
;  str - word by indetification code
;  label - JMP label if program alrealy exist in memory

find	macro	num,str,label

	mov	ah,0ffh
get:
	xor	al,al
	int	2fh
	cmp	bx,str
	je	label
	cmp	al,0
	jne	get1
	mov	num,ah
get1:
	dec	ah
	cmp	ah,7fh
	ja	get
find	endm

; code to definition ID of program
;
; parameters:
; num - byte ptr to stored ID
; str - code to identification
;
; compile small version of code if previous
; defined:
;          IDsmallcode
;

defineID	macro	num,str
_save2f_:
	cmp	ah,cs:num
	jne	_int2f_

ifndef IDsmallcode

	push	cs
	pop	es

endif

        mov     bx,str
	iret
_int2f_:
	db	0eah
_store2f_ dw	0,0
defineID	endm

; initialization interrupt by user ID code

setID	macro
	intr 2fh,_save2f_,_store2f_
setID	endm

; deinitialization interrupt by user ID code,
; restore old interrupt
;
; parameter:
;   seg - prefix by get previous vector

deleteID macro seg
	mov	ax,252fh
	mov	dx,seg _store2f_
	mov	ds,seg _store2f_+2
	int	21h
deleteID endm
FAR_JMP macro
	db	0eah
FAR_JMP endm
FAR_CALL macro
	db	09ah
FAR_CALL endm
print	macro	str
	lea	dx,str
	mov	ah,9
	int	21h
print	endm

putc	macro	chr
	mov	al,chr
	mov	ah,14
	int	10h
putc	endm

setflag macro
	push	ax
	push	si
	pushf
	pop	ax
	mov	si,sp
	mov	ss:[si+8],ax
	pop	si
	pop	ax
setflag endm



