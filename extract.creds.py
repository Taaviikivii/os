"""
Run this AFTER QEMU exits to save the credential sector.
tasks.json chains:  ... ; python extract_creds.py
"""
import os

CRED_OFFSET = (12 - 1) * 512   # 5632
CREDS_FILE  = 'creds.bin'

if not os.path.exists('os.bin'):
    print("os.bin not found — nothing to extract")
else:
    data = open('os.bin', 'rb').read()
    if len(data) >= CRED_OFFSET + 512:
        creds = data[CRED_OFFSET:CRED_OFFSET + 512]
        open(CREDS_FILE, 'wb').write(creds)
        flag = creds[0]
        print(f"creds.bin saved: flag={flag}  "
              f"({'account exists' if flag == 1 else 'no account'})")
    else:
        print(f"os.bin too small ({len(data)} bytes) — no cred sector to extract")