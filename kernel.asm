[org 0x1000]
[bits 16]

; ============================================================
; TAAVI OS - Boot Authentication
;
; Memory map:
;   0x0000:0x7C00 = BIOS bootloader
;   0x0000:0x1000 = this kernel (5120 bytes)
;   0x0000:0x3000 = disk I/O buffer
;   0x0000:0x0500 = DAP scratch area
;
; Disk layout:
;   Drive 0x80 (os.bin)    = bootloader + kernel (boot disk)
;   Drive 0x81 (creds.bin) = sector 1 only = credentials
;       [0x3000+0] = flag (0=no account, 1=account exists)
;       [0x3000+1 .. +32] = username null-terminated
;       [0x3000+33.. +64] = password null-terminated
; ============================================================

start:
    push cs
    pop ds

    ; Credentials are on the second IDE drive (index=1 in QEMU = 0x81)
    mov byte [cred_drive], 0x81

    ; Read credential sector into 0x3000
    call read_cred_sector
    jc   disk_error

    push cs
    pop ds

    xor ax, ax
    mov es, ax

    mov al, [es:0x3000]
    cmp al, 0
    je  create_account
    jmp login_mode


; ============================================================
disk_error:
    push cs
    pop ds
    mov si, disk_err_msg
.p: lodsb
    cmp al, 0
    je  halt
    mov ah, 0x0E
    int 0x10
    jmp .p


; ============================================================
; Helper: read sector 1 of cred_drive into 0x0000:0x3000
; ============================================================
read_cred_sector:
    push ds
    push si

    xor ax, ax
    mov ds, ax
    mov si, 0x0500

    mov byte [si+0],  0x10
    mov byte [si+1],  0x00
    mov word [si+2],  1         ; 1 sector
    mov word [si+4],  0x3000    ; buffer offset
    mov word [si+6],  0x0000    ; buffer segment
    mov dword [si+8], 0         ; LBA 0 = sector 1 of creds.bin
    mov dword [si+12], 0

    mov ah, 0x42
    mov dl, [cred_drive]
    int 0x13

    pop si
    pop ds
    ret

; ============================================================
; Helper: write 0x0000:0x3000 to sector 1 of cred_drive
; ============================================================
write_cred_sector:
    push ds
    push si

    xor ax, ax
    mov ds, ax
    mov si, 0x0500

    mov byte [si+0],  0x10
    mov byte [si+1],  0x00
    mov word [si+2],  1
    mov word [si+4],  0x3000
    mov word [si+6],  0x0000
    mov dword [si+8], 0         ; LBA 0
    mov dword [si+12], 0

    mov ah, 0x43
    mov al, 0x00
    mov dl, [cred_drive]
    int 0x13

    pop si
    pop ds
    ret


; ============================================================
; CREATE ACCOUNT
; ============================================================
create_account:
    push cs
    pop ds

    mov si, create_msg
.banner:
    lodsb
    cmp al, 0
    je  .b_done
    mov ah, 0x0E
    int 0x10
    jmp .banner
.b_done:
    call print_crlf
    call print_crlf

    ; --- get username ---
    mov si, create_user_msg
.up: lodsb
    cmp al, 0
    je  .ui
    mov ah, 0x0E
    int 0x10
    jmp .up
.ui:
    mov bx, new_username
    mov [new_username_ptr], bx
    mov byte [new_username_len], 0
.uk:
    mov ah, 0
    int 0x16
    push cs
    pop ds
    cmp al, 13
    je  .ud
    cmp al, 8
    je  .ubs
    cmp byte [new_username_len], 31
    jge .uk
    mov ah, 0x0E
    int 0x10
    mov bx, [new_username_ptr]
    mov [bx], al
    inc bx
    mov [new_username_ptr], bx
    inc byte [new_username_len]
    jmp .uk
.ubs:
    cmp byte [new_username_len], 0
    je  .uk
    dec byte [new_username_len]
    mov bx, [new_username_ptr]
    dec bx
    mov [new_username_ptr], bx
    mov ah, 0x0E
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .uk
.ud:
    cmp byte [new_username_len], 0
    je  .ui
    mov bx, [new_username_ptr]
    mov byte [bx], 0
    call print_crlf

    ; --- get password ---
    mov si, create_pass_msg
