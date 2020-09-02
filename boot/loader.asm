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

KernelSizeOutOfLimitStr    : db "ERROR:the kernel program's size is out of the system's limitation(0x20000)"

Booting32ProtectModeStr    : db "trying to switch the system to 32 bit protect mode"

;the variable used by print string function 
;every time system print a string this variable will 
;increase 1
PrintStringRowNumber db 0


iRDSectorLoop   dw  RootDirSectors;14
iRDSectorID     dw  SectorNoOfRootDirectory;19
;section data end
;========================================================


;========================================================
;32bit cpu gdt definition 
;prepare for switch from 16bit realmode to 32bit protected mode
;gbt describes the priority of the memory segment in order to protect
;system from unexpected memory accessment 

%include "protect32.inc";import the helper definitions

[section .gdt]
GDT_DUMMY   : Descriptor         0,         0,                 0;dummy gdt table act help the system locate the table
GDT_CODE    : Descriptor         0,   0xfffff,DA_C   | DA_LIMIT_4K | DA_32
GDT_DATA    : Descriptor         0,   0xfffff,DA_DRW | DA_LIMIT_4K | DA_32
GDT_VIDEO   : Descriptor   0xb8000,   0xfffff,DA_DRW | DA_DPL3

GDT_PTR : dw $ - GDT_DUMMY - 1  ;range of the gdt table
          dd GDT_DUMMY + LoaderProgramAbusolute;the pointer point to the gdt table start

;selectors that help us select the target memory segment
SelectorCode  equ GDT_CODE - GDT_DUMMY
SelectorData  equ GDT_DATA - GDT_DUMMY
SelectorVideo equ GDT_VIDEO - GDT_DUMMY 
;========================================================

;========================================================
;macro defines in this system
%include "kmem.inc"

FontSetting equ 0x17

;in 32 bit mode we print green words
FontSetting32 equ 0x12
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
;16 bit function
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

    _SEARCH_FOR_LOADER_PROGRAM_LOOP_BEGIN :
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
    _NO_LOADER_FOUNED :
        ;print the error string 
        mov cx, 51
        mov bp, NoKernelFoundStr
        mov ax,ds
        mov es,ax
        call PRINT_STRING

        ;infinity loop,system halt
        jmp $

    _CHECK_LOADED_DATA :

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

        ;check the size of the kernel file
        ;if the kernel file's size is out of the boundary
        ;we print a error message and stop the system 
        add bx,0x1c
        mov eax, dword [es:bx];get the size
        cmp eax,KernelProgramSize

        jc _START_LOADING_KERNEL_PROGRAM;the file size check pass start loading process
        
        ;otherwise print a error string and stop the system
        mov ax,ds
        mov es,ax
        
        mov cx,74
        mov bp,KernelSizeOutOfLimitStr

        call PRINT_STRING

        jmp $

        _START_LOADING_KERNEL_PROGRAM :

        ;get the begining cluster id
        sub bx,2
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


            ;the kernel may be a big file if the it's bigger than 0x10000 bytes 
            ;the register bx may overflow,inorder to prevent that we will change the
            ;register es's value.

            ;this code is vaild only when the sector size is 512 bytes
            mov ax,0xffff
            sub ax,word [BPB_BytsPerSec]
            cmp bx,ax

            jc _GO_ON_LOADING_THE_FILE
                mov ax,es
                add ax,0x1000
                mov es,ax

            _GO_ON_LOADING_THE_FILE :

            ;the bx offset increases 512
            add bx, word [BPB_BytsPerSec]

            jmp _LOAD_LOADER_PROG
        _FAIL_TO_LOAD_LOADER_PROG:
            jmp $
        _FINISH_LOADINNG_LOADER_PROG:


    push ds
    pop es
    mov bp,LoadKernelSuccessfullyStr
    mov cx,50

    call PRINT_STRING

    call KILL_DISK_MOTOR

    ;start booting the 32bit protect mode
    mov bp,Booting32ProtectModeStr
    mov cx,50
    call PRINT_STRING

    lgdt [GDT_PTR];load gdt pointer

    cli ;close the bios interrupt

    ;enable A20h address bus so the cpu can access to memory higher than 0x100000 
    in  al,0x92
    or  al,0x2
    out 0x92,al

    ;enable 32 bit mode
    mov eax,cr0
    or  eax,0x1
    mov cr0,eax

    jmp SelectorCode : dword PROTECT32_MODE_CODE_START + LoaderProgramAbusolute

    jmp $
