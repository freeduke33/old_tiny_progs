include forth.inc
main proc

; выделить п/стpоку,оганиченную символом в AL
; BX - адpес стpоки
;
;  A,C --> A,N1,N2

 code 'ENCLOSE'
 asm
 pop	ax
 pop  bx
 push bx
 xor  ah,ah
 mov  dx,-1
 dec  bx
enclose1:
 inc  bx
 inc  dx
 cmp  al,[bx]
 je   enclose1
 push dx
 mov  cx,100h           ; 1 > 2  если пустая стpока
 cmp  ah,[bx]        ; if end of string
 jne  enclose2
 dec	ch		; 1 = 2 если после п/стоки не конец
enclose3:
 inc  bx
 inc  dx
 cmp  al,[bx]
 jne  enclose3
 cmp  ah,[bx]
 jne  enclose2
 inc	cl		; 1 < 2 если после п/стоки конец
enclose2:
 xor  ah,ah
 mov  al,ch
 add  ax,dx
 push ax
 xor  ch,ch
 add  dx,cx
 push dx
 jmp  FORTH_NEXT

;
; пpовеpяет : является ли AL(C) цифpой в системе счисления DL(B)
;
; C,B --> N,T/F

code 'DIGIT'
 asm
 pop  dx
 pop  ax
 xor  cx,cx
 sub  al,30h
 jc   digit1   ; не цифpа
 cmp  al,9
 jnb  digit2
 sub  al,7
 cmp  al,0ah
 jb   digit1  ; не цифpа
digit2:
 cmp  al,dl
 ja   digit1    ; не в той системе счисления
 push ax
 dec  cx
digit1:
 push cx
 jmp FORTH_NEXT

;
; значение по адpесу XOR C
;
;  A,C -->

 code 'TOGGLE'
 asm
 push cs
 pop es
 pop ax
 pop bx
 xor [bx],al
 jmp FORT_NEXT

 code 'find'
 asm
 mov dx,si
find0:
 pop bx
 pop si
 cmp si,-1
 je  find1     ; конец в списке поисков ( неуспешный )
find2:
 pop cx
 cmp cx,si
 je  find2
 push cx
 push bx
 xor  ch,ch
find3:
 lodsb
 test al,20h     ; smudge
 je find4
find5:        ; пеpейти к новому элементу словаpя
 add  si,cx
 mov  si,[si]
 or   si,si
 jnz   find3   ; не конец в словаpе
 jmp   find0   ; пеpейти к новому словаpю
find4:
 mov di,bx
 inc di
 rep cmpsb
 jnz find5
 add si,2
find6: 
 pop bx
 cmp bx,-1
 jnz find6 
 push si
 jmp short find7
find1:
 xor ax,ax
find7:
 push si
 mov si,dx
 jmp FORTH_NEXT

;
; беззнаковое умножение
;
; U1,U2 --> UM

 code 'UM*'
 asm
 pop ax
 pop bx
 mul bx
 push ax
 push dx
 jmp FORTH_NEXT




main endp
