%ifndef __kmem.inc__
%define __kmem.inc__

;defines parameters discribes memory origanization in the system

;user memory offset,the user memory starts at 1Mb's memory space
UserMemoryAbusolute     equ 0x100000

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

;boot 

%endif
