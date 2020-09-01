org 0x7c00

;====================Macro Defines===============
StackBase equ 0x7c00

LOADER_SEG equ 0x9000;the address the loader program will be loaded(0x90000)
LOADER_OFFSET equ 0x200
FontSetting equ 0x07

%define BootProgramFile
;================================================

;==============definition of the boot hdr of the FAT12 file system================

    jmp short START
    nop
%include "fat12header.inc"
;=====================================================================================


;=================================boot program =======================================
START:
    mov ax, cs
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov sp, StackBase

    ;initialize the disk
    xor ax,ax
    int 0x13

    ;read in 
    _SEARCH_FOR_LOADER_PROGRAM_LOOP_BEGIN:
        cmp word [iRDSectorLoop],0
        jz _NO_LOADER_FOUNED

        dec word [iRDSectorLoop]
        
        ;load the sector's data
        mov ax,LOADER_SEG
        mov es,ax

        mov ax,word [iRDSectorID]
        mov cl,1
        mov bx,LOADER_OFFSET

        call READ_SECTOR

        inc word [iRDSectorID]
        
        jmp _CHECK_LOADED_DATA
    _NO_LOADER_FOUNED:
        ;print the error string string 
        mov cx, 61
        mov bp, NoLoaderFoundStr
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
            mov di,bx;di = 0x200 + i * 32
            ;ds = 0x0000
            mov si,LoaderFileName;*si = LoaderFileName
            mov cl,11
            call COMPARE_STRING

            cmp ax,1
            jz  _THE_LOADER_FILE_IS_FOUNDED
            
            dec dx
            add bx,32;bx = 0x200 + i * 32

            jmp _LOOP_IN_A_SECTOR
        _LOOP_IN_A_SECTOR_END:

        
        jmp _SEARCH_FOR_LOADER_PROGRAM_LOOP_BEGIN

    _THE_LOADER_FILE_IS_FOUNDED:
        ;now we know that the loader file's directory is loaded in [es:bx] 0x9000:0x200
        ;currently the ds points to 0x0000

        ;get the begining cluster id
        add bx,0x1A
        mov ax,word [es:bx]
        push ax
        ;read from the first FAT table
        ;es = LOADER_SEG we load the fat table into the 0x8700:0x0000
        ;the loader program data will be loaded into the 0x9000:0x0200 later
        mov ax,LOADER_SEG - 0x300
        mov es,ax
        mov bx,0
        mov ax,1
        mov cl,18
        call READ_SECTOR

        mov bx,LOADER_OFFSET;0x7cbc
        _LOAD_LOADER_PROG:
            ;current stack contains [ax],ax is the current fat index
            ;read from the ax th cluster's sector
            mov ax,LOADER_SEG
            mov es,ax
            pop ax
            push ax
            ;I don't know why but we need to -2 to get the right sector index
            add ax,RootDirSectors + SectorNoOfRootDirectory - 2
            mov cl,1
            
            call READ_SECTOR

            mov ax,LOADER_SEG - 0x300
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
            ;currently we print a string
            ;mov cx,31
            ;mov bp,LoaderProgIsLoadedSuccessfully
            ;mov ax,ds
            ;mov es,ax
            ;call PRINT_STRING


            jmp LOADER_SEG : LOADER_OFFSET

;=================================boot program=========================================

;===============================variables===========================================
LoaderFileName: db  "LOADER  BIN",0
;LoaderFileIsFounded: db "the loader file is founded!"
iRDSectorLoop   dw  RootDirSectors;14
iRDSectorID     dw  SectorNoOfRootDirectory;19

NoLoaderFoundStr: db "ERROR:no loader program was found"
;LoaderProgIsLoadedSuccessfully db "loader file loaded successfully"
;===================================================================================


;=================================print string========================================
;print a string,the string lenght is [cx],while the [es:bp] point to the string
PRINT_STRING:
    ;push ds
    ;pop es

    mov al, 1
    mov bh, 0
    mov bl, FontSetting 
    mov dh, 0
    mov dl, 0
    mov ah, 0x13
    int 0x10

    ret
;=====================================================================================


;==================================CMP STRING==========================
;compare to string [ds:si] and [es:di] whose length is [cl]
;if the two string is the same set ax to be 1 else set a 0
;the regisiters in use cx,ax
%include "strcmp.inc"
;======================================================================

%include "rsectors.inc"

; fill the rest of the boot program with 0
times 510-($-$$)   db    0
; the boot program must be ended with 55 aa
dw  0xaa55 