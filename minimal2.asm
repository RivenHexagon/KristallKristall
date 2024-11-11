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
