; data.asm — blank credential sector (512 bytes = sector 12)
; flag byte = 0 means no account, triggers CREATE ACCOUNT MODE

times 512 db 0