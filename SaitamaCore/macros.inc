%macro SEGMENT_DESCRIPTER_RESERVED 0
	dw 0, 0
	dw 0, 0
%endmacro

; https://en.wikipedia.org/wiki/Global_Descriptor_Table	
; base %1, limit %2
%macro MAKE_4G_CODE_SEGMENT_DESCRIPTER_MACRO 2
	dw (%2 & 0xFFFF)
	dw (%1 & 0xFFFF)
	dw ((%1 >> 16) & 0xFF) << 0 | (DESC_TYPE_CODE_RX) << 8 | 1b << 12 | 00b << 13 | 1b << 15 
	dw ((%2 >>16) & 0xF) << 0 | 0 << 4 | 1 << 6 | 1 << 7 | (%1 >> 24) << 8
%endmacro

; base %1, limit %2
%macro MAKE_4G_DATA_SEGMENT_DESCRIPTER_MACRO 2
	dw (%2 & 0xFFFF)
	dw (%1 & 0xFFFF)
	dw ((%1 >> 16) & 0xFF) << 0 | (DESC_TYPE_DATA_RW) << 8 | 1b << 12 | 00b << 13 | 1b << 15 
	dw ((%2 >>16) & 0xF) << 0 | 0 << 4 | 1 << 6 | 1 << 7 | (%1 >> 24) << 8
%endmacro

; ======= gdt descripter attributes ========

DESC_TYPE_CODE_RX equ 1010b
DESC_TYPE_CODE_X equ 1000b ; r-x
DESC_TYPE_DATA_RW equ 0010b ; rw-


