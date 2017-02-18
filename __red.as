TXTlen equ 30 * 10
BUFlen equ 5 * 1024
endBUF equ offset BUF + BUFlen - 2


.model tiny
.code
org 100h
begin:
    jmp start
include tsr.mac
include scankey.inc

status_key  equ 417h

POP_KEY     = 80h
RUN_TSR     = 40h

seg_f   dw  0
off_f   dw  0
len_f   dw  0
NUM_INIT dw 0
ID  db  0
bit     db      0
key_list:
key_1   db  39h
    dw  03h
key_2   db  39h
    dw  01h
key_3   db  39h
    dw  03h
key_4   db  39h
    dw  01h

END_list = offset key_list + 12


defineID ID,'RC'

save09:
    push    ax
    push    si
    push    ds
    xor ax,ax
    mov ds,ax
    mov si, offset key_list -3
    in  al,60h
scan:   
    add si,3
    cmp si,END_list
    je  no_ini
    cmp al,cs:[si]
    jne scan
    mov ax,cs:[si+1]
    test ax,word ptr ds:[status_key]
    je  scan
    sub si, offset key_list
    mov cs:NUM_INIT,si
    or  cs:bit,POP_KEY
no_ini:
    pop ds
    pop si
    pop ax
    FAR_JMP
store09 dw  0,0



save08:
    pushf
    FAR_CALL
store08 dw  0,0
    call    testini
    iret


testini:
    test    cs:bit,POP_KEY 
    jne  ok
no_ok:
    ret
ok:
    test    cs:bit,RUN_TSR
    jne  no_ok
    or  cs:bit,RUN_TSR
    call    prg
    mov cs:bit,0
    ret


outintr proc
prg:
    mov cs:_ss_,ss
    mov cs:_sp_,sp
    push    cs
    pop ss
    mov sp,offset SSseg

    push    bp
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    push    ds
    push    es
;
; restore previous interrupts
;
    call    locseg
    mov si,off_f
    mov cx,len_f
    lea di,swp
    mov ds,seg_f
    cld 
    rep movsb

    call locseg
    mov ah,62h
    int 21h
    mov PID,bx

    mov bx,cs
    mov ah,50h
    int 21h

    call main

    mov ah,50h
    mov bx,cs:PID
    int 21h

    mov di,off_f
    mov cx,len_f
    lea si,swp
    mov ds,seg_f
    cld
    rep movsb

    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    mov ss,cs:_ss_
    mov sp,cs:_sp_
    ret

locseg:
    push cs
    pop  es
    push cs
    pop  ds
    ret

swp db 1000h dup('x')

main proc 
    call getMODE
    mov  cs:Vseg,bx
    cmp ah,0
    jne graph
; текстовый режим
    call saveTXT
    call ClearKBD
    call interfase
    call restoreTXT
    ret
; графический режим
graph:
    ret
endp main


; Узнать текущий режим дисплея ( посредством BIOS )
; AL= видеорежим
; AH= 1 - текстовый, 0 - графический
; BX= VideoSegment
getMODE proc near
    mov ah,0fh
    int 10h
    mov ds:Vpage,bh
    mov ds:Column,ah
    xor ah,ah
    lea si,TransVmode
    add ax,ax
    add si,ax
    mov ax,cs:[si]
    ret
endp getMODE

saveTXT proc near
    call FullWindow
    mov ah,03h
    int 10h
    mov cSIZE,cx
    mov cPOS,dx
    call hiddenCursor
    lea di,SaveARRAY
    lea si,windHI
    mov cs:CurrPTR,offset eraseTXT
    call locseg
    call moveTXT
    call SmallWindow
    ret
endp saveTXT

restoreTXT proc near
    call FullWindow
    lea di,SaveARRAY
    mov cs:CurrPTR,offset closeTXT
    call moveTXT
    call SmallWindow
    mov dx,cPOS
    mov ah,2
    int 10h
    mov cx,cSIZE
    mov ah,1
    int 10h
    ret
