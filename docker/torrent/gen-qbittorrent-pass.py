import hashlib
import base64
import os
import sys

def generate_qbittorrent_hash(password):
    # qBittorrent parameters
    iterations = 100000
    salt_size = 16
    
    # Generate random salt
    salt = os.urandom(salt_size)
    
    # Generate PBKDF2 hash
    dk = hashlib.pbkdf2_hmac(
        'sha512',
        password.encode('utf-8'),
        salt,
        iterations
    )
    
    # Encode salt and hash to base64
    b64_salt = base64.b64encode(salt).decode('ascii')
    b64_hash = base64.b64encode(dk).decode('ascii')
    
    # Format as qBittorrent expects
    return f'@ByteArray({b64_salt}:{b64_hash})'

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 gen-qbittorrent-pass.py <password>")
        sys.exit(1)
        
    password = sys.argv[1]
    print(generate_qbittorrent_hash(password))
