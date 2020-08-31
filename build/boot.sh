nasm ../boot/boot.asm -o ../bin/boot.bin
dd if=../bin/boot.bin of=../empty.img bs=512 count=1 conv=notrunc
nasm ../boot/loader.asm -o ../bin/loader.bin
mount -o loop ../empty.img ../../FloppyDisk
dd if=../bin/loader.bin of=../../FloppyDisk/loader.bin bs=3x512 count=1 conv=notrunc
