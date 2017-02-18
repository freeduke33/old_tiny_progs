.model large
.code
public _RtoI   ; п/программа преобразования 
; CL    код возврата
;  0    без ошибок
;  1    слишком большое
;  2    меньше 1
;  3    меньше 0

public _input  ; исходное число 8 байт ( float   )
public _output ; результат 4 байта     (long int )
saaa segment
assume cs:saaa,ds:saaa,es:saaa
_RtoI proc far
     push ds
     push cs
     pop ds
     mov ax,input4

     mov cl,3       ;
     cmp ax,8000h   ; если <0  
     jae exit       ;

     and ax,7ff0h  ; выделяем степень
; сместить вправо на 4
     mov cl,4
     sar ax,cl
; привести к норм. степени
     sub ax,1022
     mov cl,2       ;
     cmp ax,0       ;  если дробное или 0
     jbe exit       ;

     dec cl         ;
     cmp ax,32      ;  если > 4 байт
     ja  exit       ;
     mov log,al ; и записать 
     mov  ax,input4
; выделить  ст байт числа
     and  ax,0fh
     or   al,10h  ; и дописать  ст 1 разряд
     mov input4,ax
     mov  cx,21      ; 5 + 16
; сместить все биты из результата назад
loop1:
     clc
     rcr  input4,1
     rcr  input3,1
     rcr  input2,1
     rcr  _input,1
     loop loop1
; выдвинуть только значащие
     mov  al,log
     mov  cl,al
     xor  ax,ax
loop2:
     clc
     rcl _input,1
     rcl input2,1
     rcl input3,1
     rcl input4,1
     loop loop2
exit:
     mov cl,0
     pop ds
     ret
endp _RtoI
log  db 0         ; степень числа
_input dw 0       ; 8 байт - исходное float число
input2 dw 0
_output = input3  ; 4 байта - int число
input3 dw 0
input4 dw 0
 ends saaa
end 