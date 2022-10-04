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

# Notes:
#	Use ds:si for print string, and move all to segmented addressing
#

.globl _start
.section .text

## Boot sector ##
_start:
	jmp main	# First 3 bytes
	nop
	
	oem_name:	.ascii "LinksOS "
	bpb:
		bytes_per_logsec:	.word	0x200	# Sector size (in bytes)
		logsec_per_cluster:	.byte	0x1	# Sectors per cluster
		reserved_logsec:	.word	0x1	# 0 - boot sector, need more info. temp 3
		fat_cnt:		.byte	0x2	# Number of allocation tables - FAT12 Always have 2
		root_dir_num:		.word	0xe0	# Maximum number of dirs. in root dir.
		total_logsec:		.word	0x1680	# Total number of sectors
		media_desc:		.byte	0xf0	# Type of media
		logsec_per_fat:		.word	0x9	# bit 0 - 0 single sided, 1 double sided 
							# bit 1 (size) - 0 if 9 sectors per FAT, 1 if 8
							# bit 3 (removable status) - 0 fixed, 1 removable
							# bit 4, 5, 6, 7 unused	
		sector_per_track:	.word	0x24	# 18 sectors per track for floppy
		head_num:		.word	0x2	# Two head per clynder for 1.44 3 and half floppys
		hidden_sec:		.long	0x0
		bigsec_num:		.long	0x0
		drive_num:		.byte	0x0	# Drive number
		bs:			.byte	0x0
		extbsignature:          .byte   0x29
		drive_serial_num:	.long	0x01af82913
		volume_label:		.ascii	"LYNX FLOPPY"
		fs:			.ascii	"FAT12   "

boot_vars:
	boot_drive:	.byte 0	# Boot drive number (dl)

main:
	setup_segments:
		cli			# Disable interupts
		movw	$0x600, %sp	# We will setup memory in second stage bootlaoder
					# This is temporary, we do not need much.
#		movw	$0x50, %ax
#		movw	%ax, %ss

		xor	%ax, %ax	# Set all segments to 0
		movw	%ax, %ds
		movw	%ax, %es

		sti			# Enable interupts

	movb	%dl, boot_drive	# Save value that represents the drive
				# we booted from

#	call	clear_screen       # Clear screen
	call	reset_disk         # Reset disk

#        pushw   $copyright	# Print CopyRight message
#        call    print_text

#	pushw	$welcome_text   # Print welcome message
#	call	print_text

	fat_init:
		call	load_fat
	load_second:
		pushw	$second_stage_name
		call    find_file
		pushw	$0x800
		pushw	%cx
		pushw	%ax
		call	read_file_linear				
#	jmp_second:
#		jmp	0x8000
#		pushw	$18
#		call	read_sectors
#		jc      error_reboot
#	call	load_second_bt     # Load second bootlaoder

	end:
		jmp end

######################
## SCREEN FUNCTIONS ##
######################
# INT 10 - 17th int vector
#	Interrupt handler that BIOS sets up. They provide video services ->
#	Video mode (0h), cursor position (02h), get cursor position (02h)...
#
# ABOUT:
#	Prints text from given address until null char is hit.
#       INT $0x10
#	PARAMETERS:
#		1. Parameter 1 - Address to data to print	<-- 4(%bp)
#       REGISTERS:
#		%ah - 0x0e - function code
#		%al - Caracter to output
#		%bh - Page number
#		%bl - Color
#		%ax - Printed characters
#       RETURNS:
#		Number of writen bytes in %ax
#       NOTES:
#
#print_text:
#        pushw   %bp
#        movw    %sp, %bp
#
#        movw    4(%bp), %di
#
#        xor     %ax, %ax        # Empty counter register
#                                # Used for counting chars.
#	movw	%ax, %es
#
#        print_loop:
#                movb    %es:(%di), %al
#                cmpb    $0, %al
#                je      print_end
#
#		movb    $0x0e,  %ah
#                movb    $0x00,  %bh
#                movb    $0x07,  %bl
#
#                int     $0x10
#
#		incw	%di
#                jmp     print_loop
#        print_end:
#		movw	4(%bp), %ax	# Get original address
#		subw	%ax, %di	# Sub final address from orig. address
#		movw	%di, %ax	# Move result to %ax for return value.
#                movw    %bp, %sp
#                popw    %bp
#                ret

#
# ABOUT:
#       Clears screen
#       INT $0x10
#       PARAMETERS:
#
#       REGISTERS:
#		%ah - 0x6 - Function code to scroll up
#				(0x7 for down)
#		%al - Lines to scroll (down or up) if 0 (clear),
#				then ch, cl, dh, dl are used
#		%bh - Background color -> high four bits are for background,
#				and for low are for foregorund
#				(see BIOS color attributes)
#		%ch - Upper row number
#		%cl - Left column number
#		%dh - Lower row number
#		%dl - Right column number
#
#       RETURNS:
#
#       NOTES:
#
#clear_screen:
#        pushw   %bp
#        movw    %sp, %bp

#        movb    $0x07, %ah
#        movb	$0x00, %al
#        movb    $0x07, %bh

#        xor	%cx, %cx
#        movb    $0x19, %dh
#        movb    $0x50, %dl

#        int     $0x10

#	movw	%bp, %sp
#	popw	%bp
#	ret

####################
## ATA OPERATIONS ##
####################
# INT 13 - 19th int vector
#		Fuctions that BIOS provides until driver is implemented.
#		This is only way to access disks without drivers
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

	xor	%ax, %ax		# For reseting disk system
	Movb	boot_drive, %dl		# Using 0x80 to use first disk
	int	$0x13

#	jc	error_reboot		# If carry flag is set, error occured
#	cmpb	$0x86,	%ah		# If %ah is set to 0x86 -> unsupported function
#	je	error_unsupported
#	cmpb	$0x80,	%ah		# If %ag is set to 0x80 -> Invalid function
#	je	error_unsupported

	movw	%bp, %sp
	popw	%bp
	ret

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
#error_unsupported:
#	pushw   $error_uns_text
#	call    print_text      # Print function error text
#	subw	$2, %sp
#error_reboot:
#	pushw	$error_text
#	call	print_text	# Print error text
#	subw	$2, %sp

#	xor	%ax, %ax	# ah - 0x00 and it 0x16 for reading keyboard scancode
#	int	$0x16		# Contines executing after any key on keyboard
#				# has been pressed
#
#	jmp	$0xffff, $0000	# Jumps to reset vector, and reboots pc
				# FFFF * 16 + 0 = FFFF0 ->
				#	1048560 - 16 bytes below 1mb
#welcome_text:
#        .ascii  "Welcome to LinksBoot!\n\rBooting...\n\0"
#copyright:
#	.ascii	"CopyRight Xunillen. GPL license.\n\r\0"
error_uns_text:
#	.ascii  "\n\n\rFunction not supported, or is invalid.\0"
	.ascii "F\0"
error_text:
#	.ascii	"\n\rBoot error... Press any key to reboot.\0"
	.ascii "E\0"
second_stage_name:
	.ascii "LINKSCNDBTT"
