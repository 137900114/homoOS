org 0x7c00

;====================Macro Defines===============
StackBase equ 0x7c00

LOADER_SEG equ 0x9000;the address the loader program will be loaded(0x90000)
LOADER_OFFSET equ 0x200
FontSetting equ 0x07
;================================================

;==============definition of the boot hdr of the FAT12 file system================
; ----------------------------------------------------------------------
; FAT12 磁盘的头,启动盘使用FAT12文件系统,FAT12比较简单,且可以为后边的文件系统学习打下基础
; ----------------------------------------------------------------------
    jmp short START
    nop

BS_OEMName  DB '--COAT--'   ; OEM String, 必须 8 个字节

BPB_BytsPerSec  DW 512      ; 每扇区字节数
BPB_SecPerClus  DB 1        ; 每簇多少扇区
BPB_RsvdSecCnt  DW 1        ; Boot 记录占用多少扇区
BPB_NumFATs DB 2            ; 共有多少 FAT 表
BPB_RootEntCnt  DW 224      ; 根目录文件数最大值
BPB_TotSec16    DW 2880     ; 逻辑扇区总数
BPB_Media   DB 0xF0         ; 媒体描述符
BPB_FATSz16 DW 9            ; 每FAT扇区数
BPB_SecPerTrk   DW 18       ; 每磁道扇区数
BPB_NumHeads    DW 2        ; 磁头数(面数)
BPB_HiddSec DD 0            ; 隐藏扇区数
BPB_TotSec32    DD 0        ; 如果 wTotalSectorCount 是 0 由这个值记录扇区数

BS_DrvNum   DB 0            ; 中断 13 的驱动器号
BS_Reserved1    DB 0        ; 未使用
BS_BootSig  DB 29h          ; 扩展引导标记 (29h)
BS_VolID    DD 0            ; 卷序列号
BS_VolLab   DB 'TianSuoHAO2'   ; 卷标, 必须 11 个字节
BS_FileSysType  DB 'FAT12   '   ; 文件系统类型, 必须 8个字节
;------------------------------------------------------------------------
; -------------------------------------------------------------------------
; 基于 FAT12 头的一些常量定义，如果头信息改变，下面的常量可能也要做相应改变
; -------------------------------------------------------------------------
; BPB_FATSz16
FATSz			equ	9

; 根目录占用空间:
; RootDirSectors = ((BPB_RootEntCnt*32)+(BPB_BytsPerSec–1))/BPB_BytsPerSec
; 但如果按照此公式代码过长，故定义此宏
RootDirSectors		equ	14

; Root Directory 的第一个扇区号	= BPB_RsvdSecCnt + (BPB_NumFATs; FATSz)
SectorNoOfRootDirectory	equ	19

; FAT1 的第一个扇区号	= BPB_RsvdSecCnt
SectorNoOfFAT1		equ	1

; DeltaSectorNo = BPB_RsvdSecCnt + (BPB_NumFATs; FATSz) - 2
; 文件的开始Sector号 = DirEntry中的开始Sector号 + 根目录占用Sector数目
;                      + DeltaSectorNo
DeltaSectorNo		equ	17

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
        ;currently we just print a string when we find the loader file
        ;how we know that the loader file's directory is loaded in [es:bx] 0x9000:0x200
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

;==========================Read Sector=======================================
;	从第 ax 个 Sector 开始, 将 cl 个 Sector 读入 es:bx 中
READ_SECTOR:
	; -----------------------------------------------------------------------
	; 怎样由扇区号求扇区在磁盘中的位置 (扇区号 -> 柱面号, 起始扇区, 磁头号)
	; -----------------------------------------------------------------------
	; 设扇区号为 x
	;                           ┌ 柱面号 = y >> 1
	;       x           ┌ 商 y ┤
	; -------------- => ┤      └ 磁头号 = y & 1
	;  每磁道扇区数       │
	;                   └ 余 z => 起始扇区号 = z + 1
	push	bp
	mov	bp, sp
	sub	esp, 2			; 辟出两个字节的堆栈区域保存要读的扇区数: byte [bp-2]

	mov	byte [bp-2], cl
	push	bx			; 保存 bx
	mov	bl,byte [BPB_SecPerTrk]	; bl: 除数
	div	bl			; y 在 al 中, z 在 ah 中
	inc	ah			; z ++
	mov	cl, ah			; cl <- 起始扇区号
	mov	dh, al			; dh <- y
	shr	al, 1			; y >> 1 (其实是 y/BPB_NumHeads, 这里BPB_NumHeads=2)
	mov	ch, al			; ch <- 柱面号
	and	dh, 1			; dh & 1 = 磁头号
	pop	bx			; 恢复 bx
	; 至此, "柱面号, 起始扇区, 磁头号" 全部得到 ^^^^^^^^^^^^^^^^^^^^^^^^
	mov	dl, byte [BS_DrvNum]		; 驱动器号 (0 表示 A 盘)
.GoOnReading:
	mov	ah, 2				; 读
	mov	al, byte [bp-2]		; 读 al 个扇区
	int	13h
	jc	.GoOnReading		; 如果读取错误 CF 会被置为 1, 这时就不停地读, 直到正确为止

	add	esp, 2
	pop	bp

	ret
;=======================Read Sector============================

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

;=================================LOAD FROM FAT12==================================
;load the [ax] th fat pointer data to [ax],this function only effects register ax
;before calling this function the fat table data should all be loaded to [es:bx]
LOAD_FROM_FAT12_TABLE:
    push bx
    push dx
    push cx

    ;caculate the offset
    mov cx,ax
    shr ax,1
    mov dx,3
    mul dx
    
    add bx,ax
    and cx,1
    add bx,cx

    ;get the 2 bytes contains the fat data
    mov ax, word [es:bx]
    
    cmp cx,1
    jz _ELSE_IF_THE_CX_EQUALS_1
    _IF_THE_CX_EQUALS_0:
        and ax,0x0fff
        jmp _END_IF
    _ELSE_IF_THE_CX_EQUALS_1:
        shr ax,4
    _END_IF:    

    pop cx
    pop dx
    pop bx

    ret
;================================================================================

; fill the rest of the boot program with 0
times 510-($-$$)   db    0
; the boot program must be ended with 55 aa
dw  0xaa55 