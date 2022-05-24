SECTIONS
{
	. = 0x7c00;
	.text :
	{
		*(.*)
		. = 0x1FE;
		SHORT(0xAA55)
	}
}
