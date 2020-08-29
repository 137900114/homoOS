org 0x7c00

LOADER_SEG 0x90000;the address the loader program will be loaded
LOADER_OFFSET 0x100

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


    ;how many sectors a fat table have
    FATSize equ 9

    ;RootDirectorySectorsNum = (BPB_RootEntCnt * 32) / BPB_BPerSector = 14
    ;DataSectorOffset = 1(the boot program sector) + 2 * 9(2 FAT table sectors) + RootDirectorySectorsNum = 33
    DataSectorOffset equ 33

    RootDirectorySectorsNum equ 14
    RootDirectorySectorsOffset equ 19

    FatTableOffset equ 1
;=====================================================================================


;=================================boot program =======================================
START:
    
;=================================boot program=========================================

; fill the rest of the boot program with 0
times 510-($-$$)   db    0
; the boot program must be ended with 55 aa
dw  0xaa55 