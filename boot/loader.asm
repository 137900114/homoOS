org 0x200

[section .text]
    jmp START
    nop
;section text end
;========================================================
;variable definitions
%include "fat12header.inc"


[section .data]
LoaderStr                  : db "booting the system from loader program..."

QuerySystemMemoryLayoutStr : db "query system memory layout..."
FailToQueryMemoryLayoutStr : db "ERROR:fail to query memory range descriptor,system halt"

MemoryQuerySuccessStr      : db "success to query the memory layout d mrd is readed!"

NoKernelFoundStr           : db "ERROR:no kernel program file is founded in the disk"
LoadKernelSuccessfullyStr  : db "the kernel has been loaded to 0x70000 successfully"
StartLoadingKernelStr      : db "start loading kernel program"

;the variable used by print string function 
;every time system print a string this variable will 
;increase 1
PrintStringRowNumber db 0


iRDSectorLoop   dw  RootDirSectors;14
iRDSectorID     dw  SectorNoOfRootDirectory;19
;section data end
;========================================================

;========================================================
;macro defines in this system
%include "kmem.inc"

FontSetting equ 0x17
StackBase equ LoaderProgramOffset
;========================================================

;========================================================
; READ_SECTOR
; from the ax th Sector, read cl sectors into es:bx

; LOAD_FROM_FAT12_TABLE
; load the [ax] th fat pointer data to [ax],this function only effects register ax
; before calling this function the fat table data should all be loaded to [es:bx]

%include "rsectors.inc"
;========================================================

;========================CMP STRING======================
;COMPARE_STRING
;compare to string [ds:si] and [es:di] whose length is [cl]
;if the two string is the same set ax to be 1 else set a 0
%include "strcmp.inc"
;========================================================

;======================print string======================
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
;========================================================

;================main function===========================
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

    mov ax,ds
    mov es,ax
    mov cx,41
    mov bp,LoaderStr

    call PRINT_STRING

    ; print the string
    mov cx, 29
    mov bp,QuerySystemMemoryLayoutStr
    
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
    mov bp,FailToQueryMemoryLayoutStr
    mov cx,55
    call PRINT_STRING

    jmp $
_QUERY_MEMORY_LAYOUT_SUCCESS:
    ;es = LoaderProgamseg
    mov bx,MemoryQuerySuccessStr
    add bx,35
    mov eax,dword [MemoryDescriptorStructureNum]
    add eax,48
    mov byte [bx],al

    mov bp,MemoryQuerySuccessStr
    mov cx,51

    call PRINT_STRING

    ;now the memory descriptor structure is stored in MemCheckDescriptorBuffer
    
    
    ;now trying to load kernel.bin file into memory
    push ds
    pop es
    mov bp,StartLoadingKernelStr
    mov cx,28

    call PRINT_STRING

    ;initialize the disk
    xor ax,ax
    int 0x13

    _SEARCH_FOR_LOADER_PROGRAM_LOOP_BEGIN:
        cmp word [iRDSectorLoop],0
        jz _NO_LOADER_FOUNED

        dec word [iRDSectorLoop]
        
        ;load the sector's data
        mov ax,KernelProgramSeg
        mov es,ax

        mov ax,word [iRDSectorID]
        mov cl,1
        mov bx,KernelProgramOffset

        call READ_SECTOR

        inc word [iRDSectorID]
        
        jmp _CHECK_LOADED_DATA
    _NO_LOADER_FOUNED:
        ;print the error string 
        mov cx, 51
        mov bp, NoKernelFoundStr
        mov ax,ds
        mov es,ax
        call PRINT_STRING

        ;infinity loop,system halt
        jmp $

    _CHECK_LOADED_DATA:

        ;check for the loaded data
        ;currently the loaded data stored is at [es:bx] which is [0x9000:0x200]
        
        mov dx,16;the maximun directory number in a sector is 16
        _LOOP_IN_A_SECTOR:
            cmp dx,0
            jz  _LOOP_IN_A_SECTOR_END;if the search in this sector comes to the end
            
            ;es = 0x9000
            mov di,bx;di = 0x0 + i * 32
            ;ds = 0x0000
            mov si,KernelFileName;*si = KernelFileName
            mov cl,11
            call COMPARE_STRING

            cmp ax,1
            jz  _THE_LOADER_FILE_IS_FOUNDED
            
            dec dx
            add bx,32;bx = 0x0 + i * 32

            jmp _LOOP_IN_A_SECTOR
        _LOOP_IN_A_SECTOR_END:

        
        jmp _SEARCH_FOR_LOADER_PROGRAM_LOOP_BEGIN

    _THE_LOADER_FILE_IS_FOUNDED:

        ;get the begining cluster id
        add bx,0x1A
        mov ax,word [es:bx]
        push ax
        ;read from the first FAT table
        ;we will load the fat table into the 0x6d00:0x0000
        ;the loader program data will be loaded into the 0x7000:0x0 later
        mov ax,KernelProgramSeg - 0x300
        mov es,ax
        mov bx,0
        mov ax,1
        mov cl,18
        call READ_SECTOR

        mov bx,KernelProgramOffset
        _LOAD_LOADER_PROG:
            ;current stack contains [ax],ax is the current fat index
            ;read from the ax th cluster's sector
            mov ax,KernelProgramSeg
            mov es,ax
            pop ax
            push ax
            ;I don't know why but we need to -2 to get the right sector index
            add ax,RootDirSectors + SectorNoOfRootDirectory - 2
            mov cl,1
            
            call READ_SECTOR

            mov ax,KernelProgramSeg - 0x300
            mov es,ax
            ;currently stack contains [ax] ax contains the current fat index
            pop  ax
            push bx
            ;now the stack contains [bx] bx contains loader program offset
            mov bx,0
            ;load fat index data from the fat table
            ;the fat index data is stored in register ax now
            call LOAD_FROM_FAT12_TABLE

            cmp ax,0x0ff8
            jnc _FINISH_LOADINNG_LOADER_PROG
            cmp ax,0x0ff7
            jz  _FAIL_TO_LOAD_LOADER_PROG
            ;now the stack contains [bx] bx contains loader program offset
            pop bx
            push ax
            ;the bx offset increases 512
            add bx,0x200

            jmp _LOAD_LOADER_PROG
        _FAIL_TO_LOAD_LOADER_PROG:
            jmp $
        _FINISH_LOADINNG_LOADER_PROG:


    push ds
    pop es
    mov bp,LoadKernelSuccessfullyStr
    mov cx,50

    call PRINT_STRING

    jmp $
;section text ends
;===============main function=============================

;=============memory information==========================
[section .data]
;data information used in 16bit real mode
KernelFileName  db "KERNEL  BIN"

MemoryDescriptorStructureNum dd 0
MemorySize                   dd 0
    
MemCheckDescriptorBuffer times 256 db 0
;section data ends
;==========================================================