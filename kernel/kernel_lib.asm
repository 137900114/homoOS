FontSetting equ 0x07
global homo_print
global clear_screen

[section .data]
ScreenPos: dd 0

;function that print a string in the screen
;c prototype: void homo_print(char* ds:str);
;print a string pointed from str to charactor '\0'
;parameter str is passed by eax
[section .code]
homo_print:
    push esi
    push edi

    mov esi,eax
    mov edi,[ScreenPos]
    
    .copy_string_data_to_graphic_memory:
        mov al,byte [esi]

        cmp al,0x0
        jz .stop_printing_the_string

        mov byte [gs:edi],al
        inc edi
        mov byte [gs:edi], FontSetting
        inc edi

        inc esi
    .stop_printing_the_string:


    pop esi
    pop edi

    ret

clear_screen:
    push eax
    push esi
    push ecx

    mov ecx,25 * 80 * 2
    mov esi,0
    mov eax,FontSetting * 0x100

    .clear_loop:
        cmp ecx,0
        jz .end_loop

        mov word [gs:esi],ax
        add esi,2

        dec ecx
        jmp .clear_loop
    .end_loop:    

    pop ecx
    pop esi
    pop eax

    ret
    