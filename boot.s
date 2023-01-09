################ Memory map (Real Mode) ######################
## Name								Start		End		Size
## REAL MODE INTERRUPT TABLE(IVT)	0x00000000	0x000003FF	1 KiB - Unusable -------------------|
## BIOS DATA AREA (BDA)				0x00000400	0x000004FF	256 bytes - Unusable ---------------|
## CONVECTIONAL MEMORY				0x00000500	0x00007BFF	30 KiB	-------|		    		|
## OS BOOTSECTOR					0x00007C00	0x00007DFF	512 bytes -----|-- Usable memory----|--- Low Memory (640 KiB)
## CONVENTIONAL MEMORY				0x00007E00	0x0007FFFF	480 KiB  ------|		    		|
## EXTENDED BIOS DATA AREA			0x00080000	0x0009FFFF	128 KiB	- Used by EBDA -------------|
## VIDEO DISPLAY MEMORY				0x000A0000	0x000BFFFF	128 KiB - Hardware mapped ----------|
## VIDEO BIOS						0x000C0000	0x000C7FFF	32 KiB 	- Video BIOS ---------------|--- System reserved 384 Kib
## BIOS EXPANSIONS					0x000C8000	0x000EFFFF	160 KiB	- BIOS Expansions ----------|
## MOTHERBOARD BIOS					0x000F0000	0x000FFFFF	64 KiB	- Motherboard bios ---------|
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
		fat_cnt:			.byte	0x2	# Number of allocation tables - FAT12 Always have 2
		root_dir_num:		.word	0xe0	# Maximum number of dirs. in root dir.
		total_logsec:		.word	0x1680	# Total number of sectors
		media_desc:			.byte	0xf0	# Type of media
		logsec_per_fat:		.word	0x9	# bit 0 - 0 single sided, 1 double sided 
										# bit 1 (size) - 0 if 9 sectors per FAT, 1 if 8
										# bit 3 (removable status) - 0 fixed, 1 removable
										# bit 4, 5, 6, 7 unused	
		sector_per_track:	.word	0x24	# 18 sectors per track for floppy
		head_num:			.word	0x2	# Two head per clynder for 1.44 3 and half floppys
		hidden_sec:			.long	0x0
		bigsec_num:			.long	0x0
		drive_num:			.byte	0x0	# Drive number
		bs:					.byte	0x0
		extbsignature:		.byte   0x29
		drive_serial_num:	.long	0x01af82913
		volume_label:		.ascii	"LYNX FLOPPY"
		fs:					.ascii	"FAT12   "

boot_vars:
	boot_drive:	
		.byte 0	# Boot drive number (dl)
main:
	setup_segments:
		cli		# Disable interupts
		movw	$0xff00, %sp	# We will setup memory in second stage bootlaoder
								# This is temporary, we do not need much.
#		movw	$0x50, %ax
#		movw	%ax, %ss

		xor		%ax, %ax		# Set all segments to 0
		movw	%ax, %ds
		movw	%ax, %es

		sti						# Enable interupts

		movb	%dl, boot_drive	# Save value that represents the drive
								# we booted from

	call	reset_disk         # Reset disk

	fat_init:
		pushw	$0x7e0
		call	load_fat
	load_second:
		pushw	$second_stage_name
		call    find_file
		pushw	$0x100
		pushw	%cx
		pushw	%ax
		call	read_file_linear
		jmp		0x2000
	end:
		jmp		end

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

	xor		%ax, %ax		# For reseting disk system
	movb	boot_drive, %dl		# Using 0x80 to use first disk
	int		$0x13

	movw	%bp, %sp
	popw	%bp
	ret

second_stage_name:
	.ascii		"LINKSCNDBTT"
