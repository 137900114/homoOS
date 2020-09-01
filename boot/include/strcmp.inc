%ifndef _strcmp.inc__
%define _strcmp.inc__

%ifndef BootProgramFile
    [section .text]
%endif

;==================================CMP STRING==========================
;compare to string [ds:si] and [es:di] whose length is [cl]
;if the two string is the same set ax to be 1 else set a 0
    ;the regisiters in use cx,ax
COMPARE_STRING:

    _LOOP_GO_THROUGH_THE_STRING:
        cmp cl,0
        jz  _THE_STRING_IS_THE_SAME 

        ;if a charactor is not the same as the other string the two string must be different
        mov al,byte [si]
        mov ah,byte [es:di]
        cmp al,ah
        jnz _THE_STRING_IS_NOT_THE_SAME

        inc si
        inc di
        dec cl

        jmp _LOOP_GO_THROUGH_THE_STRING
    _THE_STRING_IS_NOT_THE_SAME:
        mov ax,0
        jmp _LOOP_END
    _THE_STRING_IS_THE_SAME:
        mov ax,1
    _LOOP_END:
    
    ret
    
;======================================================================

%endif