.pp: lodsb
    cmp al, 0
    je  .pi
    mov ah, 0x0E
    int 0x10
    jmp .pp
.pi:
    mov bx, new_password
    mov [new_password_ptr], bx
    mov byte [new_password_len], 0
.pk:
    mov ah, 0
    int 0x16
    push cs
    pop ds
    cmp al, 13
    je  .pd
    cmp al, 8
    je  .pbs
    cmp byte [new_password_len], 31
    jge .pk
    mov bx, [new_password_ptr]
    mov [bx], al
    inc bx
    mov [new_password_ptr], bx
    inc byte [new_password_len]
    mov ah, 0x0E
    mov al, '*'
    int 0x10
    jmp .pk
.pbs:
    cmp byte [new_password_len], 0
    je  .pk
    dec byte [new_password_len]
    mov bx, [new_password_ptr]
    dec bx
    mov [new_password_ptr], bx
    mov ah, 0x0E
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .pk
.pd:
    cmp byte [new_password_len], 0
    je  .pi
    mov bx, [new_password_ptr]
    mov byte [bx], 0
    call print_crlf

    ; --- build credential sector at 0x3000 ---
    xor ax, ax
    mov es, ax
    push cs
    pop ds

    mov di, 0x3000
    mov cx, 512
    xor al, al
.zero:
    mov [es:di], al
    inc di
    loop .zero

    mov byte [es:0x3000], 1     ; flag = account exists

    mov si, new_username
    mov di, 0x3001
.cu:
    mov al, [si]
    mov [es:di], al
    inc si
    inc di
    cmp al, 0
    jne .cu

    mov si, new_password
    mov di, 0x3021
.cp:
    mov al, [si]
    mov [es:di], al
    inc si
    inc di
    cmp al, 0
    jne .cp

    ; write to creds.bin (drive 0x81, sector 1)
    push cs
    pop ds
    call write_cred_sector
    jc   disk_error

    push cs
    pop ds

    mov si, account_created_msg
.ok: lodsb
    cmp al, 0
    je  halt
    mov ah, 0x0E
    int 0x10
    jmp .ok


; ============================================================
; LOGIN MODE
; ============================================================
login_mode:
    push cs
    pop ds
    xor ax, ax
    mov es, ax

    call read_cred_sector
    jc   disk_error

    push cs
    pop ds

.retry:
    mov bx, username
    mov [username_ptr], bx
    mov byte [username_len], 0
    mov bx, password
    mov [password_ptr], bx
    mov byte [password_len], 0

    mov si, message
.banner:
    lodsb
    cmp al, 0
    je  .uk
    mov ah, 0x0E
    int 0x10
    jmp .banner

.uk:
    mov ah, 0
    int 0x16
    push cs
    pop ds
    cmp al, 13
    je  .ud
    cmp al, 8
    je  .ubs
    cmp byte [username_len], 31
    jge .uk
    mov ah, 0x0E
    int 0x10
    mov bx, [username_ptr]
    mov [bx], al
    inc bx
    mov [username_ptr], bx
    inc byte [username_len]
    jmp .uk
.ubs:
    cmp byte [username_len], 0
    je  .uk
    dec byte [username_len]
    mov bx, [username_ptr]
    dec bx
    mov [username_ptr], bx
    mov ah, 0x0E
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .uk
.ud:
    mov bx, [username_ptr]
    mov byte [bx], 0
    call print_crlf

    mov si, password_msg
.pp: lodsb
    cmp al, 0
    je  .pk
    mov ah, 0x0E
    int 0x10
    jmp .pp

.pk:
    mov ah, 0
    int 0x16
    push cs
    pop ds
    cmp al, 13
    je  .pdd
    cmp al, 8
    je  .pbs
    cmp byte [password_len], 31
    jge .pk
    mov bx, [password_ptr]
    mov [bx], al
    inc bx
    mov [password_ptr], bx
    inc byte [password_len]
    mov ah, 0x0E
    mov al, '*'
    int 0x10
    jmp .pk
