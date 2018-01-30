MINI_KERNEL_LOAD_ADDRESS equ 0x40000
MINI_KERNEL_DATA_ADDRESS equ MINI_KERNEL_LOAD_ADDRESS
MINI_KERNEL_INIT_ADDRESS equ MINI_KERNEL_LOAD_ADDRESS+mini_kernel_init

MINI_KERNEL_DATA:
	core_size dd mini_kernel_init_end
	core_init_address dd mini_kernel_init
	core_gdt_limit dw 0
	core_gdt_address dd 0x7e00

str_kern_01 db "kernel init stage 1 done!"

temp_data:

times 64-($-$$) db 0

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
; >>> save the current same descripter index of GDT that needed be loaded to the end of it.
xor ebx, ebx
mov ebx, cs
and ebx, 0xfffffff8
add ebx, [MINI_KERNEL_DATA_ADDRESS+core_gdt_address] ; ebx is the address of old code segment descripter index 
xor ecx, ecx
mov ecx, [MINI_KERNEL_DATA_ADDRESS+core_gdt_limit]
add ecx, [MINI_KERNEL_DATA_ADDRESS+core_gdt_address] ; ecx is the end position of current GDT
mov eax, [ebx]
mov [ecx], eax
mov eax, [ebx+4]
mov [ecx+4], eax
; >>> mov the old code segment descripter to the same position(index) of the GDT needed to be loaded.
mov eax, cs
and eax, 0xfffffff8
mov dword edi, [MINI_KERNEL_DATA_ADDRESS+core_gdt_address]
add edi, eax
sub esp, 0x8
sgdt [ss:esp]
mov dword esi, [ss:esp+2] 
add esp, 0x8
add esi, eax
mov dword eax, [esi]
mov [edi], eax 
mov dword eax, [esi+4]
mov [edi+4], eax
; >>> rebuild GDT
mov word [MINI_KERNEL_DATA_ADDRESS+0x8], 39
lgdt [MINI_KERNEL_DATA_ADDRESS+0x8]

jmp dword 0x0018:gdt_reload_done+0x40000 ; use new cs segment selector
gdt_reload_done:
; >>> init the with new GDT
mov eax, 0x8
mov ds, eax
mov eax, 0x20
mov ss, eax
xor esp, esp

mov eax, str_kern_01+0x40000
call put_string

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