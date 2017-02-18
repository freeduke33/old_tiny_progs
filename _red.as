
STACKlen equ 100
TXTlen   equ (len_window-2) * (top_window-2)
BUFlen   equ 5 * 1024
endBUF   equ offset start + BUFlen - 2
BUF      equ offset start
ARRAYlen equ top_window * len_window * 2
bufTXT   equ BUF + BUFlen
ARRAY    equ bufTXT + TXTlen
BEGINlen equ BUFlen
topTSR   equ ARRAY + ARRAYlen
lenSWP	 equ topTSR - offset main


len_window equ 30 + 2
top_window equ 09 + 2
windATTR   equ attr_bkg
base_name  equ  060h
ovl	   equ  0B0h

.model tiny
.code
org 100h
begin:
    jmp start
include tsr.mac
include scankey.inc

status_key  equ 417h

POP_KEY dw	0
RUN_TSR db	0
SWP_DOS db	30h dup ('W')
tmp	db	50h dup ('T')
	dw	STACKlen dup('Ss')
SSseg   equ	$-2
oldint	db	1024 dup('V')

save_seg dw	0
tmp_end	 dw	offset tmp
seg_f   dw  0
off_f   dw  0
len_ff  dw  0
ID  	db  0
_s_sp_	dw  0   
PID 	dw  0
_ss_    dw  0
_sp_    dw  0


key_list:
        db  39h
    	dw  03h
        db  39h
	dw  01h
        db  39h
	dw  03h
        db  39h
	dw  01h
END_list equ $


defineID ID,'_D'

save09:
    push    ax
    push    si
    push    ds
    xor     ax,ax
    mov     ds,ax
    mov     si, offset key_list -3
    in      al,60h
@@scan:   
    add     si,3
    cmp     si,offset END_list
    je      @@no_ini
    cmp     al,cs:[si]
    jne     @@scan
    mov     ax,cs:[si+1]
    test    ax,word ptr ds:[status_key]
    je      @@scan
    sub     si,offset key_list - 2
    mov     cs:POP_KEY,si
    in      al,61h
    mov     ah,al
    or      al,80h
    out     61h,al
    mov     al,ah
    out     61h,al
    mov     al,20h
    out     20h,al
    cmp     al,0
@@no_ini:
    pop ds
    pop si
    pop ax
    je @@next
    iret
@@next:
    FAR_JMP
store09 dw  0,0



save08:
    pushf
    FAR_CALL
store08 dw  0,0
    call    testini
    iret

save28:
    pushf
    call prg
    popf
    FAR_JMP
store28 dw 0,0

save24:
     mov al,3
     iret
store24 dw 0,0

testini proc
    push si
    push ds
    mov ds,cs:seg_f
    mov si,cs:off_f
    cmp byte ptr [si+1],0
    jne  @@no_ok
    call prg
@@no_ok:
    pop ds
    pop si
    ret
endp testini


prg proc
    cmp cs:RUN_TSR,0
    je  $+3
    ret
    inc cs:RUN_TSR
    mov cs:_ss_,ss
    mov cs:_sp_,sp
    push    cs
    pop     ss
    mov     sp,offset SSseg
    push    bp
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    push    ds
    push    es
    cmp  cs:POP_KEY,0
    je   @@restore
;
; restore previous interrupts
;
    cli
    mov ds,cs:seg_f
    mov si,cs:off_f
    mov cx,cs:len_ff
    push cx
    mov di,offset SWP_DOS
    push cs
    pop es
    cld
    rep movsb
    sti
    mov ah,62h
    int 21h
    mov cs:PID,bx
    
    call locseg
    mov  ah,50h
    mov  bx,cs
    int  21h
    mov  ax,3524h
    int  21h
    mov  cs:[store24],bx
    mov  cs:[store24+2],es
    lea  dx,save24
    mov  ah,25h
    int  21h
    
    call read_ovl
    jc   @@err_ovl
    call main
    call restore_mem
@@err_ovl:

    mov  dx,cs:[store24]
    mov  ds,cs:[store24+2]
    mov  ax,2524h
    int  21h

    mov ah,50h
    mov bx,cs:PID
    int 21h
    cli
    mov es,cs:seg_f
    mov di,cs:off_f
    pop cx
    mov si,offset SWP_DOS
    push cs
    pop ds
    cld
    rep movsb
@@restore:
    mov cs:POP_KEY,0
    sti

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
    dec cs:RUN_TSR
    ret
prg endp

locseg proc
    push cs
    pop  es
    push cs
    pop  ds
    ret
endp locseg

