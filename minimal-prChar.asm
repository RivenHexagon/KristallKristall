; minimal.asm - A minimal x86 program to run directly from the BIOS
; prints a single character on screen in 16-bit real mode

section .text
    global _start
_start:
    mov ah, 0x0E            ; BIOS teletype output service
    mov al, 'H'             ; ASCII character 'H'
    int 0x10                ; Call BIOS interrupt 0x10 (display character)
    jmp $                   ; Infinite loop to keep the program running

    times 510-($-$$) db 0   ; Pad to 510 bytes
    dw 0xAA55               ; Boot signature (2 bytes)
