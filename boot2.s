.code16

.globl _start
.section .text

_start:

	### A20 ###
	call	a20_status
	cmpw	$1, %ax
	je	print_enabled
	jmp	print_disabled
	print_enabled:
		pushw	$a20_line_enabled
		call	print_text
		jmp	next
	print_disabled:
		pushw   $a20_line_disabled
                call    print_text
		call	activate_a20	# Try, and enable A20 line
		call	a20_status	# Get A20 status
		cmpw	$1, %ax
		jne	a20_failed
		a20_success:
			pushw	$a20_line_enabled	# Print status text and continue
			call	print_text
			jmp	next
		a20_failed:
			pushw	$a20_line_failed	# If A20 line activation fails, print
			call	print_text		# message and reboot.
			call	error_reboot

next:
	load_gdt:
		lgdt	gdt
		pushw	$gdt_ok
		call	print_text
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
# ABOUT:
#	Activates A20 gate using multiple methods:
#		1. Using BIOS function.
#			1. Using INT 15 and %ax = 0x2403, check A20 gate support.
#			   If unsupported (%ax = 0x86 or cf set), then jump to 2.
#			   If supported get status, and activate A20 gate if needed.
#			   If function is unable to get A20 status, go to 2.
#		2. Using keyboard controller (Classical A20 way)
#			   1. Write command byte 0xD1 to IO port 0x64 (PS/2 controller).
#				Then write 0xDF to port 0x60 (output port),
#				which will enable A20 line
#				(0b11011111 - second bit sets A20 gate support
#				https://wiki.osdev.org/%228042%22_PS/2_Controller)
#
#			PS/2 Controller IO Ports - 0x60-0x64
#				IO Port	  Access type	Purpose
#				0x60	  Read/write	Data port
#				0x64	  Read		Status register
#				0x64	  Write		Command register
#			Command bytes we use here:
#				0xD1 - Write next byte to Controller Output Port,
#					write next byte to 0x60 PS/2 IO port
#					0xD1 and 0xD0 allow us to read and write to
#					PS/2 controller
#                       NOTE:   After every OUT (write) instruction check if buffer is empty.
#                               We do this by reading from 0x64 IO port (Status Register) and
#                               checking if bit 2 is set (0 = buffer is empty, 1 = buffer is full).
#                               Do this in loop until bit 1 is not 0. -> function check_buff
#		3. Use Fast A20 method. This is dangerous and not supported on every system (chip),
#		   As it can cause weird effects on system if not properly supported. Because of this
#		   we need to add code that checks if bit 1 is already set, and if we need to write
#		   0x92 port, as unnecessary writing to it may lead to later problems.
#		   Using this as last method to try and activate A20 line.
#			How: We write specific value to port 0x92 to control A20.
#				Bit 0 (rw) - fast reset
#				Bit 1 (rw) - Enable/disable (0/1) A20
#				Bit 3 (rw) - 0/1 Power on password bytes
#					(In CMOS 0x38-0x3f or 0x36-0x3f)
#				Bit 6-7 (rw) - Hard disk LED OFF (00), or ON (01,10,11)
#				Bit 2,4,5 var. meanings
#			NOTE:	Faster than Keyboard method.
#			ADDITIONAL DOCS:
#				https://www.win.tue.nl/~aeb/linux/kbd/A20.html
#       PARAMETERS:
#       REGISTERS:
#       RETURNS:
#               0 if A20 line is disabled
#               1 if A20 line is enabled
#       NOTES:
#
activate_a20:
        pushw   %bp
        movw    %sp, %bp

	bios_int15:
		# See if A20 line is supported
		# (QUERY A20 GATE SUPPORT)
		movw	$0x2403, %ax
		int	$15
		cmpb	$0, %ah
		jnz	keyboard_controller	# jmp. to second activation method
		jc	keyboard_controller

		movw	$0x2401, %ax		# Activate A20 gate
		int	$15
		cmpb	$0, %ah
		jnz	keyboard_controller
		jc	keyboard_controller

		# Check to see if A20 line is enabled
		call	a20_status
		testw	$0x01, %ax
		jnz	activate_end
		# Otherwise go to keyboard controller method
	keyboard_controller:
		xor	%ax, %ax	# Empty %al

		call	check_buff
		movb	$0xd1, %al	# Write command byte 0xD1 to IO port 0x64. (see above)
		outb	%al, $0x64

		call	check_buff
		movb	$0xdf,	%al	# Write second byte that sets bits to PS/2 controller (see above)
		outb	%al, $0x60
		call	check_buff

                # Check to see if A20 line is enabled
                call	a20_status
                testw	$0x01, %ax
                jnz	activate_end
		jmp	fast_a20
		# Go to fast A20 method
		check_buff:
			inb	$0x64, %al
			testb	$2, %al		# Bitwise AND, Checks if bit 2 is set.
						# If result is 0, ZF is set to 1, otherwise to 0.
			jnz	check_buff
			ret
	fast_a20:
		inb	$0x92, %al
		testb	$0x02, %al	# Read value from 0x92
		jnz	fast_a20_end	# And see if bit 2 is set
		orb	$0x02, %al	# If not, set bit 2, other bits, and write to 0x92.
		andb	$0xfe, %al
		outb	%al, $0x92
		fast_a20_end:
			# Check to see if A20 line is enabled
			call	a20_status	# Sets return value
	activate_end:
		movw	%bp, %sp
		popw	%bp
		ret

