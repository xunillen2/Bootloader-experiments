movw $0x7c0, %ax
movw %ax, %ds

loop:
        movb    $0x07, %ah      # Scroll down window
        movb    $0x00, %al      # Koliko linija da pomaknemo dolje. (0 za brisanje ekrana)
        movb    $0x07, %bh
        movw    $0x00, %cx      # Cursor - 0,0 position (row, colum up left)
                                # Specificiramo gornji lijevi dio ekrana
        movb    $0x18, %dh      # Lower right end of screen (14, 70)
        movb    $0x4f, %dl

        int     $0x10

        jmp loop

