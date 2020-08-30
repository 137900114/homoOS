org 0x7c00

;====================Macro Defines===============
StackBase equ 0x7c00

LOADER_SEG equ 0x9000;the address the loader program will be loaded(0x90000)
LOADER_OFFSET equ 0x100
FontSetting equ 0x17
;================================================

;==============definition of the boot hdr of the FAT12 file system================
    jmp START
    nop

    BS_OEMName      db "--COAT--";boot sector data structure : manufactor name 8 bytes
    BPB_BPerSector  dw 0x200;How many bits of data in a sector
    BPB_SPerCluster db 1;How many sector in a cluster
    BPB_RSecNum     dw 1;Reserved sector number
    BPB_FATNum      db 2;number of FATs
    BPB_RootEntCnt  dw 0xe0;the maximum number of root directory enenity
    BPB_TotalSector dw 0xB40;the total sector number
    BPB_Media       db 0xF0;the number discribes disk's media
    BPB_SecPerFAT   dw 0x9;How many sectors in a FAT structure 
    BPB_SecPerTrac  dw 18;how many sectors on a track
    BPB_HeaderNum   dw 0x2;how many heads on a disk
    BPB_HideSec     dd 0x0;how many hidden sectors
    BPB_TotSec32    dd 0x0;if the total count of the FAT32 0
    BS_DriverNum13 db 0x0;the driver id which is required in the interrupt 13(driver I/O)
    BS_Reserved    db 0x0;a bit that is not used
    BS_BootSig     db 0x29;a signature sign out the boot
    BS_VolID       dd 0;the Volume id
    BS_VolLabel    db "Tinix0.01--";the Volume label 11 bytes
    BS_FileSysType db "FAT12";The file system type 8 bytes


    ;how many sectors a fat table have
    FATSize equ 9

    ;RootDirectorySectorsNum = (BPB_RootEntCnt * 32) / BPB_BPerSector = 14
    ;DataSectorOffset = 1(the boot program sector) + 2 * 9(2 FAT table sectors) + RootDirectorySectorsNum = 33
    DataSectorOffset equ 33

    RootDirectorySectorsNum equ 14
    RootDirectorySectorsOffset equ 19

    FatTableOffset equ 1
;=====================================================================================

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
	mov	bl,byte [BPB_SecPerTrac]	; bl: 除数
	div	bl			; y 在 al 中, z 在 ah 中
	inc	ah			; z ++
	mov	cl, ah			; cl <- 起始扇区号
	mov	dh, al			; dh <- y
	shr	al, 1			; y >> 1 (其实是 y/BPB_NumHeads, 这里BPB_NumHeads=2)
	mov	ch, al			; ch <- 柱面号
	and	dh, 1			; dh & 1 = 磁头号
	pop	bx			; 恢复 bx
	; 至此, "柱面号, 起始扇区, 磁头号" 全部得到 ^^^^^^^^^^^^^^^^^^^^^^^^
	mov	dl, byte [BS_DriverNum13]		; 驱动器号 (0 表示 A 盘)
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
    push ds
    pop es

    mov al, 1
    mov bh, 0
    mov bl, FontSetting 
    mov dh, 0
    mov dl, 0
    mov ah, 0x13
    int 0x10

    ret
;=====================================================================================


;===============================variables===========================================
LoaderFileName: db  "LOADER BIN ",0
iRDSectorLoop   dw  RootDirectorySectorsNum
iRDSectorID     dw  RootDirectorySectorsOffset

NoLoaderFoundStr: db "ERROR:no loader program was found in the disk,the system halt"
;===================================================================================


;=================================boot program =======================================
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

    ;initialize the disk
    xor ah,ah
    xor al,al
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

        jmp _SEARCH_FOR_LOADER_PROGRAM_LOOP_BEGIN


;=================================boot program=========================================

; fill the rest of the boot program with 0
times 510-($-$$)   db    0
; the boot program must be ended with 55 aa
dw  0xaa55 