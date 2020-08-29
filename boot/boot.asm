org 0x7c00
FontSetting equ 0x17
StackBase equ 0x7c00

    jmp START
    nop

    BS_OEMName      db "--COAT--";boot sector data structure : manufactor name 8 bytes
    BPB_BPerSector  dw 0x200;How many bits of data in a sector
    BPB_SPerCluster db 1;How many sector in a cluster
    BPB_RSecNum     dw 1;Reserved sector number
    BPB_FATNum      db 2;number of FATs
    BPB_RootEntCnt  dw 0xe0;the maximum number of root directory enenity
    BPB_TotalSector dw 40936;the total sector number
    BPB_Media       db 0xF0;the number discribes disk's media
    BPB_SecPerFAT   dw 0x9;How many sectors in a FAT structure 
    BPB_SecPerTrac  dw 17;how many sectors on a track
    BPB_HeaderNum   dw 0x4;how many heads on a disk
    BPB_HideSec     dd 0x0;how many hidden sectors
    BPB_TotSec32    dd 0x0;if the total count of the FAT32 0
    BS_Interrupt13 db 0x0;the id of the interrupt 13
    BS_Reserved    db 0x0;a bit that is not used
    BS_BootSig     db 0x29;a signature sign out the boot
    BS_VolID       dd 0;the Volume id
    BS_VolLabel    db "Tinix0.01--";the Volume label 11 bytes
    BS_FileSysType db "FAT12---";The file system type 8 bytes


; db 定义一个字节  dw 字word  dd 定义一个双字double word
BootMessage:    db "Trying to boot the homo system......(actually there is nothing in it)"
BootMessageEnd:

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


    ; 打印字符串"Booting..."
    mov al, 1
    mov bh, 0
    mov bl, FontSetting 
    mov cx, BPB_BPerSector - BS_OEMName
    mov dh, 0
    mov dl, 0
    ; es = ds
    push ds
    pop es
    mov bp, BS_OEMName
    mov ah, 0x13
    int 0x10

    jmp $


; times n m        n：重复定义多少次   m:定义的数据
times 510-($-$$)   db    0
dw  0xaa55 