.pbs:
    cmp byte [password_len], 0
    je  .pk
    dec byte [password_len]
    mov bx, [password_ptr]
    dec bx
    mov [password_ptr], bx
    mov ah, 0x0E
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .pk
.pdd:
    mov bx, [password_ptr]
    mov byte [bx], 0
    call print_crlf

    push cs
    pop ds
    xor ax, ax
    mov es, ax

    mov si, username
    mov di, 0x3001
.cmu:
    mov al, [si]
    mov bl, [es:di]
    cmp al, bl
    jne .denied
    cmp al, 0
    je  .chk_pass
    inc si
    inc di
    jmp .cmu

.chk_pass:
    mov si, password
    mov di, 0x3021
.cmp:
    mov al, [si]
    mov bl, [es:di]
    cmp al, bl
    jne .denied
    cmp al, 0
    je  .granted
    inc si
    inc di
    jmp .cmp

.granted:
    push cs
    pop ds
    jmp welcome_screen

.denied:
    push cs
    pop ds
    mov si, denied_msg
.pd: lodsb
    cmp al, 0
    je  .retry
    mov ah, 0x0E
    int 0x10
    jmp .pd


; ============================================================
; WELCOME SCREEN
; ============================================================
welcome_screen:
    push cs
    pop ds

    mov ax, 0x0003
    int 0x10

    mov ax, 0x0600
    mov bh, 0x1F
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10

    mov ah, 0x02
    mov bh, 0
    mov dh, 10
    mov dl, 0
    int 0x10

    mov ah, 0x0E
    mov cx, 28
.sp1:
    mov al, ' '
    int 0x10
    loop .sp1

    mov si, welcome_msg
.wm: lodsb
    cmp al, 0
    je  .wm_done
    int 0x10
    jmp .wm
.wm_done:

    xor ax, ax
    mov es, ax
    mov di, 0x3001
.wu:
    mov al, [es:di]
    cmp al, 0
    je  .wu_done
    mov ah, 0x0E
    int 0x10
    inc di
    jmp .wu
.wu_done:

    push cs
    pop ds

    mov ah, 0x02
    mov bh, 0
    mov dh, 11
    mov dl, 0
    int 0x10

    mov ah, 0x0E
    mov cx, 28
.sp2:
    mov al, ' '
    int 0x10
    loop .sp2

    mov si, separator_msg
.sm: lodsb
    cmp al, 0
    je  .sm_done
    mov ah, 0x0E
    int 0x10
    jmp .sm
.sm_done:

    mov ah, 0x02
    mov bh, 0
    mov dh, 13
    mov dl, 0
    int 0x10

    mov ah, 0x0E
    mov cx, 34
.sp3:
    mov al, ' '
    int 0x10
    loop .sp3

    mov si, subtitle_msg
.su: lodsb
    cmp al, 0
    je  halt
    mov ah, 0x0E
    int 0x10
    jmp .su


; ============================================================
print_crlf:
    push ax
    push bx
    mov ah, 0x0E
    mov bx, 0x0007
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    pop bx
    pop ax
    ret

halt:
    cli
    hlt
    jmp $

; ============================================================
; DATA
; ============================================================
cred_drive          db 0x81

disk_err_msg        db 'Disk error!', 13, 10, 0
message             db 'TAAVI OS', 13, 10, 13, 10, 'Username: ', 0
create_msg          db 'TAAVI OS - First Boot', 13, 10, 'CREATE ACCOUNT', 0
password_msg        db 'Password: ', 0
denied_msg          db 13, 10, 'Access Denied. Try again.', 13, 10, 0
welcome_msg         db 'Welcome, ', 0
separator_msg       db '-------------------', 0
subtitle_msg        db 'TaaviOS', 0
create_user_msg     db 'New Username: ', 0
create_pass_msg     db 'New Password: ', 0
account_created_msg db 13, 10, 'Account created! Reboot to login.', 13, 10, 0

username_len  db 0
username_ptr  dw username
username      times 32 db 0

password_len  db 0
password_ptr  dw password
password      times 32 db 0

new_username_len  db 0
new_username_ptr  dw new_username
new_username      times 32 db 0

new_password_len  db 0
new_password_ptr  dw new_password
new_password      times 32 db 0

times 5120-($-$$) db 0