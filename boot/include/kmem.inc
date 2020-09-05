%ifndef __kmem.inc__
%define __kmem.inc__

;defines parameters discribes memory origanization in the system

;the system under 32 bit protection memory offset
;below the 1MB memory is runs the loader and kernel program
PM32MemoryAbusolute     equ 0x100000

;the loader program starts at 0x90200
LoaderProgramSeg        equ 0x9000
LoaderProgramOffset     equ 0x200
LoaderProgramAbusolute  equ LoaderProgramSeg * 0x10

;the kernel program starts at 0x70000
;between the loader program base address and kernel base program address
;are all the memory that the kernel program can use
KernelProgramSeg        equ 0x7000
KernelProgramOffset     equ 0x0
KernelProgramAbusolute  equ KernelProgramSeg * 0x10
KernelProgramSize       equ LoaderProgramAbusolute - KernelProgramAbusolute

;memory layout for memory page table
;page directory table and page table starts at here
PageDirectoryBase       equ PM32MemoryAbusolute
PageDirectoryMaxSize    equ 0x1000;a entinity in the table is 4 bytes,then the total size is 4 * 1024 = 0x1000
;page table starts at here
PageTableBase           equ PageDirectoryBase + PageDirectoryMaxSize
PageTableMaxSize        equ PageDirectoryMaxSize * 0x400

PG_P                    equ 1;the page has property
PG_RW_R                 equ 0;the page can be readed
PG_RW_W                 equ 2;the page can be writed
PG_US_S                 equ 0;the page can only be used in system level
PG_US_U                 equ 4;the page can be used in user level

%endif
