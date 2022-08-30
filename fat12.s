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
.globl	load_fat
# ABOUT:
#	Loads FAT table of drive specified in passed parameter.
# PARAMETERS:
#	1. Parameter 1 - Disk number	<-- 4(%bp) 
# REGISTERS:
#	%es:%di - used for storing calculated values and other stuff
# MEMORY LOCATIONS:
#	We will load FAT and and it parameters in memory location 0x700 (and up).
#	This will be overwritten when we load GDT and IDT, but FAT driver 
#	and it's memory locations are not in use anymore. 
#	
#	0x700 - Root size
#
load_fat:
	xorw	%ax, %ax
	movw	%ax, %es
	movw	$0x700, %di
	root_size_calc:	# Each entety in root dir is 32bit. (32 * root_dir_num) / 512(sector size) 
		movw	$0x20, %ax
		mulw	root_dir_num
		divw	bytes_per_logsec
		movw	%ax, %es:(%di)	# Store root size (in sectors) in 0x700
		incw	%di		# Move %di for next value (root start location)
	root_start_calc: # FAT_cnt * sector_per_fat + reserved_secotrs
		movw	fat_cnt, %ax
		mulw	logsec_per_fat
		addw	reserved_logsec, %ax
		movw	%ax, %es:(%di)	# Store root size in 0x702
	read_root:
		movw	$0x700, %di	# Reset %di to start location
		movb	$0x02, %ah
#		movb	%es:(%di), %al
		movb	$0x0e, %al
		movb	$0x01, %ch	# temp
#		movb	%es:2(%di), %cl
		movb	$0x13,	%cl
		movb	$0, %dh		# temp
		movb	$0, %dl		# temp
		movw	$0x700, %bx
		int	$0x13
	ret