read_ovl proc
    cmp  byte ptr cs:[ovl],0
    je   @@ok_read ; оверлей всегда загружен
    call save_mem
    jc   @@bad_read
    call locseg
    mov  dx,ovl
    mov ax,3d00h
    int 21h
    jc  @@bad_read
    mov bx,ax
    mov ax,4200h
    xor cx,cx
    mov dx,offset main - 100h
    int 21h
    jc  @@bad_read
    mov cx,offset start - offset main
    mov ah,3fh
    mov dx,offset main
    int 21h
    jc  @@bad_read
@@ok_read:
    clc		; нормально загружен оверлей 
@@bad_read:
    pushf
    mov ah,3eh
    int 21h
    popf
    ret    
endp read_ovl

swap_int proc
    push cs
    pop es
    lea di,oldint
    xor ax,ax
    mov si,ax
    mov ds,ax
    mov cx,512
    cli
@@ints:    
    lodsw
    xchg ax,es:[di]
    mov ds:[si-2],ax
    inc di
    inc di
    loop @@ints
    ret
endp swap_int 

save_mem proc
    call swap_int
    push cs
    pop ds
    mov si,ds:tmp_end
    mov byte ptr ds:[si],0
    mov ds:save_seg,0
    mov ah,48h
    mov bx, ( lenSWP / 16 ) + 2
    int 21h
    jc  use_tmp
    mov es,ax
    xor di,di
    lea si,main
    mov cx,lenSWP
    rep movsb
    mov cs:save_seg,es
    clc
    ret
use_tmp:    
    mov ah,5ah
    lea dx,tmp
    xor cx,cx
    int 21h
    jc  @@end_write
    mov bx,ax
    mov ah,40h
    lea dx,main
    mov cx,lenSWP
    int 21h
    jc  @@end_write
    mov ah,3eh
    int 21h
@@end_write:    
    ret
endp save_mem

restore_mem proc
    cmp  byte ptr cs:[ovl],0
    je   @@no_restore
    call swap_int
    call locseg
    cmp ds:save_seg,0
    jnz @@use_mem
    mov ax,3d00h
    lea dx,tmp
    int 21h
    mov bx,ax
    mov ah,3fh
    lea dx,main
    mov cx, lenSWP
    int 21h
    mov ah,3eh
    int 21h
    lea dx,tmp
    mov ah,41h
    int 21h
@@no_restore:    
    ret
@@use_mem:
    mov ds,cs:save_seg
    xor si,si
    lea di,main
    mov cx,lenSWP
    rep movsb
    push ds
    pop es
    mov ah,49h
    int 21h
    ret
endp restore_mem

main proc 
    putc '<'
    call locseg
    call getMODE
    jc graph
; текстовый режим
    call locseg
    call ClearKBD
    call open_window
    call locseg
    call open_base
    call interfase
    call locseg
    call close_window
    putc '>'
    ret
; графический режим
graph:
    ret
endp main

open_base proc
    mov dx,base_name
    mov ax,3d90h
    int 21h
    jc  @@no_open
    mov bx,ax
    mov dx,BUF
    mov cx,BEGINlen
    mov ah,3fh
    int 21h
    mov ah,3eh
    int 21h
@@no_open:
    ret
endp open_base

; Узнать текущий режим дисплея ( посредством BIOS )
; AL= видеорежим
; CF= 0 - текстовый, 1 - графический
getMODE proc near
    mov ah,0fh
    int 10h
    mov ds:Column,ah
    mov ds:Vpage,bh
    mov bx,ds:_windLeft
    cmp ah,40
    jne @@col
    mov bh,0
@@col:
    mov ds:windLeft,bx
    mov ds:Vseg,0b000h
    cmp al,7
    je  @@mode
    mov ds:Vseg,0b800h
    cmp al,4
    jb  @@mode
    stc
    ret
@@mode:    
    xor ax,ax
    push ds
    mov ds,ax
    mov ax,word ptr ds:[44eh]
    pop ds
    mov ds:Voff,ax
    clc
    ret
endp getMODE


get_offset proc
    push dx
    mov es,ds:Vseg
    mov al,bl
    mov dh,ds:Column
    add dh,dh
    mul dh
    mov di,ax
    mov al,bh
    add al,al
    xor ah,ah
    add di,ax
    add di,ds:Voff
    pop dx
    ret
endp get_offset

open_window proc
    push es
    mov bh,ds:Vpage
    mov ah,03h
    int 10h
    mov ds:cSIZE,cx
    mov ds:cPOS,dx
    call hiddenCursor

    mov al,ds:Column
    cbw
    sub ax,len_window
    add ax,ax
    mov ds:windSpace,al
    mov dh,al
    mov bx,ds:windLeft
    call get_offset
    mov dl,ds:attr_bkg
    lea bx,windBOX
    mov si,ARRAY
    mov cx,top_window
    mov bp,len_window
line_new:
    push cx
    mov cx,bp
