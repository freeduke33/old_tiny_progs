
PUBLIC INtext       ;  указатель на вх. текст
PUBLIC OUTtext      ;  указатель на архив
PUBLIC pack         ;  процедура кодирования
PUBLIC unpack       ;  процедура раскодирования
PUBLIC INsize       ;  длинна вх. текста
PUBLIC OUTsize      ;  длинна вых. текста
PUBLIC ARCbits      ;  число значимых бит в последнем байте архива

OUTsize = current
ARCbits = bits
INtext  = input
OUTtext = output

aseg segment
assume cs:aseg,ds:aseg,es:aseg

temp = temp1


pack proc far
   lds  di,cs:output
   mov  word ptr [di],0 ; ОЧИСТИТЬ НАЧАЛО АРХИВА
   mov  cs:erase,0
   call char       ; частота символов
   call main       ; постоение кода
   call puttable   ; запись таблиц в аpхив
   call src_arc    ; apхивиpование текста
 endp pack


unpack proc far
   mov cs:erase,0fffh
   call gettable
   call arc_src
 endp unpack

   mov  ax,cs:current
   mov  ax,4c00h
   int 21h


; подсчет частоты появления символов в буфере
; ds:si - буфер  cx - длинна буфера
; и запись частот в списке сумм

char proc near

   lds si,cs:input
   mov cx,cs:INsize
char_1:
   lodsb
   xor	ah,ah
   add  ax,ax
   mov	di,ax
   mov  ax,cs:[di+offset chars]  ; номер встреченного символа в списке сумм
   cmp	ax,0   
   jne	char_2      
   inc  cs:len_list     ; если 1 раз то
   mov  ax,cs:len_list
   mov  cs:[di+offset chars],ax
char_2:
   add  ax,ax
   mov  di,ax
   inc  word ptr cs:[di+offset list-2]
   loop char_1
   ret
endp char

main proc near
 mov ax,cs
 mov es,ax
 mov ds,ax
main_loop:
 cmp len_list,1
 jbe exit_main
 call min
 push bx
 stc
 call correct
 call compress
 call min
 push bx
 clc
 call correct
 call compress
 pop ax
 pop bx
 add ax,bx

;
; ax = summ  add to end

 lea si,list
 mov bx,len_list
 add si,bx
 add si,bx
 mov [si],ax
 inc len_list

  mov bx,len_list
  lea si,chars
  mov cx,256
  mov dx,-1
toend_loop:
  lodsw
  cmp ax,dx
  jne no_toend
  mov [si-2],bx
no_toend:
  loop toend_loop
 jmp short main_loop
exit_main:
 ret
main endp

;
; Найти символ с min суммой
;

min proc near
 mov cx,len_list
 lea si,list
 mov bx,7fffh
min_loop:
 lodsw
 cmp ax,bx
 ja  no_min
 mov bx,ax   ; min
 mov dx,cx   ; len_list - N min в списке
no_min:
 loop min_loop
 dec dx
 neg dx
 add dx,len_list
 ret
 endp min

;
;  dx= N to delete
;  убать элемент N  из списка сумм

compress proc near
  mov cx,len_list
  sub cx,dx
  jz no_compr
  lea si,list
  add si,dx
  add si,dx
compr_loop:
  lodsw
  mov [si-4],ax
  loop compr_loop
no_compr:
  dec len_list
  ret
 endp compress

;
; dx= N to correct
; все ссылки на элемент N заменить в chars на -1
; все большие N  сместить к началу
; добавить CF к использованным в сумме кодам

correct proc near
  pushf
  mov cx,256
  mov bx,-1
  lea si,chars
  lea di,codes
corr_loop:
  lodsw
  cmp ax,dx
  jne no_corr
  mov [si-2],bx
  popf
  pushf
  rcl word ptr cs:[di],1
  inc byte ptr cs:[di+2]
no_corr:
  cmp ax,dx
  jna corr_next
  cmp ax,-1
  je  corr_next
  dec ax
  mov cs:[si-2],ax
corr_next:
  add  di,3
  loop corr_loop
  popf
  ret
 endp correct



src_arc proc near
  lds si,cs:input	; исходный текст
  mov cx,cs:INsize      ; длинна текста
  mov bp,offset codes   ; начало списка кодов
  mov dx,cs
  mov es,dx
  push si
arc_loop:
; для каждого байта исходного текста
  pop si
  lodsb
  push si
  push cx
; найти соответствующий код
  mov bl,3             ; длинна записи с кодом ( 2б - код, 1б - длинна )
  mul bl
  add ax,bp
  mov si,ax
; и переписать его во временную область
  mov ax,cs:[si]
  mov cs:temp,ax
  mov bh,cs:[si+2]
; добавить код к концу архива
  call add_code
  pop cx
; перейти к след. букве
  loop arc_loop
  pop si
  ret
 endp src_arc

;
; добавить код к концу архива
; BH = длинна кода
; 
add_code proc near
  push si
  push es
  push ds

  push cs
  pop ds
  les di,ds:output   ; архив
  mov bl,cs:bits  ; число занятых бит в последнем байте архива
  mov cl,bl
  cmp cl,0
  je  no_shift
  xor ch,ch
