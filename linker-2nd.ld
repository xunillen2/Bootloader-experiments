ENTRY(_start);
SECTIONS
{	. = 0x1000;
	.data : {
		*(.data)
	}
	. = 0x2000;
	.text : {
		*(.text)
	}
}
