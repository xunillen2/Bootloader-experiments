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
#	Data region:
#		Contains data
#		Always starts with cluster 2.
#		Calcualtion: Root dir end + 1 log_sec
#
#	DRIVER NOTES:
#		This driver is unstable and not fully tested. This is only a prototype driver so
#		i can load second stage bootloader. Only tested with 2.88M floopy disk in qemu and
#		with USB 2.88M floppy emulation on real machine.
#  		Will rewrite it later.
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
		logsec_per_cluster:     .byte   0x1
global_fat_values:
		root_size:	.word	0x0	# Size of root dir
		root_end_mem:	.word	0x700	# End of root dir in memory
		fat_size:	.word	0x0	# Size of fat (total, fat*2)
		data_start:	.word	0x0	# Start address of data region on disk
.globl	load_fat
# ABOUT:
#	Loads FAT table of drive specified in passed parameter.
# PARAMETERS:
#	1. Parameter 1 - Disk number	<-- 4(%bp) 
# REGISTERS:
#	%ax - contains start location of root dir
#	%cx - contains size of root dir
# NOTE: This is a fucking mess. Move calculation for global driver variables from reading subfunctions.
#
load_fat:
	movw	%sp, %bp

	xorw	%bx, %bx
	root_size_calc:	# Each entety in root dir is 32bit. (32 * root_dir_num) / 512(sector size) 
		movw	$0x20, %ax
		mulw	root_dir_num
		addw	%ax, root_end_mem
		movw	%ax, root_size		# Populate root size and root end var
		divw	bytes_per_logsec
		pushw	%ax
	root_start_calc: # (FAT_cnt * sector_per_fat + reserved_secotrs) -> sector
		xorw	%ax, %ax	# clean ax
		movb	fat_cnt, %al
		mulw	logsec_per_fat
		pushw	%ax			# Calculatefat size
		mulw	bytes_per_logsec
		movw	%ax, fat_size
		popw	%ax
		addw	reserved_logsec, %ax
		popw	%cx
	read_root:
		pushw	$0x70
		pushw	%cx
		pushw	%ax
		call	read_sectors
		
		pushw	$second_stg_name
		call	find_file
	read_fat:
		xorw	%dx, %dx
		movw	root_end_mem, %ax	# Div location by 0x10 as we use segmented addressing
		movw	$0x10, %cx
		divw	%cx
		pushw	%ax
		pushw	logsec_per_fat
		pushw	reserved_logsec
		call	read_sectors
	read_data:
		xorw	%ax, %ax
		addw	bytes_per_logsec, %ax	# Calculate start of data region on disk (reserved + fat + root + bytes_per_logsec)
		addw	fat_size, %ax
		addw	root_size, %ax
		addw	bytes_per_logsec, %ax
		movw	%ax, data_start
	loop:
		jmp loop

	movw	%bp, %sp
	ret


# ABOUT:
#	Calculates CHS from given LBA value.
#	Calculations:
#		example values:
#			sector_per_tracks: 36
#
#		head:	(lba % (sector_per_track * 2)) / sector_per_track
#			Changes every 36 sector, example:	lba=8, head=0
#							  	lba=36, head=1
#								lba=72, head=0
#		track:	(lba / (sector_per_track * 2))
#			Increments every 72 sector. Why? Because we need to read tracks on all heads
#			before going to next track.
#		sector: (lba % sector_per_track + 1)
#			Goes to maxiumum of 35, then resets, as we read 36 sectors per track.	
#						example:
#								lba=35, sector=36
#								lba=36, sector=1
#								lba=37, sector=2
#	PARAMETERS:
#		1. Parameter 1 - LBA Value	-> 4(%bp)
#	REGISTERS:
#		NaN, Used only for calculation.
#	RETURNS:
#		%ch - Track
#		%cl - Sector
#		%dh - Head
#
calculate_lba:
	pushw	%bp
	movw	%sp, %bp
	subw	$2, %sp

	movw	sector_per_track, %ax
	movw	$2, %cx
	mulw	%cx
	movw	%ax, -2(%bp)	# Calculate (secto_per_track * 2) as we use
				# it in tow calculations
	head:
		xorw	%dx, %dx	# Clear reminder
		movw	-2(%bp), %cx
		movw	4(%bp), %ax
		divw	%cx		# (lba % (sector_per_track * 2))
		movw	%dx, %ax
		xor	%dx, %dx	# Clear reminder
		movw	sector_per_track, %cx
		divw	%cx		# (...) / sector_per_track
		pushw	%ax		# Save value
	track:
		xor	%dx, %dx
		movw	-2(%bp), %cx
		movw	4(%bp), %ax
		divw	%cx
		pushw	%ax
	sector:
		xor	%dx, %dx
		movw	4(%bp), %ax
		movw	sector_per_track, %cx
		divw	%cx
		incw	%dx
	end:
		# Move values to intended return registers
		movb	%dl, %cl
		popw	%ax	# Track
		movb	%al, %ch
		popw	%ax	# Head
		movb	%al, %dh
		movw	%bp, %sp
		popw	%bp
		ret


