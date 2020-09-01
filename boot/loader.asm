org 0x200

[section .text]
    jmp START
    nop
;section text end
;=========================================================
;variable definitions
[section .data]
LoaderMessage:    db "query system memory layout..."
FailToQueryMemoryLayout: db "ERROR:fail to query memory range descriptor,system halt"

MemoryQuerySuccess db "success to query the memory layout d mrd is readed!"
;the variable used by print string function 
;every time system print a string this variable will 
;increase 1
PrintStringRowNumber db 0
;section data end
;=========================================================

;========================================================
;macro defines in this system
%include "kmem.inc"

FontSetting equ 0x17
StackBase equ LoaderProgramOffset
;LoaderProgramSeg equ 0x9000
;LoaderProgramOffset equ 0x200

;KernelProgramSeg equ 0x7000
;========================================================

;load ReedSector function into the file
%include "rsectors.inc"

;===============print string===================
;print a string ,which the [es:bp] points to. the size of the string is specified
;by cx
[section .text]
PRINT_STRING:

    mov al, 1
    mov bh, 0
    mov bl, FontSetting 
    mov dh, byte [PrintStringRowNumber]
    mov dl, 0
    mov ah, 0x13
    int 0x10

    add dh, 1
    mov byte [PrintStringRowNumber],dh
    ret
;section text ends
;==============================================

;================main function==================
[section .text]
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
    mov cx, 29
    mov ax,ds
    mov es,ax
    mov bp,LoaderMessage
    call PRINT_STRING

    ;check for the system's memory layout 
    ;the memory range descriptor structure will be loaded to 
    ;[es : di] which is 0x9000:0x0 now
    mov ax,LoaderProgramSeg
    ;at the first call ebx is 0,then ebx will be a random value that system can
    ;use it to reference the next block recording the data until ebx reach the end
    ;then system will set ebx 0
    mov ebx,0            
    mov es,ax
    mov di,MemCheckDescriptorBuffer 

    _FIND_THE_NEXT_MEMORY_DESCRIPTOR:
        mov eax,0xe820      ;the function id is 0xe820
        mov ecx,20          ;at present we just pass 20 to ecx ,this argument is not important

        mov edx,0x534d4150  ;the word "SMAP"

        int 0x15;

        ;if the cf is 0,the query success
        ;otherwise the memory query fails,jump to print the failure inform
        jc  _QUERY_MEMORY_LAYOUT_FAIL

        mov eax,dword [MemoryDescriptorStructureNum]
        inc eax
        mov dword [MemoryDescriptorStructureNum],eax
        
        cmp ebx,0
        ;if ebx equals 0,which means that the descirptor reach the end
        jz  _QUERY_MEMORY_LAYOUT_SUCCESS
        ;otherwise, go to the next iteration
        add di,20;
        jmp _FIND_THE_NEXT_MEMORY_DESCRIPTOR
_QUERY_MEMORY_LAYOUT_FAIL:
    ;es = LoaderProgamSeg
    mov bp,FailToQueryMemoryLayout
    mov cx,55
    call PRINT_STRING

    jmp $
_QUERY_MEMORY_LAYOUT_SUCCESS:
    ;es = LoaderProgamseg
    mov bx,MemoryQuerySuccess
    add bx,35
    mov eax,dword [MemoryDescriptorStructureNum]
    add eax,48
    mov byte [bx],al

    mov bp,MemoryQuerySuccess
    mov cx,51

    call PRINT_STRING

    ;now the memory descriptor structure is stored in MemCheckDescriptorBuffer
    
    
    ;now trying to load kernel.bin file into memory
    ;initialize the disk
    xor ax,ax
    int 0x13

    

    jmp $
;section text ends
;===============main function==================

;=============memory information==============
[section .data]
;data information used in 16bit real mode
KernelProgramName  db "KERNEL  BIN"

MemoryDescriptorStructureNum dd 0
MemorySize                   dd 0
    
MemCheckDescriptorBuffer times 256 db 0
;section data ends
;===============================================