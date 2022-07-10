ENTRY(_start);
SECTIONS
{
	. = 0x7c00;
	.text : {
		*(.text)
	}
	.sig 0x7dfe : {
		SHORT(0xAA55)
	}
}
