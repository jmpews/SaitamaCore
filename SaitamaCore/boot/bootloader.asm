%include "macros.inc"

core_base_address equ 0x00040000
core_start_sector equ 0x0000001

jmp short bootloader_start

; default reversed gdt items
default_gdt_descripters:
	SEGMENT_DESCRIPTER_RESERVED
	MAKE_4G_DATA_SEGMENT_DESCRIPTER_MACRO 0x0, 0xffffffff
	MAKE_4G_CODE_SEGMENT_DESCRIPTER_MACRO 0x0, 0xffffffff

bootloader_start:

mov ax, cs
mov ss, ax

; >>> set default gdt limit
mov word [default_gdt+0x7c00], 23
add dword [default_gdt+0x7c00+2], 0x7c00
; use the default segment descripters, no stack, only 1 r-x segment descripter, 1 -w- segment descripter
lgdt [default_gdt+0x7c00]

; >>> extend extra GDT's item
sgdt [default_gdt+0x7c00]
; >>> change 32-bit physical address of gdt with seg:seg-offset
mov dword eax, [default_gdt+0x7c00+2]
xor edx, edx
mov ebx, 16
div ebx
mov ds, eax
mov ebx, edx
; >>> set extra GDT position
xor edx, edx
mov word dx, [cs:default_gdt+0x7c00]
add dword ebx, edx
inc ebx
%if 0
; create stack segment descripter
; base: 0x7c00 limit: 0xffffe granularity: 4k size: 4k
mov dword [ebx+0x0], 0x7c00fffe
mov dword [ebx+0x04], 0x00cf9600
%else
; create stack segment descripter
; base: 0x7c00 limit: 0xfefff granularity: byte size: 4k
mov dword [ebx+0x0], 0x7c00efff
mov dword [ebx+0x04], 0x004f9600
%endif
; create protectd mode display buffer descripter
; base: 0xb8000 limit: 0x7fff granularity: byte size: 0x7fff
mov dword [ebx+0x8], 0x80007fff
mov dword [ebx+0xc], 0x0040920b
; >>> update the expanded GDT
mov word [cs:default_gdt+0x7c00], 8*5-1
lgdt [cs:default_gdt+0x7c00]

in al, 0x92
or al,10b 
out 0x92, al

cli

; >>> enter protected mode
mov eax, cr0
or eax, 1
mov cr0, eax

jmp dword 0x0010:flush+0x7c00	;use code segment selector

[bits 32]

flush:
	; >>> init register with segment-descripter
	mov eax, 0x0008	; set data segment selector
	mov ds, eax
	mov eax, 0x0018 ; set stack segment selector
	mov ss, eax
	xor esp, esp

	; >>> load kernel from 1st sector on the disk to the memory
	mov edi, core_base_address
	; call read_head_disk_0 function
	mov eax, core_start_sector
	mov ebx, ds
	mov ecx, edi
	call read_hard_disk_0

	; >>> load the rest kernel
	mov eax, [edi] ; get kernel size
	xor edx, edx
	mov ecx, 512
	div ecx
	or edx, edx
	jnz @1
	dec eax
@1:
		or eax, eax
		jz setup_kernel
	mov ecx, eax
	mov eax, core_start_sector
	inc eax
	add edi, 512
@2:
		push ecx
		mov ecx, edi
		mov ebx, ds
		call read_hard_disk_0
		inc eax
		add edi, 512
		pop ecx
		loop @2

; @edi: the kernel load address
setup_kernel:
	mov eax, core_base_address
	add eax, [eax+0x4] ; get core_init_address
	jmp eax


; ============= disk manage kit =============
; read 1 sector
; @eax : sector number
; @ebx: segment selector
; @ecx: segment offset
read_hard_disk_0:
	push edx

	mov ds, ebx
	mov ebx, ecx

	push eax
	; set read count of sector 
	mov dx, 0x1f2
	mov al, 1
	out dx, al
	pop eax

	inc dx ; 0x1f3
	out dx, al ; LBA 7~0

	inc dx
	shr eax, 8
	out dx, al ; LBA 15~8

	inc dx
	shr eax, 8
	out dx, al ; LBA 23~16

	inc dx ; 0x1f6
	shr eax, 8
	or al, 0xe0 ; use master disk,
	out dx, al ; LBA 27~24

	inc dx ; 0x1f7
	mov al, 0x20 ; read disk
	out dx, al

	mov dx, 0x1f7
.wait_of_ready:
		; mov dx, 0x1f7
		in al, dx
		and al, 0x88
		cmp al, 0x08
		jnz .wait_of_ready

	mov ecx, 256
	mov dx, 0x1f0

.read_to_buffer:
		in ax, dx
		mov word [ebx], ax
		add ebx, 2
		loop .read_to_buffer

	pop edx
	ret

; ============= disk manage kit end =============

default_gdt:
	dw 23
	dd default_gdt_descripters



times 510-($-$$)	db 0
					db 0x55, 0xaa
