include tsr.inc
main proc
	jmp	start

; *************** int 17 *****************
save17:
	cmp	ah,000h
	jne	orig
	cmp	al,080h
	jb	orig
	cmp	al,0afh
	ja	graph
	add	al,30h
orig:
	db	0eah
offset17	dw	0
seg17		dw	0

graph:
	cmp	al,0dfh
	ja	orig
	push	bx
	mov	bx,offset tab - 0b0h
	db	2eh	; prefix cs:
	xlat
	pop	bx
	jmp short orig

; *************** end int 17 *************

tab:
	db 09bh,09ch,09dh,0a5h,0a7h,083h,084h,085h
	db 086h,097h,095h,091h,092h,08bh,08ch,0a1h

	db 0a3h,0a8h,0a6h,0a9h,0a4h,0aah,08dh,08eh
	db 093h,090h,098h,096h,099h,094h,09ah,080h

        db 081h,082h,087h,088h,089h,08ah,08fh,09eh
	db 09fh,0a2h,0a0h,0abh,0ach,0adh,0aeh,0afh
start:
	print	titl
	intr	17h,save17,offset17
	lea	dx,start
	int	27h
defsetint
titl:	db	'Setup printer alternative cyrilic.'0dh,0ah,24h
main	endp