endp restoreTXT

writeTXT proc
    lea di,bufTXT
    mov cs:CurrPTR,offset buftoTXT
    mov cs:posTXT,offset bufTXT
    call moveTXT
    ret
writeTXT endp

FullWindow proc
    dec  byte ptr [windLeft]
    dec  byte ptr [windLeft+1]
    add  windLEN,2
    add  windTOP,2
    ret
FullWindow endp

SmallWindow proc
    inc  byte ptr [windLeft]
    inc  byte ptr [windLeft+1]
    sub  windLEN,2
    sub  windTOP,2
    ret
SmallWindow endp

ClearKBD proc
next_key:
    mov  ah,1
    int  16h
    jz   run
    mov	 ah,0
    int  16h
    jmp short next_key
run:
    ret
ClearKBD endp

;
; SI := адрес таблицы заполнения
;

moveTXT proc near
    mov cx,windTOP
    mov dx,windLeft
    mov bh,Vpage
    mov bp,windLEN
move_1:
    push cx
    push dx
    mov cx,bp
move_2:
    mov ah,02h
    int 10h
    push cx
    call word ptr [CurrPTR]
    pop  cx
    inc  dl
    loop move_2 
    pop dx
    pop cx
    cmp cx,2
    je nodecSI
    cmp cx,windTOP
    je nodecSI
    sub si,3
nodecSI:
    inc dh
    loop move_1
    ret
endp moveTXT
putch proc
    mov ah,9
    mov cl,1
    int 10h
    ret
putch endp

; запомнить экран и вывести рамку
; SI := указатель на таблицу 
; DI := область запоминания экрана
;

eraseTXT proc near
    mov ah,08h
    int 10h 
    stosw
    lodsb
    cmp cx,bp
    je  angle
    cmp cx,2
    jbe angle
    dec si
angle:
    mov bl,windATTR
    jmp short putch
endp eraseTXT

; параметры см eraseTXT
; закрыть окно
;
closeTXT proc near
rest_1:
    mov ax,[di]
    inc di
    inc di
    mov bl,ah
    jmp short putch
endp closeTXT

buftoTXT proc near
    push bx
    mov al,[di]
    inc di
    mov ah,al
; выделить атрибут буквы
    and al,11000000b
    clc
    rcl al,1
    rcl al,1
    rcl al,1
    lea bx,windATTR
    xlat
; выделить код буквы 
    xchg al,ah
    and al,00111111b
    lea bx,ASCIItab
    xlat
    pop bx
    mov bl,ah
    jmp short putch 
endp buftoTXT
;
;
;
hiddenCursor proc
    mov  cx,2000h
    mov ah,1
    int 10h
    ret
hiddenCursor endp

interfase proc near
    mov  _s_sp_,sp
    mov	 al,ds:[windATTR+4]
    mov  ds:[windATTR+1],al
    call topic
    call initSEL
mainmenu:
    mov  al,0
    call Select
    call Switch
    cmp  byte ptr outR,1
    jne  int_1
    mov  byte ptr numSEL,1
    jmp short mainmenu
int_1:
    cmp  byte ptr outR,-1
    jne  int_2
    mov  al,maxSEL
    mov  byte ptr numSEL,al
    jmp  short mainmenu
int_2:
    ret
endp interfase

initSEL proc near
    mov byte ptr numSEL,0
    mov al,1
    call Select
    ret
initSEL endp

;  Стpуктуpа 1б текста в bufTXT
;
;  AACC CCCC
;    -------  код символа 00 ... 64
;  --         атpибут символа
;  00 обычный текст
;  10 выбиpаемый текст
;  01 подсветка
;  11 выбpанный текст

Select proc
;
; AL := +/- 1
; 
 add al,numSEL
 cmp al,0
 jbe outRange
 cmp al,maxSEL
 ja  outRange
;
; если выбоp находится в пpеделах, то
;
 mov numSEL,al          ; запомнить новый выбоp
 call unSelect          ; убpать отобpажение стаpого в тексте
 call setSEL            ; отобpазить новый
 call WriteTXT          ; и вывести текст в окно
 ret
