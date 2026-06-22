[org 0x7C00]
[bits 16]

    ; Save boot drive immediately — BIOS sets DL before jumping here
    mov [cs:boot_drive], dl

    ; Step 1: Reset disk controller (clears any iPXE/SeaBIOS stale state)
    mov ah, 0x00
    mov dl, [cs:boot_drive]
    int 0x13

    ; Step 2: Load 10 sectors (kernel, sectors 2-11) into 0x0000:0x1000
    xor ax, ax
    mov es, ax              ; es = segment 0
    mov bx, 0x1000          ; es:bx = physical 0x1000

    mov ah, 0x02
    mov al, 10              ; 10 sectors = 5120 bytes
    mov ch, 0               ; cylinder 0
    mov cl, 2               ; start from sector 2 (sector 1 = this bootloader)
    mov dh, 0               ; head 0
    mov dl, [cs:boot_drive]
    int 0x13
    jnc .success            ; no carry = success

    ; --- Disk error: print error code and freeze ---
    mov bl, ah              ; save BIOS error code from AH
    mov si, err_msg
.ep:lodsb
    cmp al, 0
    je  .print_code
    mov ah, 0x0E
    int 0x10
    jmp .ep
.print_code:
    ; print high nibble of error code
    mov al, bl
    shr al, 4
    call print_hex_nibble
    ; print low nibble
    mov al, bl
    and al, 0x0F
    call print_hex_nibble
    jmp $                   ; freeze

.success:
    jmp 0x0000:0x1000       ; jump to kernel entry point

; --- Subroutine: print AL as a single hex nibble ---
print_hex_nibble:
    cmp al, 10
    jl  .is_digit
    add al, 'A' - 10
    jmp .emit
.is_digit:
    add al, '0'
.emit:
    mov ah, 0x0E
    int 0x10
    ret

boot_drive  db 0x80         ; default to hard disk; overwritten at runtime
err_msg     db 'BOOT DISK ERR=0x', 0

times 510-($-$$) db 0
dw 0xAA55