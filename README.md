# KristallKristall
Low level code for modern Intel CPUs to run in BIOS Legacy Mode on VirtualBox.

## Tool chain
Compile with `nasm`:
```
nasm -f bin minimal.asm -o minimal.bin
```
Hexdump the file:
```
xxd -g 1 -l 512 minimal.bin
```
Create an empty `.img` file:
```
dd if=/dev/zero of=bootable.img bs=512 count=2048
```
Write to disk image:
```
dd if=minimal.bin of=bootable.img bs=512 count=1 conv=notrunc
```
Convert the `.img` to a `.vdi`:
```
VBoxManage convertfromraw bootable.img bootable.vdi --format VDI
```
## Some breakdown
The asm code
```
section .text
    org 0x7C00                ; Set origin to 0x7C00 for BIOS bootloaders
    global _start

_start:
    mov si, message           ; Load address of the message into SI register
    jmp display_message       ; Jump to start of display logic

display_message:
    lodsb                     ; Load byte at [SI] into AL, increments SI
    cmp al, 0                 ; Check if AL is zero (end of string)
    je hang                   ; If zero, jump to hang (end of program)
    
    mov ah, 0x0E              ; BIOS teletype output service
    int 0x10                  ; Call BIOS interrupt to print character in AL
    jmp display_message       ; Repeat for next character

hang:
    jmp $                     ; Infinite loop to keep the program running

message db 'Hello', 0         ; Define message with null terminator

times 510-($-$$) db 0         ; Pad to 510 bytes
dw 0xAA55                     ; Boot signature (2 bytes)
```
compiles down to
```
00000000: be 12 7c eb 00 ac 3c 00 74 06 b4 0e cd 10 eb f5  ..|...<.t.......
00000010: eb fe 48 65 6c 6c 6f 00 00 00 00 00 00 00 00 00  ..Hello.........
[...]
000001f0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 55 aa  ..............U.
```
with the op code corelation:
```
01. BE 12 7C             ; mov si, message
02. EB 00                ; jmp display_message
03. AC                   ; lodsb
04. 3C 00                ; cmp al, 0
05. 74 06                ; je hang

06. B4 0E                ; mov ah, 0x0E
07. CD 10                ; int 0x10
08. EB F5                ; jmp display_message

09. EB FE                ; jmp $
10. 48 65 6C 6C 6F 00    ; 'Hello' message
11. 00 00 00 00 00 00 00 ; padding
12. AA 55                ; boot signature
```
### Explaination of `je hang` as an example
The op code `74`:`je` (jump if equal) comes with a displacement of `06`: six bytes. The CPU continues six bytes after the instruction following `74 06`.  That would be the instruction `B4 0E`: `mov ah, 0x0E` of line 06 with the byte `B4` as 0 displacement. Adding +6 leads to the infinite loop op code `EB FE`:`jmp $`.


--END--