;
; иначе установить флаг CF и outR := значение AL на входе
;
outRange:
 sub al,numSEL
 mov outR,al
 stc
 ret
Select endp

;
; убpать из текста буквы, помеченные как куpсоp
;
unSelect proc
 mov cx,TXTlen          ; для пpосмотpа всего текста
 lea si,bufTXT
unsel:
 cmp byte ptr [si],11000000b    ; если атpибут := 11b тогда 
 jb  nosel
 and byte ptr [si],0bfh           ; пpеобpазовать его в 10b
nosel:
 inc si
 loop unsel
 ret 
unSelect endp

setSEL proc
 mov si,offset bufTXT - 1
 mov cl,numSEL
 xor ch,ch
 mov bl,1
set_1:
 xor al,al
set_2:
 inc si
 test byte ptr [si],10000000b
 jz set_1
; если это позиция куpсоpа 
 or al,al
 jnz set_2
; и она пеpвая в последовательности выбиpаемого слова
 inc al
 loop set_2 ; уменьшить число оставшихся выбоpов
;
; тепеpь отобpазить куpсоp
;
invers:
 or  byte ptr [si],40h
 inc si
 test byte ptr [si],10000000b
 jnz invers
 ret
setSEL endp

;  Стpуктуpа 1 записи в словаpе
;
;  00??????
;    ------ код символа
;  T0NNNNNN
;    ------ число букв след уpовня
;  -        пpизнак конца слова ( наличие текста )
;  4б - смещение текста в файле данных ( если Т установлен )
;


;
; pазобpать запись
;
ParseRecord proc
;
; SI := указатель на запись
; BH := 0
;
 lodsw                  ; пpочитать символ и число след букв
 xor ah,ah
 test al,80h            ; если есть текст
 jz notext
 add si,4               ;  пеpейти к след записи
notext:
 and bl,00111111b       ; выделить число след букв
 add cx,bx              ; и добавить их к пpосмотpу
 ret
ParseRecord endp

;
; пеpейти к следующей букве, пpопустив высшие уpовни
;
TonextChar proc
;
; SI := указатель на запись
;
 xor cx,cx
 mov bh,cl
loop_next:
 call ParseRecord
 cmp si,endBUF
 jb no_read
 call updateBUF
no_read:
 loop loop_next
 ret 
TonextChar endp

findWord proc
 call initfile
 call setfile
 lea di,wordtofind
 xor bh,bh
 mov cx,numFirst
findW:
 mov al,[si]
 or al,al
 jz endFind
 cmp al,[di]
 jne nextfind
 inc di
 xor cx,cx
 call ParseRecord
 or cx,cx
 jnz findW
 sub si,ax
 jmp short failFind
nextfind:
 push cx
 call TonextChar 
 pop cx
 loop findW
failFind:
 xor al,al
endFind:
 ret
 findWord endp

;
; CF := 1 - выход за пределы выбора outR определено
;       0 - выбрано numSEL
;

Switch proc
 mov byte ptr outR,0
getkey:
 mov ah,0
 int 16h
 cmp ax,PgDn
 jne key1
 mov byte ptr outR,2
 stc
 ret
key1:
 cmp ax,PgUp
 jne key2
 mov byte ptr outR,-2
 stc
 ret
key2:
 cmp ax,CUR_LEFT
 je  key2_
 cmp ax,CUR_Up
 jne key3
key2_:
 mov al,-1
 call Select
 jnc getkey
 ret
key3:
 cmp ax,CUR_RIGHT
 je  key3_
 cmp ax,CUR_Down
 jne key4
key3_:
 mov al,1
 call Select
 jnc getkey
 ret
key4:
 cmp ax,Home_KEY
 jne key5
 mov outR,3
 stc
 ret
key5:
 cmp ax,ESC_KEY
 jne key6
 call Clear
 ret
