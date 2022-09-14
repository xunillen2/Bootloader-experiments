# FAT12 structure:
#
#	##########################################################################
#	#  Boot sector # Reserved sectors # FAT1 # FAT2 # Root dir # Data region #
#	##########################################################################
#
#	Boot sector - Contains BPB and our bootloader
#	Reserved sectors - Reserved sectors definied in BPB
#	FATs - 2kb to 32kb:
#		Contains info of clusters and their status in linked list type structure 
#		(aka. it contains entrys to def. what clusters are in use).
#		entry:
#			12 bit value:
#				0x000		- 		Free Cluster
#				0x001		- 		Reserved cluster
#				0x0002 - 0xFEF	-		Used cluster - next cl
#				0xFF0  - 0xFF6	-		Reserved values
#				0xFF7		-		Bad clusters
#				0xFF8  - 0xFFF	-		Last cluster in file
#	Root dir:
#		Contains entry for each file and directory stored in fs.
#		Each entry is 32byte value:
#			- 0-7byte	File name		- Important
#			- 8-10byte	File extension		- Important
#			- 11byte	File attributes
#				- 0b ReadOnly
#				- 1b Hidden
#				- 2b System
#				- 3b Volume label
#				- 4b Subdir
#				- 5b archive
#				.... 11th byte will not be used for now
#			- 12byte	Unused
#			- 13byte	Create time (ms)
#			- 14-15byte	Create time (intervals)
#			- 16-17byte	Created time (year)
#			- 18-19byte	Last access date
#			- 20-21byte	EA index
#			- 22-23byte	Last modified time
#			- 24-25byte	Last modified date
#			- 26-27byte	First cluster		- Important
#			- 28-32byte	File size		- Important
#		
.code16
temp_bpb:
                bytes_per_logsec:       .word   0x200   # Sector size (in bytes)
                reserved_logsec:        .word   0x1     # 0 - boot sector, need more info. temp 3
                fat_cnt:                .byte   0x2     # Number of allocation tables - FAT12 Always have 2
                root_dir_num:           .word   0xe0    # Maximum number of dirs. in root dir.
                logsec_per_fat:         .word   0x9     # bit 0 - 0 single sided, 1 double sided
                                                        # bit 1 (size) - 0 if 9 sectors per FAT, 1 if 8
                                                        # bit 3 (removable status) - 0 fixed, 1 removable
                                                        # bit 4, 5, 6, 7 unused
		sector_per_track:       .word   0x24
		total_logsec:           .word   0x1680
		bigsec_num:             .long   0x0
                head_num:               .word   0x2				

.globl	load_fat
# ABOUT:
#	Loads FAT table of drive specified in passed parameter.
# PARAMETERS:
#	1. Parameter 1 - Disk number	<-- 4(%bp) 
# REGISTERS:
#	%ax - contains start location of root dir
#	%cx - contains size of root dir
load_fat:
	xorw	%ax, %ax
	root_size_calc:	# Each entety in root dir is 32bit. (32 * root_dir_num) / 512(sector size) 
		movw	$0x20, %ax
		mulw	root_dir_num
		divw	bytes_per_logsec
		pushw	%ax
	root_start_calc: # (FAT_cnt * sector_per_fat + reserved_secotrs)
		xor	%ax, %ax	# clean ax
		movb	fat_cnt, %al
		mulw	logsec_per_fat
		addw	reserved_logsec, %ax
		popw	%cx
	read_root:
		pushw	$0x700
		pushw	%cx
		pushw	%ax

		call	read_sectors
	ret


.globl	read_sectors
# ABOUT
#	4(%bp) -> start sector
#	6(%bp) -> sectors to read
#	8(%bp) -> address
#
#
read_sectors:
	pushw	%bp
	movw	%sp, %bp	
read:
	cmpw	$0, 6(%bp)
	je	end_read
	calculate_lba:
		calculate_sector:
			# (start_sector % sector_per_track) + 1
			xor	%dx, %dx
			movw	4(%bp), %ax
			movw	sector_per_track, %cx
			divw	%cx
			incw	%dx
			store_sector:
				pushw	%dx
		calculate_track:
			xor	%dx, %dx
			movw	sector_per_track, %ax
			movw	$2, %bx
			mulw	%bx
			movw	%ax, %cx
			movw	4(%bp), %ax
			divw	%cx
			store_track:
				pushw	%ax
		calculate_head:
			xor	%dx, %dx
			movw	sector_per_track, %ax
			movw	$2, %bx
			mulw	%bx
			movw	%ax, %cx
			xorw	%dx, %dx
			movw	4(%bp), %ax
			divw	%cx
			movw	%dx, %ax
			xor	%dx, %dx
			movw	sector_per_track, %cx
			divw	%cx
			store_head:
				pushw	%ax

	xorw	%ax, %ax
	movw	%ax, %es
	movw	8(%bp), %bx

	movw	2(%esp), %ax	# Sector/Track
	movb	%al, %ch
	movw	4(%esp), %ax
	movb	%al, %cl
	movw	(%esp), %ax	# Head
	movb	%al, %dh

	movb	$2, %ah
	movb	$1, %al
	movb	$0, %dl

	int	$0x13
	addw	$6, %sp	# Clear stack

	decw	6(%bp)
	incw	4(%bp)
	addw	$0x200, 8(%bp)
	jmp	read
	end_read:
		movw	%bp, %sp
		popw	%bp
		ret
