ENTRY(_start);
SECTIONS
{
	. = 0x7c00;
	.text : {
		*(.text)
	}
	.data : {
		*(.data)
	}
	.sig 0x7dfe : {
		SHORT(0xAA55)
	}
}