key6:
 cmp ax,Back_KEY
 jne key7
 stc
 ret
key7:
 cmp ax,RET_KEY
 jne key8
 clc 
 ret
key8:
 cmp ax,F1
 jne key9
 call Help
 jmp getkey
key9:
 cmp ax,F2
 jne key10
 call Clear
 call CaseWord
 ret
key10:
 mov ax,BELL+0e00h
 int 10h
 jmp getkey
Switch endp

;
; Запись в буфер заставки и выбора режимов работы
;
topic proc
   call locseg
   cld
   lea si,topTitl
   lea di,bufTXT
   mov cx,TXTlen
   rep movsb
   call writeTXT
   mov  byte ptr maxSEL,3
   ret
topic endp

;
;
;
help proc
   ret
help endp

;
;
;
caseWord proc
  ret
caseWord endp

;
;
;
Clear proc
   pop ax
   mov sp,_s_sp_
   push ax
   ret
Clear endp

;
;
;
;
InitFile proc
   ret
initFile endp

;
;
;
SetFile proc
   ret
SetFile endp

;
;
;
updateBUF proc
   ret
updateBUF endp


;
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
;                *********************************
;                        #################
;
TransVmode:         ; таблица видеорежимов
    db 0,0      ; текст 40х25
    db 1,0      ; 1
    db 2,0      ; 2
    db 3,0      ; 3
    db -1,1     ; 4
    db -1,1     ; 5
    db -1,1     ; 6
    db 7,0      ; 7
    db -1,2     ; 8
    db -1,2     ; 9
    db -1,2     ; a
    db -1,2     ; b
    db -1,2     ; c
    db -1,1     ; d
    db -1,1     ; e
    db -1,1     ; f
    db -1,1     ; 10
    db -1,1     ; 11
    db -1,1     ; 12
    db -1,1     ; 13

_s_sp_	 dw  0   ; 
outR	 db  0   ; значение ошибки при выходе за предел в списке выбора
numSEL	 db  0	 ; номер текущего выбора в списке
maxSEL	 db  0   ; число выборов
CurrPTR  dw  0   ; адрес процедуры сохранения/восстановления
Vpage    db  0   ; текущая видеостраница
Vseg     dw  0   ; и сегмент
Column   db  0   ; число столбцов на экране
cPOS     dw  0   ; позиция и
cSIZE    dw  0   ; размер курсора
windLeft dw  050Ah ; левый верхний угол окна
windLEN  dw  30  ; ширина окна
windTOP  dw  10  ; высота окна
windATTR db  30h ; атрибут окна      00
     db  40h     ; атрибут выбора    01 
     db  35h     ; атрибут выделения 10
     db  70h     ; атрибут курсора   11
     db  77h     ; атрибут заставки
windHI   db  '╒','═','╕'
windFILL db  '│',' ','│'
windLO   db  '╘','═','╛'
wordtoFind   db 30 dup('?')
numFirst dw  0
posTXT   dw  0
BufTXT   db  30 * 10 dup('X')
saveARRAY dw 32 * 12 dup('Vp')


topTitl	 db  56,56,76,56,56,56,76,76,56,56,76,56,56,76,76
	 db  56,56,56,76,76,56,76,76,56,56,76,56,56,56,56
	 db  56,76,56,76,56,76,56,76,56,76,56,76,56,76,56
	 db  76,56,76,56,76,56,76,56,76,56,76,76,56,56,56
	 db  56,76,56,56,56,76,56,76,56,76,56,76,56,76,76
	 db  56,56,76,56,76,56,76,56,76,56,76,56,76,56,56
	 db  56,76,56,76,56,76,56,76,56,76,56,76,56,76,56
	 db  76,56,76,76,76,56,76,76,56,56,76,56,76,56,56
	 db  56,56,76,56,56,76,56,76,56,56,76,56,56,76,76
	 db  56,56,76,56,76,56,76,56,56,56,76,76,56,56,56
	 db  56,56,56,56,56,56,56,56,56,56,56,56,56,56,56
	 db  56,56,56,56,56,56,56,56,56,56,56,56,56,56,56
	 db  56,56,56,56,56,56,00,38,29,36,39,56,61,56,15
	 db  44,42,42,35,34,34,56,56,56,56,56,56,56,56,56
	 db  57,57,57,57,57,57,57,57,57,57,57,57,57,57,57
	 db  57,57,57,57,57,57,57,57,57,57,57,57,57,57,57
	 db  56,162,165,168,167,169,171,56,170,167,158,159,169,160,154
	 db  166,162,159,56,156,156,167,158,184,170,164,167,156,154,56
	 db  56,56,56,56,56,56,56,56,56,56,56,56,56,56,56
	 db  56,56,56,56,56,56,56,56,56,56,56,56,56,56,56
