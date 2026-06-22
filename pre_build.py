"""
Run this BEFORE nasm/copy to rescue the credential sector from the current os.bin.
Saves it to creds.bin so it survives the rebuild.
"""
import os

CRED_OFFSET = 11 * 512  # 5632

if os.path.exists('os.bin'):
    data = open('os.bin', 'rb').read()
    if len(data) >= CRED_OFFSET + 512:
        creds = data[CRED_OFFSET:CRED_OFFSET + 512]
        if creds[0] == 1:  # only save if a real account exists
            open('creds.bin', 'wb').write(creds)
            print(f"creds.bin saved (flag=1, account exists)")
        else:
            print(f"Sector 12 flag=0, skipping creds.bin save")
    else:
        print("os.bin has no credential sector yet")
else:
    print("No os.bin found")