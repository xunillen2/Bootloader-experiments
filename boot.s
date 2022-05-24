movw $0x7c0, %ax
movw %ax, %ds

loop:
	movb	$0x07, %ah
	movb	$0x00, %al
	movb	$0x07, %bh
	movb	$0x00, %cl
	movb	$0x18, %dh
	movb	$0x4f, %dl
	int	$0x10

	jmp loop


