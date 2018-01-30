core_base_address equ 0x0004000
core_start_sector equ 0x0000001

mov ax, cs
mov ss, ax
mov sp, 0x7c00

; 在实模式下, 将32位线性物理地址改为 <段:段偏移> 寻址方式
mov eax, [cs:pgdt+0x7c00+0x2]
xor edx, edx
mov ebx, 16
div ebx
mov ds, eax
mov ebx, edx

; create 0# descripter
mov dword [ebx+0x00], 0x00000000
mov dword [ebx+0x04], 0x00000000  

; create 1#, data segment, map to 0~4GB  linear address space
mov dword [ebx+0x08], 0x0000ffff
mov dword [ebx+0x0c], 0x00cf9200
mov dword [ebx+0x0c], 0000_1101_1111_1001_0010_00000000b

; create code segment descripter
mov dword [ebx+0x10], 0x7c0001ff
mov dword [ebx+0x14], 0x00409800

; create stack segment descripter
mov dword [ebx+0x18], 0x7c00fffe
mov dword [ebx+0x1c], 0x00cf9600

; create protectd mode display buffer descripter
mov dword [ebx+0x20], 0x80007fff
mov dword [ebx+0x24], 0x0040920b

; update gdt limit
mov word [cs:pgdt+0x7c00], #(8*5-1)

in al, 0x92
or al, 0000_0010B
out 0x92, al

cli

mov eax, cr0
or eax, 1
mov cr0, eax

; enter protected mode
jmp dword 0x0010:flush	;use code segment selector

[bits 32]

flush:
	mov eax, 0x0008	; set data segment selector
	mov ds, eax

	mov eax, 0x0018 ; set stack segment selector
	mov ss, eax
	xor esp, esp

	; load kernel core from disk to the memory
	mov edi, core_base_address
	mov eax, core_start_sector
	mov ebx, edi
	call read_hard_disk_0


; ============= disk manage kit =============
; read 1 sector
; @eax : sector number
; @ds:ebx : dest buffer.
read_hard_disk_0:
	push eax
	push ecx
	push edx

	push eax

	mov dx, 0x1f2
	mov al, 1
	out dx, al ; amout of sector

	inc dx ; 0x1f3
	pop eax
	mov al ,0x1
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
	mov [ebx], ax
	add ebx, 2
	loop .read_to_buffer

	pop edx
	pop ecx
	pop eax
ret

pgdt	dw 0
		dd 0x00007e00

times 510-($-$$)	db 0
					db 0x55, 0xaa
