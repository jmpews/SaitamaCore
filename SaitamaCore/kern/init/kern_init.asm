%include "macros.inc"

MINI_KERNEL_LOAD_ADDRESS equ 0x800000
MINI_KERNEL_DATA_ADDRESS equ MINI_KERNEL_LOAD_ADDRESS
MINI_KERNEL_INIT_ADDRESS equ MINI_KERNEL_LOAD_ADDRESS+mini_kernel_init

MINI_KERNEL_DATA:
	core_size dd mini_kernel_init_end
	core_init_address dd mini_kernel_init
	core_gdt_limit dw 31
	core_gdt_address dd 0x7e00
	core_page_directory_address dd 0x10000
	kernel_space_pde_offset dd 0xc00

str_kern_01 db "kernel init stage 1 done!", 0
str_kern_02 db "kernel init stage 2 done!", 0

temp_data:

times 0x80-($-$$) db 0

[bits 32]

mini_kernel_init:
; >>> rebuild GDT descripter at 0x7e00
mov ebx, [MINI_KERNEL_DATA_ADDRESS+core_gdt_address]
; make reserved segment descripter
sub esp, 4*4+2*4
lea eax, [esp+4*4]
mov dword [esp], eax
mov dword [esp+4], 0
mov dword [esp+8], 0
mov dword [esp+0xc], 0
call make_gdt_descriptor
mov eax, [esp+0x10]
mov [ebx+0x0], eax
mov eax, [esp+0x14]
mov [ebx+0x4], eax
add esp, 4*4+2*4

; make data segment descripter
sub esp, 4*4+2*4
lea eax, [esp+4*4]
mov dword [esp], eax
mov dword [esp+4], 0
mov dword [esp+8], 0xffffffff
mov dword [esp+0xc], 0x00cf9200
call make_gdt_descriptor
mov eax, [esp+0x10]
mov [ebx+0x8], eax
mov eax, [esp+0x14]
mov [ebx+0xc], eax
add esp, 4*4+2*4

; make stack segment descripter
sub esp, 4*4+2*4
lea eax, [esp+4*4]
mov dword [esp], eax
mov dword [esp+4], 0x00007c00
mov dword [esp+8], 0xffffe
mov dword [esp+0xc], 0x00cf9600
call make_gdt_descriptor
mov eax, [esp+0x10]
mov [ebx+0x10], eax
mov eax, [esp+0x14]
mov [ebx+0x14], eax
add esp, 4*4+2*4

; make code segment descripter
sub esp, 4*4+2*4
lea eax, [esp+4*4]
mov dword [esp], eax
mov dword [esp+4], 0
mov dword [esp+8], 0xffffffff
mov dword [esp+0xc], 0x00cf9b00
call make_gdt_descriptor
mov eax, [esp+0x10]
mov [ebx+0x18], eax
mov eax, [esp+0x14]
mov [ebx+0x1c], eax
add esp, 4*4+2*4

; >>> retain the old code segment descripter
; if you want to rebuid or reload a new GDT, you must retain the old code segment descripter, at the same descripter
; >>> save the current same descripter index of GDT which needed to be loaded to the end of it.
xor ebx, ebx
mov ebx, cs
and ebx, 0xfffffff8
add ebx, [MINI_KERNEL_DATA_ADDRESS+core_gdt_address] ; ebx is the address of old code segment descripter index 
xor ecx, ecx
mov word cx, [MINI_KERNEL_DATA_ADDRESS+core_gdt_limit]
inc ecx
add ecx, [MINI_KERNEL_DATA_ADDRESS+core_gdt_address] ; ecx is the end position of current GDT
mov eax, [ebx]
mov [ecx], eax
mov eax, [ebx+4]
mov [ecx+4], eax
; >>> mov the old code segment descripter to the same position(index) of the GDT which needed to be loaded.
mov eax, cs
and eax, 0xfffffff8
mov dword edi, [MINI_KERNEL_DATA_ADDRESS+core_gdt_address]
add edi, eax ; edi is the reserved position of new GDT
sub esp, 0x8
sgdt [ss:esp]
mov dword esi, [ss:esp+2] 
add esp, 0x8
add esi, eax ; edi the corresponding index position of old GDT
mov dword eax, [esi]
mov [edi], eax 
mov dword eax, [esi+4]
mov [edi+4], eax
; >>> rebuild GDT
mov word [MINI_KERNEL_DATA_ADDRESS+0x8], 39
lgdt [MINI_KERNEL_DATA_ADDRESS+0x8]

