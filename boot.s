################ Memory map (Real Mode) ######################
## Nmae					Start		End		Size
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

movw    $0x7c0, %ax
movw    %ax, %ds


movw    $0x7e0, %ax
movw    %ax, %ss

movw    $0x2000, %sp

# call clear_screen

#.section .data
#       sample_text:
#               .ascii "Test\0"

_start:
        movw    $0x00,  %cx

        print_loop:
                movb    $0x0e,  %ah

                movb    sample_text(,%ecx,1), %al
                cmpb    $0, %al
                je      loop_end

                movb    $0x00,  %bh
                movb    $0x07,  %bl

                int     $0x10

                incw    %cx
                jmp     print_loop

        loop_end:
                jmp loop_end



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

        movw    %bp, %sp
        popw    %bp

        int     $0x10


sample_text:
        .ascii  "18 naked cowboys in the showers at Ram Ranch!\0"