# ABOUT:
#	Reads sectors from disk from start sector to end sector (definied by sector to read),
#	and saves data from sectors to address 0x700
#	Values on stack are directly modified to save memory.
#       PARAMETERS:
#               1. Parameter 1 - Start sector		-> 4(%bp)
#		2. Parameter 2 - Sectors to read 	-> 6(%bp)
#		3. Parameter 3 - Store address		-> 8(%bp)
#       REGISTERS:
#               NaN, Used only for functions
#       RETURNS:
#		%ax - Sectors read - not implemented. Returns nothing
#	NOTE:
#		Parameter 3. is used for segmented addressing. Always pass address/16
read_sectors:
	pushw	%bp
	movw	%sp, %bp

	# Set segments to 0x700
	movw	8(%bp), %es
	xorw	%bx, %bx
	read:
		cmpw	$0, 6(%bp)
		je	end_read

		pushw	4(%bp)
		call	calculate_lba

		movb	$2, %ah
		movb	$1, %al
		movb	$0, %dl
		int	$0x13

		decw	6(%bp)
		incw	4(%bp)
		addw	$0x200, %bx	# Bug:	We are limited to 63kb read, as bx will overflow.
					#	Add check to move segment and reset bx to mitigate
					#	this problem
		jmp	read
		end_read:
			movw	%bp, %sp
			popw	%bp
			ret

# ABOUT:
#       Finds file name located in loaded root directory in memory location 0x700,
#	and returns its cluster location and size
#       PARAMETERS:
#               1. Parameter 1 - Pointer to file name
#       REGISTERS:
#               %bx - Points to string passed by parameter 1
#		%di - Dynamic pointer to bytes from 0-10 in root dir data loaded
#			in memory 0x700. Incremented by 20 every file.
#		%cx - Counter
#		%ah - Temp. register, and return register
#       RETURNS:
#		%ax - cluster location
#		%al - file size
#	NOTE:
#		FIX ME:		If file is not found funciton will continue reading outside root dir.
#				Not a big problem as we mostly give file name as parameter that exists 
#				in root dir.
#		FIX ME 2:	First cluster is fully returned in %ax, but file size is limited
#				to 16bit instead of 32bit, so max correct reported size is 63kb.
#				If file is bigger than that, size report should be considered bad.
#				Mitigation exists for reading file data, and that is to use cluster
#				information in FAT table.
#
find_file:
	pushw	%bp
	movw	%sp, %bp
	subw	$2, %sp
	movw	$0x6e0, -2(%bp)

	find:
		addw	$0x20, -2(%bp)
		movw	-2(%bp), %bx
		movw	4(%bp), %di
		movw	$11, %cx
	 	loop_chars:
			test	%cx, %cx
			jz	done
			movb	(%di), %al
			cmpb	%al, (%bx)
			jne	find
			incw	%di
			incw	%bx
			decw	%cx
			jmp	loop_chars
	done:
		movw	15(%bx), %ax
		movw	17(%bx), %cx
		movw	%bp, %sp
		popw	%bp
		ret	

# ABOUT:
#	Calcualte and read clusters from disk containing file data.
#	1. Calculates cluster:
#			Gets 12bit value from FAT table from cluster number given by parameter, 
#			performs bitwise operation and views result value for cluster meaning.
#			Calculates in loop by reading next 12bit value until 0xff8-0xfff is not hit.
#			If value is "Rand value" jump to that cluster and continue reading.
#
#			Cluster Meanings:
#			Value		Meaning
#			0x00 		Unused
#			0xff0-0xff6	Reserved cluster
#			0xff7		Bad cluster
#			0xff8-0xfff	Last cluster in file
#			Rand value	Number of the next cluster in the file
#					(As clusters of file data do not need to be linear)
#	2. Read file
#			Read number of sectors defined by logsec_per_cluster from data_start + cluster_address
#			cluster_number = (cluster_number - 2) * bytes_per_logsec
#			(-2 because entry 0 and 1 in FAT table are reserved and not used. ) 
#       PARAMETERS:
#               1. Parameter 1 - File start cluster
#		2. Parameter 2 - File size	# Not needed 
#		3. Parameter 3 - Mem. address where to save file data 
#       REGISTERS:
#               NaN, Used only for functions
#       RETURNS:
#               %ax - Number of cluster readed   
#       NOTE:
#               Parameter 3. is used for segmented addressing. Always pass address/16
#		Fat table start address on disk = reserved_logsec
read_file:
	pushw	%bp
	movw	%sp, %bp


	end_readf:
		movw	%bp, %sp
		popw	%bp
		ret

second_stg_name:
	.ascii "TSTFILE2TXT"