jmp dword 0x0018:gdt_reload_done_stage1+MINI_KERNEL_LOAD_ADDRESS ; use new cs segment selector
gdt_reload_done_stage1:
; >>> init the with new GDT
mov eax, 0x8
mov ds, eax
mov es, eax
mov gs, eax
mov eax, 0x20
mov ss, eax
xor esp, esp

mov eax, str_kern_01+MINI_KERNEL_DATA_ADDRESS
call dword 0x18:MINI_KERNEL_LOAD_ADDRESS+put_string

; Q: why use Paging?
; A: **manage physical memory properly.**
; >>> setup Paging, Paging is base on Segmentation
; !!! Paging mechanism is divided into two parts: the Page Directory and the Page Table.
ida_debug_nop
setup_paging_mechanism:
mov ecx, 1024 
mov ebx, [MINI_KERNEL_DATA_ADDRESS+core_page_directory_address]
.clear_page_dir:
	mov dword [ebx], 0
	add ebx, 4
	loop .clear_page_dir
mov ecx, 1024*1024
.clear_page_table:
	mov dword [ebx], 0
	add ebx, 4
	loop .clear_page_table
; >>> init the page directory entry of kernel space
.create_kernel_pde:
	mov ebx, [MINI_KERNEL_DATA_ADDRESS+core_page_directory_address]
	mov eax, ebx
	add eax, 0x1000
	or eax, PG_US_U|PG_RW_W|PG_P
	mov dword [ebx+0], eax ; first page table
	mov dword [ebx+0xc00], eax ; 0xc0000000 - 0xffffffff is kernel space, just a convention

	; QA: need to access PAGE directory in th Paging Mode
	; >>> init the page directory address in Paging Mode
	mov ebx, [MINI_KERNEL_DATA_ADDRESS+core_page_directory_address]
	mov eax, ebx
	or eax, PG_US_U|PG_RW_W|PG_P
	mov [ebx+1023*4], eax
; >>> init the page table entry of kernel space
.create_kernel_pte:
	; for kernel low 1MB space
	mov eax, 1024*1024/0x1000
	mov ecx, eax
	xor edi, edi 
	xor ebx, ebx
	mov ebx, [MINI_KERNEL_DATA_ADDRESS+core_page_directory_address]
	add ebx, 0x1000
	xor eax, eax
	or eax, PG_US_U|PG_RW_W|PG_P
.create_kernel_pte_loop:
	mov [ebx+edi*4], eax
	add eax, 0x1000
	inc edi
	loop .create_kernel_pte_loop

mov ebx, [MINI_KERNEL_DATA_ADDRESS+core_page_directory_address]
mov eax, MINI_KERNEL_LOAD_ADDRESS
shr eax, 22
shl eax, 2
add ebx, eax
mov eax, 0x12000
or eax, PG_US_U|PG_RW_W|PG_P
mov dword [ebx], eax
mov ebx, 0x12000
mov eax, MINI_KERNEL_LOAD_ADDRESS
shl eax, 10
shr eax, 22
add ebx, eax
xor edi, edi
mov ecx,256
mov eax, MINI_KERNEL_LOAD_ADDRESS
or eax, PG_US_U|PG_RW_W|PG_P
.create_kernel_code_map:
	mov [ebx+edi*4], eax
	add eax, 0x1000
	inc edi
	loop .create_kernel_code_map

%if 0
; >>> kernel space shared with process
.create_other_kernel_pde:
	mov eax, [MINI_KERNEL_DATA_ADDRESS+core_page_directory_address]
	mov ebx, eax
	add eax, 0x2000
	or eax, PG_US_U|PG_RW_W|PG_P
	mov ecx, [MINI_KERNEL_DATA_ADDRESS+kernel_space_pde_offset]
	add ecx, 4
.create_other_kernel_pde_loop:
	mov [ebx+ecx], eax
	add ecx, 4
	add eax, 0x1000
	cmp ecx, 0x1000-4
	jl .create_other_kernel_pde_loop
%endif

; >>> start enable Paging
mov eax, [MINI_KERNEL_DATA_ADDRESS+core_page_directory_address]
mov cr3, eax

mov eax, cr0
or eax, 0x80000000
mov cr0, eax

.reload_gdt_descripter_with_new_address:
sgdt [MINI_KERNEL_DATA_ADDRESS+core_gdt_limit]
mov ebx, [MINI_KERNEL_DATA_ADDRESS+core_gdt_limit+2]
mov eax, [MINI_KERNEL_DATA_ADDRESS+kernel_space_pde_offset]
shr eax, 2
shl eax, 22
or dword [ds:ebx+4*8+4], eax
add dword [MINI_KERNEL_DATA_ADDRESS+core_gdt_limit+2], eax
lgdt [MINI_KERNEL_DATA_ADDRESS+core_gdt_limit]

