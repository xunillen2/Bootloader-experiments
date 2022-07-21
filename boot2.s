.code16

.globl _start
.section .text

_start:
	call	a20_status
	cmpw	$1, %ax
	je	print_enabled
	jmp	print_disabled
	print_enabled:
		movb	$0x0e, %ah
		movb	$65, %al
		movb    $0x00,  %bh
		movb    $0x07,  %bl
		int     $0x10
		jmp loop
#		pushw	$a20_line_enabled
#		call	print_text
#		subw	$4, %es
	print_disabled:
		movb	$0x0e, %ah
		movb	$66, %al
		movb    $0x00,  %bh
		movb    $0x07,  %bl
		int     $0x10
#		pushw   $a20_line_disabled
#                call    print_text
#               subw    $4, %es
loop:
	jmp loop


##############
## A20 LINE ##
##############
# ABOUT:
#	Tests if the A20 line is already enabled.
#	We can test that by:
#		1. Write byte 0xF0 to 0x600. ds:si
#               2. Write one byte in location that is
#                  bigger than 0xFFFFF (1048575) -> ex.
#                  0x00 to FFFF:610. It should wrap around
#                  if A20 line is not enabled, and write
#                  that valie to 0000:0600. es:di
#               3. If byte at 0000:0600 is 0x00, A20 line
#                  is not enabled
#               4. If byte at 0000:0600 is still 0xF0, then
#		   A20 is enabled
#       PARAMETERS:
#       REGISTERS:
#       RETURNS:
#               0 if A20 line is disabled
#		1 if A20 line is enabled
#       NOTES:
#
a20_status:
        pushw   %bp
        movw    %sp, %bp

	xor	%ax, %ax
	movw	%ax, %ds

	movw	$0x600, %si
	movw	$0xF0, %ds:(%si)

	not	%ax
	movw	%ax, %es
	movw	$0x610, %di
	movw	$0x00, %es:(%di)

        movw    $1, %ax
	movw	%ds:(%si), %cx
	cmpw	$0xF0, %cx
	je	end_a20_status
        xor     %ax, %ax

	end_a20_status:
                movw    %bp, %sp
                popw    %bp
		ret
activate_a20_line:
	



# Temp print function until i dont move it to seperate file.
print_text:
        pushw   %bp
        movw    %sp, %bp

        movw    4(%bp), %dx

        xor     %cx, %cx        # Empty counter register
                                # Used for counting chars.
        print_loop:
                movb    $0x0e,  %ah

                movb    (%edx, %ecx, 1), %al
                cmpb    $0, %al
                je      print_end

                movb    $0x00,  %bh
                movb    $0x07,  %bl

                int     $0x10

                incw    %cx
                jmp     print_loop
        print_end:
                movw    %cx, %ax
                movw    %bp, %sp
                popw    %bp
                ret

## ERROR SUBROUTINES ##
#
# ABOUT:
#       If error while calling bios function is 0x86 or 0x80
#       jmp to error_unsuported, which will print that function
#       is not supported, and will continue down to error_reboot.
#       If carry flag is set, jmp to error_reboot,
#       which will print message, and wait for user input (int 0x16, ah 0x00),
#       and it will then reboot the system.
#
error_unsupported:
        pushw   $error_text
        call    print_text      # Print function error text
        subw    $2, %sp
error_reboot:
        pushw   $error_text
        call    print_text      # Print error text
        subw    $2, %sp

        xor     %ax, %ax        # ah - 0x00 and it 0x16 for reading keyboard scancode
        int     $0x16           # Contines executing after any key on keyboard
                                # has been pressed

        jmp     $0xffff, $0000  # Jumps to reset vector, and reboots pc
                                # FFFF * 16 + 0 = FFFF0 ->
                                #       1048560 - 16 bytes below 1mb

#.section .data
#debug_msg:
	a20_line_enabled:
		.ascii	"A20 Line ENABLED\0"
	a20_line_disabled:
		.ascii	"A20 Line ENABLED\0"
	error_uns_text:
        	.ascii  "Function not supported, or is invalid.\0"
	error_text:
        	.ascii  "Boot error... Press any key to reboot.\0"