;	 db  ' импоpт содеpжание ввод_слова '

ASCIItab db  'ABCDEFGHIJ'
	 db  'KLMNOPQRST'
         db  'UVWXYZабвг'
	 db  'дежзиклмно'
	 db  'пpстуфхцчш'
	 db  'щыьэюя "?!'
	 db  ':-,.'

Buf	 db  BUFlen dup('F')
PID 	dw  0
_ss_    dw  0
_sp_    dw  0

        dw  260 dup('Ss')
SSseg   dw  0   

outintr endp

start:
    mov ax,5d06h
    int 21h
    mov cs:seg_f,ds
    mov cs:off_f,si
    mov cs:len_f,cx
    call locseg

    print   titl
    mov	  ah,30h
    int 21h
    xchg al,ah
    cmp  ax,330
    jb   bad_dos
    find ID,'RC',already
next_start:
    call command_line
    push bx
    ret
bad_dos:
    print error_dos_ver
    mov ax,4c01h
    int 21h

already:
    mov byte ptr more,'b'
    print exist
    mov si,offset keys+2
    mov ax,offset no_keys
    mov [si],ax
    jmp short next_start

resident:
    setID
	intr    09h,save09,store09
        intr    08h,save08,store08

    call    locseg
    print   install
    lea dx,start
    int 27h

help_text:
    print help_msg
    int  20h

mem_size:
    jmp resident

no_keys:
    call main
exit_to_dos:
    mov  ax,4c00h
    int 21h

command_line:
    mov bx,offset no_keys
    mov si,81h
    xor ah,ah
    mov ch,ah
scan_cmd:
    lodsb
    cmp al,20h
    je scan_cmd
    cmp al,0dh
    jne no_ret
    ret
no_ret:
    or ah,ah
    jne is_it_key
    cmp al,'/'
    je end_div
    cmp al,'-'
    je end_div
bad_key:
    mov bx,offset help_text ; неизвестный символ 
    ret
end_div:
    inc ah
    jmp short scan_cmd
is_it_key:
    mov di,offset keys
    mov cl,3
scan_keys:  
    cmp al,[di]
    je ok_key
    cmp al,[di+1]
    je ok_key
    add di,4
    loop scan_keys
    jmp short bad_key
ok_key:
    mov bx,[di+2]
    ret
    	

titl    db  'Resident Dictionary by Dmitry Kokorev '
    db  'SamPI (C) 1991.',0dh,0ah,24h
exist   db  'stay in memory :'
install db  'Press Shift-Space to work in it',0ah,0dh
more    db  24h
        db  'ut if you want ...',0ah,0dh,24h
error_dos_ver db 'Invalid dos version',0ah,0dh
keys	db  'Ii'
	dw  offset resident
	db  'Hh'
	dw  offset help_text
	db  'Gg'
	dw  offset mem_size
end_keys:
chartodiv db ' -/'
help_msg db  0ah,0dh,'usage: ReDIC [/|-key]',0ah,0dh
         db  '/I stay resident ( install already in text mode )',0ah,0dh
	 db  '/G stay resident ( install in graph/text mode)',0ah,0dh
         db  '/H this screen',0ah,0dh,24h

DEFSETINT
  end begin