next_column:
    mov ax,es:[di]
    mov ds:[si],ax  
    inc si
    inc si
    cmp  cx,1
    jne no_eol
    inc bx
no_eol:
    mov al,ds:[bx]
    mov ah,dl
    stosw
    cmp cx,bp
    jne no_bol
    inc bx
no_bol:
    loop next_column
    inc bx
    mov cl,dh
    add di,cx
    pop cx
    cmp cx,top_window
    je  no_ret_line
    cmp cx,2
    je  no_ret_line
    sub bx,3
no_ret_line:
    loop line_new
    pop es
    ret

endp open_window

close_window proc
    push es

    mov bx,ds:windLeft
    call get_offset
    mov dl,ds:windSpace
    xor dh,dh
    mov si,ARRAY
    mov es,ds:Vseg
    mov cx,top_window
    mov bp,len_window
next_line:
    mov bx,cx
    mov cx,bp
    rep movsw
    add di,dx
    mov cx,bx
    loop next_line

    mov dx,ds:cPOS
    mov bh,ds:Vpage
    mov ah,2
    int 10h
    mov cx,ds:cSIZE
    mov ah,1
    int 10h

    pop es
    ret
endp close_window

write_window proc
    push es
    mov bx,ds:windLeft
    inc bl
    inc bh
    call get_offset
    mov es,ds:Vseg
    mov si,bufTXT
    mov cx,top_window-2
    mov dl,ds:windSpace
    xor dh,dh
@@loop_write:
    push cx
    mov cx,len_window-2
@@line:
    lodsb
    call toCHAR
    stosw
    loop @@line    
    add di,dx
    add di,4
    pop cx
    loop @@loop_write
    pop es
    ret
endp write_window

ClearKBD proc
@@next_key:
    mov  ah,1
    int  16h
    jz   @@run
    mov	 ah,0
    int  16h
    jmp short @@next_key
@@run:
    ret
ClearKBD endp

toCHAR proc near
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
    ret
endp toCHAR
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
    mov	 al,ds:attr_titl
    mov  ds:attr_act,al
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
 call Write_window      ; и вывести текст в окно
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
 mov si,bufTXT
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
 mov si,bufTXT - 1
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
;  T0??????
;    ------ код символа
;  -        пpизнак конца слова ( наличие текста )
;  4б - указатель на след. букву этого уровня
;  4б - смещение текста в файле данных ( если Т установлен )


;
; пеpейти к следующей букве, пpопустив высшие уpовни
;
TonextChar proc
;
; SI := указатель на запись
;
 inc si
 lodsw
 mov dx,ax
 lodsw
 call updateBUF
 ret 
;
; SI - указатель на новую запись
;
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
; call ParseRecord
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
 cmp ax,BACK_KEY
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
   mov di,bufTXT
   mov cx,TXTlen
   rep movsb
   call write_window
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
;

outR	 db  0   ; значение ошибки при выходе за предел в списке выбора
numSEL	 db  0	 ; номер текущего выбора в списке
maxSEL	 db  0   ; число выборов
Voff     dw  0   ; текущая видеостраница
Vpage	 db  0   ;
Vseg     dw  0b800h   ; и сегмент
Column   db  0   ; число столбцов на экране
cPOS     dw  0   ; позиция и
cSIZE    dw  0   ; размер курсора

_windLeft dw 2005h ;
windLeft dw  0h    ; левый верхний угол окна
windSpace db  0       ; 
attr_bkg  db  30h     ; атрибут окна      00
attr_act  db  40h     ; атрибут выбора    01 
attr_sel  db  35h     ; атрибут выделения 10
attr_mark db  70h     ; атрибут курсора   11
attr_titl db  77h     ; атрибут заставки

windBOX   db  '╒═╕'
          db  '│ │'
          db  '╘═╛'
wordtoFind   db 30 dup('?')
numFirst  dw  0
posTXT    dw  0


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



start:
    mov ax,5d06h
    int 21h
    mov cs:seg_f,ds
    mov cs:off_f,si
    mov cs:len_ff,dx
    call locseg
    cmp dx,30h
    ja  bad_dos

    print   titl
    mov	  ah,30h
    int 21h
    xchg al,ah
    cmp  ax,330
    jb   bad_dos
    find ID,'_D',already
next_start:
    call command_line
    call set_ovl
    call set_tmp
    call locseg
    push bx
    ret
bad_dos:
    print error_dos_ver
    mov ax,4c01h
    int 21h

already:
    mov byte ptr more,'s'
    print exist
    mov si,offset keys+2
    mov ax,offset no_keys
    mov ds:[si],ax
    mov ds:[si+4],ax
    jmp short next_start

TSR_all:
    mov byte ptr cs:ovl,0
