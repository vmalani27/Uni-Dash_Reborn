import os
from cryptography.fernet import Fernet

ENCRYPTION_KEY = os.getenv("ENCRYPTION_KEY")
if not ENCRYPTION_KEY:
    raise ValueError("ENCRYPTION_KEY environment variable is not set")

cipher = Fernet(ENCRYPTION_KEY.encode())

def encrypt_token(token: str) -> str:
    return cipher.encrypt(token.encode()).decode()

def decrypt_token(encrypted: str) -> str:
    try:
        return cipher.decrypt(encrypted.encode()).decode()
    except Exception:
        # If decryption fails, assume it's plaintext (for migration)
        return encrypted