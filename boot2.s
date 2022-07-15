.code16

.globl _start
.section .text

_start:
	loop_print:
	movb	$0x0e, %ah
	movb	$65, %al
	movb    $0x00,  %bh
	movb    $0x07,  %bl
	int     $0x10
	jmp loop_print
loop:
	jmp loop
