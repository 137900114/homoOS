%ifndef __rsectors.inc__
%define __rsectors.inc__


%ifndef BootProgramFile
    %include "fat12header.inc"
    [section .text]
%endif
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


;================================KILL MOTOR=================================
;kill the disk motor
KILL_DISK_MOTOR:
	push ax
	push dx

	mov dx,0x372
	mov al,0
	out dx,al

	pop dx
	pop ax
	ret
;===========================================================================


%endif