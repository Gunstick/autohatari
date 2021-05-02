#!/usr/bin/make -f
#


.s:
	vasmm68k_mot -Ftos -align -devpac -m68000 -showopt -monst -o $@.tos $< 
#	vasmm68k_mot -Ftos -align -devpac -m68000 -showopt -nosym -o $@.tos $< 
.o:
	vlink $<

