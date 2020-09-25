global _start
extern cmain
extern clear_screen


[section .stack]
StackBase: times 128 db 0xff
StackTop:



[section .text]
_start:
    mov ax,ds
    mov es,ax
    mov fs,ax
    mov ss,ax
    mov eax,StackBase
    mov esp,eax

    call clear_screen

    jmp cmain

    jmp $


