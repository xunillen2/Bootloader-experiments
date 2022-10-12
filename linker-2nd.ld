ENTRY(_start);
SECTIONS
{
	. = 0x500;
	.text : {
		*(.text)
	}
}
