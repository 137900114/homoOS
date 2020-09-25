.phony: compile link clear load
compile:
	@nasm -f elf -o kernel_lib.o kernel_lib.asm
	@gcc -m32 -c -o main.o main.c
	@nasm -f elf -o kernel.o kernel.asm

clear:
	@rm *.o

link:
	@ld -m elf_i386 -Ttext 0x1000 -o kernel.bin kernel.o kernel_lib.o main.o
	@make clear

load:
	@sudo mount -o loop ../empty.img ../../FloppyDisk
	@sudo cp kernel.bin ../../FloppyDisk
	@sudo umount ../../FloppyDisk