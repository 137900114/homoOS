org 0x200

    jmp START
    nop

LoaderMessage:    db "Trying to boot the homo system from loader......(actually there is nothing in it)"
LoaderMessageEnd:

FontSetting equ 0x17
StackBase equ 0x200


START:
    mov ax, cs
    mov ds, ax
    mov ss, ax
    mov sp, StackBase

    ;clear the window
    mov ax,0x0600
    mov bh,FontSetting
    mov cx,0x0;(0,0)
    mov dx,0x184f;(25,80)

    int 0x10


    ; print the string
    mov al, 1
    mov bh, 0
    mov bl, FontSetting 
    mov cx, LoaderMessageEnd - LoaderMessage
    mov dh, 0
    mov dl, 0
    ; es = ds
    push ds
    pop es
    mov bp, LoaderMessage
    mov ah, 0x13
    int 0x10

    jmp $


    times 0x600 - ($ - $$) db 0xff