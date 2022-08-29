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
#		Contains entry for eacs file and directory stored in fs.
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