# ABOUT:
#	Disables A20 line.
#	This is debug function. It only uses bios int15 function to disable
#	A20 line. Use only for debug.
#       PARAMETERS:
#       REGISTERS:
#       RETURNS:
#       NOTES:
#		This function will be implemented properly if there will be need for it.
#
disable_a20:
	pushw	%ax

	# See if A20 line is supported
	# (QUERY A20 GATE SUPPORT)
	movw    $0x2403, %ax
	int     $15
	cmpb    $0, %ah
        jnz     error_unsupported
	jc	error_unsupported

        movw    $0x2400, %ax
        int	$15
        jc      error_reboot
        cmpb    $0x86, %ah
        je      error_unsupported

	popw	%ax
	ret

###############
## GDT TABLE ##
###############
# ABOUT: Sets up and loads GDT table
#	Global descriptor table contains list of selectors, that contain
#	Information with what memory locations can process access, with specific
#	premissions
#
#	Format of segment descriptor:
#
#	31#####################24#23####20#19#######16#15###############8#7#######################0
#	#			##	 ##	     ##			##			  #
#	#   Base Address(24-31) ## Flags ##   Limit  ##	  Access byte	##   Base Address (16-23) #
#	#			##	 ##	     ##			##			  #
#	###########################################################################################
#	#					     ##						  #
#	#		Base Address (0-15)	     ##		Segment Limit (0-15)		  #
#	#					     ##						  #
#	###########################################################################################
#
#	INFO:
#		0-15	Segment Limit	- Lower 4 bytes of the descriptors limit.
#		16-31	Base address	- Lower 4 bytes of the descriptors base address
#		32-39	Base address	- Middle 2 bytes of descritprors base address
#		40-47	Access byte	- Bit flags defining who has access to memory
#		48-51	Segment Limit	- Upper 4 bits of descriptors limit.
#		52-55	Flags		- Four flags used to define segment size
#		56-63	Base address	- Upper 2 bytes od descriptors base address
#
#		Segment Limit	- Definies maximum addresable unit
#		Base address	- Contains linear address where segment begins
#
#	Address 		Content
#	GDTR Offset + 0 	Null
#	GDTR Offset + 8 	Entry 1		- Code Descriptor
#	GDTR Offset + 16 	Entry 2		- Data Descriptor
#	....
#
#	Access Byte:
#		6	Present(Pr)		- Is selector present or not (1/0)
#		5	Privilege level(Priv)	- Set level(ring) of execution. 0-3
#		4	1
#		3	Excebutable(Ex)		- Is memory content executable
#		2	Direction(DC)		- Indicates if code can be executed from lower privelege level
#							(Code Segment)
#			Conforming(DC)		- Indicates if segment grows down(1) or up(0) (Data seg)
#		1	Readable(RW)		- Indicates if memory content can be read (1) (Code seg)
#			Writable(RW)		- Indicates if data can be writen to memory (1) (Data seg)
#		0	Accessed(Ac)		- If Segment is accessed, this will be set to 0
#
#	Flag:
#		3	Granularity(Gr)		- (0) Descriptor limit is specified in bytes.
#						  (1) Descriptor limit is specified in blocks (4KB - we can access 4GB)
#		2	Size(Sz)		- (0) 16bit protected mode, (1) 32bit protected mode
#		1,0	0 0
#
gdt:
	test:
		.ascii "test"
	null_descriptor:
		.zero	1
	code_descriptor:	# For cs segment
		.byte	0xff, 0xff	# Lower segment Limit (Limit to 4GB with 4KB blocks)
		.byte	0x00, 0x00	# 0 beacuse we want to start from 0 (Lower base)
		.byte	0x0		# Middle base
		.byte	0x9a		# Access byte ()
		.byte	0xc		# Flags (Gr, Sz)
		.byte	0xf		# Limit
		.byte	0x00		# Base
	data_descriptor:	# For ds, es, fs, gs, ss segments
		.byte	0xff, 0xff
		.byte	0x00, 0x00
		.byte	0x0
		.byte	0x92
		.byte	0xc
		.byte	0xf
		.byte	0x00
	test2:
		.ascii "test"

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

a20_line_enabled:
	.ascii	"\n\rA20 Line ENABLED\0"
a20_line_disabled:
	.ascii	"\n\rA20 Line DISABLED\0"
a20_line_failed:
	.ascii "\n\rA20 Line activation failed...\0"
a20_line_fast:
	.ascii "\n\rUsing FAST A20 method...\0"
gdt_ok:
	.ascii "\n\rGDT table OK\0"
error_uns_text:
       	.ascii  "\n\rFunction not supported, or is invalid.\0"
error_text:
       	.ascii  "\n\rBoot error... Press any key to reboot.\0"
