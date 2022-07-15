################ Memory map (Real Mode) ######################
## Name					Start		End		Size
## REAL MODE INTERRUPT TABLE(IVT)	0x00000000	0x000003FF	1KiB - 	    Unusable ---------------|
## BIOS DATA AREA (BDA)			0x00000400	0x000004FF	256 bytes - Unusable ---------------|
## CONVECTIONAL MEMORY			0x00000500	0x00007BFF	30 KiB	-------|		    |
## OS BOOTSECTOR			0x00007C00	0x00007DFF	512 bytes -----|-- Usable memory----|--- Low Memory (640 KiB)
## CONVENTIONAL MEMORY			0x00007E00	0x0007FFFF	480 KiB  ------|		    |
## EXTENDED BIOS DATA AREA		0x00080000	0x0009FFFF	128 KiB	- Used by EBDA -------------|

## VIDEO DISPLAY MEMORY			0x000A0000	0x000BFFFF	128 KiB - Hardware mapped ----------|
## VIDEO BIOS				0x000C0000	0x000C7FFF	32 KiB 	- Video BIOS ---------------|--- System reserved 384 Kib
## BIOS EXPANSIONS			0x000C8000	0x000EFFFF	160 KiB	- BIOS Expansions ----------|
## MOTHERBOARD BIOS			0x000F0000	0x000FFFFF	64 KiB	- Motherboard bios ---------|
############################################################
.code16


.globl _start
.section .text

_start:
	jmp main

boot_vars:
	boot_drive:	.byte 0	# Boot drive number (dl)

main:
	# Setup segments
	movw    $0x7e0, %ax
	movw    %ax, %ss

	movw    $0x2000, %sp


	movb	%dl, boot_drive		# Save value that represents the drive
					# we booted from
	# Clear screen
	call clear_screen

	# Reset disk
	call reset_disk

	# Print message
	pushw	$welcome_text
	call print_text

	call load_second_bt
	jmp error_reboot
       loop_end:
		jmp loop_end

## SCREEN FUNCTIONS ##

print_text:
	pushw	%bp
	movw	%sp, %bp

	movw	4(%bp), %dx

	movb	$0x00, %ch
	movb	$0x00, %cl
	movw	$0, %cx
	print_loop:
	        movb    $0x0e,  %ah

                movb    (%edx,%ecx,1), %al
                cmpb    $0, %al
                je      print_end

                movb    $0x00,  %bh
                movb    $0x07,  %bl

                int     $0x10

                incw    %cx
                jmp     print_loop
	print_end:
		movw	%bp, %sp
		popw	%bp
		ret

clear_screen:
        pushw   %bp
        movw    %sp, %bp

        movb    $0x07, %ah      # Scroll down window
        movb    $0x00, %al      # Koliko linija da pomaknemo dolje. (0 za brisanje ekrana)
        movb    $0x07, %bh      # Light gray -> high four 0000 - black, low four 0111 - gray
        movw    $0x00, %cx      # Cursor - 0,0 position (row, colum up left)
                                # Specificiramo gornji lijevi dio ekrana

        movb    $0x18, %dh      # Specificiramo doljni dio ekrana (24, 70). Doljni red i desni kut
        movb    $0x4f, %dl

        int     $0x10

	movw	%bp, %sp
	popw	%bp
	ret

## ATA OPERATIONS ##
# INT 13
#
# ABOUT:
#	Resets disk so we can be ready to read second stage bootloader from FAT
#	INT $0x13
#	REGISTERS:
#		%ax - $0x00 -> Reset disk system
#		%dl - Specify which disk to use
#			(From disk table - 0x00 - 0x07h -> 1-128 floppy disk)
#			(From disk table - 0x80 - 0xff -> 1-128 hard disk)
#	RETURNS:
#		If carry flag is set -> error (Valid for all functions)
#		%ah - 0x86 -> unsupported function
#		%ah - 0x80 -> unvalid function
#	NOTES:
#		We dont always boot from first disk, change detection later
#
reset_disk:
	pushw	%bp
	movw	%sp, %bp

	movw	$0x00, %ax		# For reseting disk system
	movb	boot_drive, %dl		# Using 0x80 to use first disk
	int	$0x13

	jc	error_reboot		# If carry flag is set, error occured
	cmpb	$0x86,	%ah		# If %ah is set to 0x86 -> unsupported function
	je	error_unsupported
	cmpb	$0x80,	%ah		# If %ag is set to 0x80 -> Invalid function
	je	error_unsupported

	movw	%bp, %sp
	popw	%bp
	ret

load_second_bt:
	movb	$0x02, %ah
	movb	$0x01, %al
	movb	$0x00, %ch
	movb	$0x02, %cl
	movb	$0x00, %dh
	movb	boot_drive, %dl

	# Temp set registers
	xor	%bx, %bx
	mov	%bx, %es
	mov	$0x7e00, %bx
	int 	$0x13

	jc	error_reboot

	jmp	0x7e00

## ERROR SUBROUTINES ##
#
# ABOUT:
#	If error while calling bios function is 0x86 or 0x80
#	jmp to error_unsuported, which will print that function
#	is not supported, and will continue down to error_reboot.
#	If carry flag is set, jmp to error_reboot,
#	which will print message, and wait for user input (int 0x16, ah 0x00),
#	and it will then reboot the system.
#
error_unsupported:
	pushw   $error_text
	call    print_text      # Print function error text
	subw	$2, %sp
error_reboot:
	pushw	$error_text
	call	print_text	# Print error text
	subw	$2, %sp

	movw	$0x00,	%ax	# ah - 0x00 and it 0x16 for reading keyboard scancode
	int	$0x16		# Contines executing after any key on keyboard
				# has been pressed

	jmp	$0xffff, $0000	# Jumps to reset vector, and reboots pc
				# FFFF * 16 + 0 = FFFF0 ->
				#	1048560 - 16 bytes below 1mb

.section .data
welcome_text:
        .ascii  "Welcome to LinksBoot!\n\rBooting...\0"
error_uns_text:
	.ascii  "Function not supported, or is invalid.\0"
error_text:
	.ascii	"Boot error... Press any key to reboot."