;section text ends
;===============main function=============================

;=========================================================
;32 bit code section 
;protect 32 main function
[section .code32]
[bits 32]
PROTECT32_MODE_CODE_START:
    ;now we enter the 32 bit protect mode
    ;initialize the segment registers
    mov eax,SelectorData
    mov ds,ax
    mov es,ax
    mov fs,ax
    mov ss,ax

    mov al,byte [PrintStringRowNumber + LoaderProgramAbusolute]
    inc al
    mov byte [PrintStringRowNumber + LoaderProgramAbusolute] ,al
    
    mov eax,StackBase32
    mov esp,eax

    mov ax,SelectorVideo
    mov gs,ax

    mov ebx,Boot32PMSuccessfullyStr
    mov ecx,41

    call PRINT_STRING32

    call CALCULATE_MEMORY_SIZE
    
    jmp $
;========================================================

;=======================================================
;print the string pointed by ebx,while ecx is the length of the string
PRINT_STRING32:
    push eax
    push edx

    ;in 32 protected mode we need to get absolute address of the data
    add ebx,LoaderProgramAbusolute

    mov eax,0
    mov al,byte [PrintStringRowNumber + LoaderProgramAbusolute]
    
    ;caculate the coordinate of the string
    mov dx,160
    mul dx


    _PRINT_STRING32_LOOP:
        cmp ecx,0
        jz  _PRINT_STRING32_LOOP_END

        mov dl,byte [ebx]
        mov byte [gs : eax],dl

        inc eax
        mov byte [gs : eax],FontSetting32
        inc eax
        
        inc ebx
        ;dec ecx
        ;jmp _PRINT_STRING32_LOOP
        loop _PRINT_STRING32_LOOP
    _PRINT_STRING32_LOOP_END:

    mov al,byte [PrintStringRowNumber + LoaderProgramAbusolute]
    inc al
    mov byte [PrintStringRowNumber + LoaderProgramAbusolute],al

    pop edx
    pop eax

    ret
    
;=======================================================


;=======================================================
;calculate the memory size in the system
;the result height 32 bits will be stored in ebx
;the size will be stored in eax
;this function should be compatible with c declaration
;so that c programs can call it 
[section .cdecl]
[bits 32]
CALCULATE_MEMORY_SIZE:
    ;the ebx - 4 stores the 
    push ebp
    mov ebp,esp
    
    sub esp,4

    push edi
    push ecx
    push ebx

    mov dword [ebp - 4],0
    mov edi,MemCheckDescriptorBuffer32
    mov ecx,dword [MemoryDescriptorStructureNum32]

    .WHILE_edi_nequal_0:
        cmp ecx,0
        jz  .Loop_End

        mov ebx,edi
        add ebx,16
        cmp dword [ebx],0x1
        jnz .end_if

        .if_the_memory_segment_can_be_used:
        sub ebx,16
        mov eax,dword [ebx]
        add ebx,8
        add eax,dword [ebx]

        cmp eax,dword [ebp - 4]
        jb .end_if
        mov dword [ebp - 4],eax
        .end_if:

        add edi,20
        loop .WHILE_edi_nequal_0
    .Loop_End:

    mov eax,[ebp - 4];the size of the memory will be stored and return by eax

    pop ebx
    pop ecx
    pop edi

    add esp,4
    pop ebp

    ret
;=======================================================


;=============32 bit mode data==========================
[section .data32]
;data information used in 16bit real mode
KernelFileName  db "KERNEL  BIN"

MemoryDescriptorStructureNum dd 0
MemoryDescriptorStructureNum32 equ MemoryDescriptorStructureNum + LoaderProgramAbusolute
MemorySize                   dd 0
MemorySize32 equ MemorySize + LoaderProgramAbusolute
    
MemCheckDescriptorBuffer times 256 db 0
MemCheckDescriptorBuffer32 equ MemCheckDescriptorBuffer + LoaderProgramAbusolute


Stack32DataBuffer : times 0x100 db 0
StackBase32 equ Stack32DataBuffer + 0x100 + LoaderProgramAbusolute;allocate a buffer in use of stack


Boot32PMSuccessfullyStr : db "the protect mode is booted successfully!"

;section data ends
;==========================================================