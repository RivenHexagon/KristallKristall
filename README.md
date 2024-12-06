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
## Using qemu
1. Installation:
```
sudo apt update
sudo apt install qemu-system-x86
```
2. Verify Installation
```
qemu-system-x86_64 --version
```
3. Create bootable binary
```
nasm -f bin minimal.asm -o minimal.bin
```
4. Run the Bootloader in QEMU
```
qemu-system-x86_64 minimal.bin
qemu-system-x86_64 -drive file=bootable.img,format=raw
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
with the op code corelation (Intel code format):
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
### Displacement Operand of Line 05
The op code of `je hang` (`je` = jump if equal) is `74` and comes with the displacement operand `0x06`. It instructs the CPU to continue execution six bytes further up into memory. Counting starts at byte `B4` of **line 06**, directly after the instruction `74 06`. Adding +6 to the *instruction pointer* leads to the infinite loop op code `jmp $` of **line 09**, encoded as `EB FE`.

### Displacement Operands of Lines 08 and 09
The displacement operands of the `jmp` instructions of **lines 08** and **09** are in **two's complement** representing negative numbers, because the jumps is directed **backwards**. As before, the displacement is calculated from the memory position right after the jump instruction, **including** the operand. For e.g. the displacement operand of the `jmp` instruction of **line 08** is `0xF5`, which translates to -11<sub>10</sub>. Counting 11 bytes **backwards** from the byte `0xEB` in **line 09**, takes us to byte `0xAC` of **line 03**, exactly to where the code after the label `display_message` starts.

### Memory Address of the Message String
The *BIOS* loads the programm code with the offset `0x7C00` into memory. The **absolute** memory **address** of the first byte of the `'hello'` message string is then this offset **plus** the offset of the string **within** the **program** code. The first byte of the program is the `mov si` instruction of **line 01**, encoded as `0xBE` at the **relative** offset **`0x00`**. The start of the message is 18 bytes further up into memory at the relative position `0x12`. Once the program is loaded into memory, the message's absolute address becomes `0x7C00` + `0x12` = `0x7C12`. This corresponds to the 16-bit operand of the `mov si` instruction of **line 01**: `BE 12 7C`. Please note that the **operand** is given in **little endian** format, so the **byte** order is reversed.

--END--