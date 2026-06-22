[org 0x1000]
[bits 16]

mov ax, cs
mov ds, ax

mov si, message

print:
    lodsb
    cmp al, 0
    je input

    mov ah, 0x0E
    int 0x10
    jmp print

input:
    mov ah, 0
    int 0x16

    cmp al, 13
    je enter_pressed

    cmp al, 8
    je backspace

    mov ah, 0x0E
    int 0x10

    mov bx, [username_ptr]
    mov [bx], al
    inc bx
    mov [username_ptr], bx

    inc byte [username_len]

    jmp input

backspace:
    cmp byte [username_len], 0
    je input

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

    jmp input

enter_pressed:

    mov bx, [username_ptr]
    mov byte [bx], 0

    mov ah, 0x0E

    mov al, 13
    int 0x10

    mov al, 10
    int 0x10

    mov si, password_msg

print_password:
    lodsb
    cmp al, 0
    je password_input

    mov ah, 0x0E
    int 0x10

    jmp print_password

password_input:
    mov ah, 0
    int 0x16

    cmp al, 13
    je password_done

    cmp al, 8
    je password_backspace

    mov bx, [password_ptr]
    mov [bx], al
    inc bx
    mov [password_ptr], bx

    inc byte [password_len]

    mov ah, 0x0E
    mov al, '*'
    int 0x10

    jmp password_input

password_backspace:

    cmp byte [password_len], 0
    je password_input

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

    jmp password_input

password_done:

    mov bx, [password_ptr]
    mov byte [bx], 0

    mov si, username
    mov di, correct_username

compare_username:

    mov al, [si]
    mov bl, [di]

    cmp al, bl
    jne username_invalid

    cmp al, 0
    je check_password

    inc si
    inc di

    jmp compare_username

check_password:

    mov si, password
    mov di, correct_password

compare_password:

    mov al, [si]
    mov bl, [di]

    cmp al, bl
    jne access_denied

    cmp al, 0
    je access_granted

    inc si
    inc di

    jmp compare_password
access_granted:

    mov ah, 0x0E

    mov al, 13
    int 0x10

    mov al, 10
    int 0x10

    mov si, granted_msg

print_granted:
    lodsb
    cmp al, 0
    je halt

    mov ah, 0x0E
    int 0x10

    jmp print_granted


access_denied:

    mov ah, 0x0E

    mov al, 13
    int 0x10

    mov al, 10
    int 0x10

    mov si, denied_msg

print_denied:
    lodsb
    cmp al, 0
    je halt

    mov ah, 0x0E
    int 0x10

    jmp print_denied


username_invalid:
    jmp access_denied

halt:
    jmp $

message db 'TAAVI OS',13,10,13,10,'Username: ',0

password_msg db 'Password: ',0

correct_username db 'taavi',0

correct_password db '1234',0

granted_msg db 'Access Granted',0

denied_msg db 'Access Denied',0

username_len db 0
username_ptr dw username
username times 32 db 0

password_len db 0
password_ptr dw password
password times 32 db 0