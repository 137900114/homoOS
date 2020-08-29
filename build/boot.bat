nasm ..\boot\boot.asm -o ..\bin\boot.bin

dd if=..\bin\boot.bin of=..\disk1.vhd bs=512 count=1 conv=notrunc