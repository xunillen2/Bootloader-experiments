ENTRY(_start);
SECTIONS
{
	. = 0x2000;
	.text : {
		*(.text)
	}
}