resident:
   call locseg
   setID
	intr    09h,save09,store09
        intr    28h,save28,store28
        intr    08h,save08,store08

    call    set_int
    call    locseg
    print   install
    cmp     byte ptr cs:[ovl],0
    jnz	    @@no_full
    mov     dx,topTSR
    int     27h
@@no_full:
    mov     dx,offset main
    int	    27h

help_text:
    print help_msg
    int  20h

no_keys:
    push cs
    pop  ds
    mov  ds:POP_KEY,offset key_list
    mov  ds:RUN_TSR,0
    mov  byte ptr ds:[ovl],0
    call set_int
    xor  ax,ax
    push ax
    jmp  prg

command_line:
    mov bx,offset no_keys
    mov si,80h
    lodsb
    or al,al 
    jz @@default
    cbw
    mov cx,ax
@@scan_cmd:
    lodsb
    cmp al,' '
    je  @@next_loop
    cmp al,'/'
    je  @@cmd
    cmp al,'-'
    je  @@cmd
    dec si
    jmp short @@get_base
@@next_loop:
    loop @@scan_cmd
    jmp short @@default
@@bad_key:
    mov bx,offset help_text ; неизвестный символ
    ret
@@cmd:
    lodsb
    mov di,offset keys
    push cx
    mov cl,3
@@scan_keys:
    cmp al,[di]
    je  @@ok_key
    cmp al,[di+1]
    je  @@ok_key
    add di,4
    loop  @@scan_keys
    pop cx
    jmp short @@bad_key
@@ok_key:
    mov bx,[di+2]
    pop cx
    dec cx
    dec cx
    jz  @@default
@@get_base:
    mov di,base_name
    cbw
@@get:
    lodsb
    cmp  al,' '
    jne  $+4
    loop @@get
    dec  si
@@beg_get:
    lodsb
    cmp al,' '
    je  @@end_base
    inc ah
    stosb
    loop @@beg_get
@@end_base:
    or ah,ah
    je @@default
@@ok_name:
    xor al,al
    stosb
    ret
@@default:
    mov  ax,cs:[2ch]
    mov ds,ax
    xor si,si
@@path:
    lodsw
    or ax,ax
    jz  $+5
    dec si
    jmp short @@path
    inc si
    inc si
@@name:
    push cs
    pop es
    mov di,base_name
    lodsb
    or al,al
    jz $+5
    stosb
    jmp short $-6
    push cs
    pop ds
    mov si,di
    std
@@del_n:
    lodsb
    cmp al,'\'
    jne @@del_n
    cld
    mov di,si
    inc di
    inc di
    lea si,default_name
    mov cx,10
    rep movsb
    ret
    
set_ovl proc
    push cs
    pop  es
    mov  ax,cs:[2ch]
    mov  ds,ax
    xor si,si
%%path:
    lodsw
    or ax,ax
    jz  $+5
    dec si
    jmp short %%path
    inc si
    inc si
    mov di,ovl
    cld
%%name:
    lodsb
    stosb
    or al,al
    jnz %%name
    ret
    
endp set_ovl

set_int proc
     push cs
     pop  es
     lea  di,oldint
     xor ax,ax
     mov ds,ax
     mov si,ax
     mov cx,512
     cli
     rep movsw
     sti
     ret
endp set_int

set_tmp proc
    push cs
    pop es
    mov ax,cs:[2ch]
    mov ds,ax
    lea di,mask_tmp
@@tmp1:    
    lodsw
    or ax,ax
    jz @@no_tmp
    dec si
    cmp al,cs:[di]
    jne @@tmp1
    inc di
    cmp di,offset mask_tmp + 6
    jne @@tmp1
    lea di,tmp
@@tmp2:
    lodsb
    stosb
    or al,al
    jnz @@tmp2
    cmp byte ptr es:[di-1],'\'
    je  @@no_tmp
    mov al,'\'
    stosb
    mov cs:tmp_end,di
@@no_tmp:
    ret 
endp set_tmp

DEFSETINT

mask_tmp db 0,'TMP='
titl    db  'Resident Dictionary by Dmitry Kokorev '
    	db  'SamPI (C) 1991.',0dh,0ah,24h
exist   db  'stay in memory :'
install db  'Press Shift-Space to call it',0ah,0dh
more    db  24h
        db  'econd copy start ...',0ah,0dh,24h
error_dos_ver db 'Invalid dos version',0ah,0dh
keys	db  'Ii'
	dw  offset resident
	db  'Rr'
	dw  offset TSR_all
	db  'Hh'
	dw  offset help_text
end_keys:
help_msg db  0ah,0dh,'usage: ReDIC [/|-key] [dictionary_file]',0ah,0dh
	 db  '/I stay resident small part',0ah,0dh
	 db  '/R stay resident full',0ah,0dh 
         db  '/H this screen',0ah,0dh,24h
default_name db '_ReD.lst',0

  end begin