; сместить код на число занятых бит
shift:
  clc
  rcl word ptr ds:temp1,1
  rcl byte ptr ds:temp2,1
  loop shift
no_shift:
  add di,ds:current
  mov si,offset temp
; дописать недостающие биты в последнее слово
  lodsw
  or ax,es:[di]
  stosw
; и добавить остальное в конец архива
  movsw
  call modify_var_end

  pop  ds
  pop  es
  pop  si
  ret
  endp add_code

; скорректировать число бит в последнем байте
; bh - длинна нового кода
; bl = bits

modify_var_end proc near
  mov al,bl
  add al,bh
  mov cs:bits,al 
  and cs:bits,0111b ; 0 .. 7
; и число байт в архиве
  mov cl,3
  and al,11111000b  ; число байт
  ror al,cl
  xor ah,ah
  add cs:current,ax
  mov ax,cs:erase
  and cs:temp1,ax
  and cs:temp2,al
  ret
 endp modify_var_end
;
; дописать к аpхиву таблицу кодиpования
;
puttable proc near
  mov ax,cs
  mov es,ax
  mov ds,ax
  mov si,offset codes
  mov cx,256
put_loop:
  push cx
; для каждого символа
  mov bl,[si+2]  ; длинна кода
; дописать в архив ( 4 бита - длинна кода)
  mov byte ptr cs:[temp1],bl   
  mov bh,4
  push bx
  call add_code
  pop  bx
; и сам код
  mov di,offset temp
  movsw
  mov bh,bl
  call add_code
  inc si
  pop cx
  loop put_loop
  ret
 endp puttable


; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

; выделить код из архива 
; bh = длинна кода
; DS = arc
; es = work

getcode proc near
  push si
  push di
  mov si,word ptr cs:input
; прочитать след. код во временную область
  add si,cs:current
  mov di,offset temp
  movsw
  movsb
; вернуть его к границе байта
  mov bl,cs:bits
  mov cl,bl
  xor ch,ch
  cmp cl,0
  je  no_unshift
 unshift:
  clc
  rcr  byte ptr cs:temp2,1
  rcr  word ptr cs:temp1,1
  loop unshift
no_unshift:
; отделить код от следующего
  mov cl,bh
  mov ax,0ffffh
  shl ax,cl
  not ax
  and cs:temp,ax
  call modify_var_end
  pop di
  pop si
  ret
 endp getcode


testcode proc near
 push ds
 push cs
 pop  ds
 mov cx,256
 mov si,offset codes
 loop_test:
 lodsw 
 mov bx,ax
 lodsb
 cmp al,0
 jz  test_next
 push cx
 mov cl,al
 mov dl,al
 mov ax,0ffffh
 shl ax,cl
 not ax
 and ax,cs:temp
 pop cx
 cmp ax,bx
 je  exit_test
test_next:
 loop loop_test
 clc
exit_test:
 pushf
 mov bh,dl
 mov bl,cs:bits
 mov dx,cx
 call modify_var_end
 popf
 pop ds
 ret
 endp testcode

gettable proc near
 mov cx,256
 lds si,cs:input
 push cs
 pop  es
 mov di,offset codes
 get_loop:
  push cx
; прочитать длинну кода
 mov bh,4
 call getcode
 mov bh,byte ptr cs:[temp]
; и сам код 
 call getcode
 mov ax,cs:temp
; и записать в codes
 stosw
 mov al,bh
 stosb
 pop cx
 loop get_loop
 ret
 endp gettable

arc_src proc near
 mov cx,INsize
 les di,cs:output
 lds ax,cs:input
 push cs
 pop  bp

src_loop:
 push cx
 mov bh,16
 push word ptr cs:bits
 push cs:current
 push es
 mov  es,bp
 call getcode
 pop  es
 pop  cs:current
 pop  word ptr cs:bits
 call testcode
 jne  err_arc
 dec dx
 neg dx
 add dx,255
 mov al,dl
 stosb
 pop cx
 loop src_loop
 ret
err_arc:
 pop cx
 ret
endp arc_src

; &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
; &%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%&
; &%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%&
; &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&


len_list dw 0            ; длинна списка сумм
list dw 256 dup(0)       ; список сумм ( частота появления символов )
chars dw 256 dup(0)      ; номер частоты символа в списке сумм
codes db 256 dup(0)      ; длинна кода 1б
      dw 256 dup(0)      ; формируемый код 2б

; область побитовой пеpесылки
temp1 dw 0
temp2 db 0,0

INsize  dw 0		 ; длинна вх.области
input   dd 0:0       	 ; указатель на вх. область
output  dd 0:0		 ; указатель на вых. область

current	dw 0		 ; тек. смещение в байтах в аpхиве
bits    db 0		 ; число занятых бит в последнем байте
erase   dw 0		 ; если 0 - очищать temp в процедуре modify_var_end
 ends aseg
 end 