jmp dword 0x18:MINI_KERNEL_LOAD_ADDRESS+gdt_reload_done_stage2
gdt_reload_done_stage2:

mov eax, str_kern_02+MINI_KERNEL_DATA_ADDRESS
call dword 0x18:MINI_KERNEL_LOAD_ADDRESS+put_string
nop
nop
nop

; ============= vga kit =============

; printf string
; @eax: 0~4GB offset address
put_string:
	push ecx
.getc:
	mov byte cl, [eax]
	or cl, cl
	jz .put_string_end
	call put_char
	inc eax
	jmp .getc
.put_string_end:
	pop ecx
	retf

; VGA programming
; 1. 20*80
; 2. 2 byte for a character
put_char:
	pushad
	
	mov dx, 0x3d4
	mov al, 0x0e
	out dx, al ; write to port
	mov dx, 0x3d5
	in al, dx ; read from port
	mov ah, al

	mov dx, 0x3d4
	mov al, 0x0f
	out dx, al ; write to port
	mov dx, 0x3d5
	in al, dx ; read from port

	mov bx, ax ; @bx == cursor 的16位数

	cmp cl, 0x0d ; 回车
	jnz .put_0a

.put_0a:
	cmp cl, 0x0a ; 换行符
	jnz .put_other
	add bx, 80
	jmp .roll_screen

.put_other:
	shl bx, 1 ; note!
	mov byte [ebx+0xb8000], cl
	shr bx, 1 ; note!
	add bx, 1

.roll_screen:
	cmp bx, 2000
	jl .set_cursor

	mov ax, ds
	mov es, ax
	cld
	mov esi, 0xb8000+0xa0
	mov edi, 0xb8000
	mov cx, 1920
	rep movsw
	mov ebx, 3840
	mov cx, 80

.cls:
	mov word [0x8b000+3840+ebx], 0x0720
	add bx, 2
	loop .cls

	mov bx, 1920

; @bx is the position of next cursor
.set_cursor:
	mov dx, 0x3d4
	mov al, 0x0e
	out dx, al

	mov dx, 0x3d5
	mov al, bh
	out dx, al

	mov dx, 0x3d4
	mov al, 0x0f
	out dx, al

	mov dx, 0x3d5
	mov al, bl
	out dx, al

	popad
	ret

; ============= vga kit =============

%if 0
; make_gdt_descriptor
; @eax: 线性基址
; @ebx: 段界限
; @ecx: 属性
; @return ebx:eax 完整的描述符

make_gdt_descriptor:
	push edx

	push eax
	push ebx
	shl eax, 0x10 ; shift left
	and ebx, 0xFFFF
	or dword eax, ebx ; TODO
	mov edx, eax ; low 32 bit
	pop ebx
	pop eax

	push edx
	mov edx, eax
	and edx, 0xff000000
	and eax, 0x00ff0000
	shr eax, 0x10
	or eax, edx

	and ebx, 0x000f0000
	or edx, ebx

	or edx, ecx ;  with segment flag

	pop eax
	mov ebx, edx

	pop edx
	ret

%else
; make_gdt_descriptor(线性基址, 段界限, 类型)
; @return

make_gdt_descriptor:
	push ebp 
	mov ebp, esp

	push eax
	push ebx
	push ecx
	push edx

	mov edx, [ebp+0x8] ; the address of return value
	mov eax, [ebp+0xc] ; 线性基址
	mov ebx, [ebp+0x10] ; 段界限
	mov ecx, [ebp+0x14] ; 类型

	push eax
	push ebx
	shl eax, 0x10 ; shift left
	and ebx, 0xFFFF
	or dword eax, ebx ; TODO
	mov dword [ss:edx], eax ; save low 32 bit
	pop ebx
	pop eax

	push edx
	mov edx, eax
	and edx, 0xff000000
	and eax, 0x00ff0000
	shr eax, 0x10
	or eax, edx

	and ebx, 0x000f0000 ; limit
	or eax, ebx

	or eax, ecx ; flag

	pop edx
	mov dword [ss:edx+4], eax

	pop edx
	pop ecx
	pop ebx
	pop eax

	mov esp, ebp
	pop ebp
	ret

%endif

mini_kernel_init_end: