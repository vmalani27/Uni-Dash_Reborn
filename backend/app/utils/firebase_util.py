from fastapi import HTTPException, Header
from firebase_admin import auth
import logging

async def verify_firebase_token(authorization: str | None = Header(None)):
    logging.info("verify_firebase_token: function called")

    if authorization is None:
        logging.warning("No Authorization header received")
        raise HTTPException(status_code=401, detail="Missing Authorization header")

    logging.info(f"Authorization header: {authorization[:50]}")

    if not authorization.startswith("Bearer "):
        logging.warning("Authorization header does not start with Bearer")
        raise HTTPException(status_code=401, detail="Invalid authorization format")

    id_token = authorization.split(" ")[1]
    logging.info("Token extracted. Attempting to verify with Firebase Admin...")

    try:
        decoded_token = auth.verify_id_token(id_token)
        logging.info(f"Token verification succeeded. UID: {decoded_token.get('uid')}")
        return decoded_token
    except Exception as e:
        logging.error(f"Token verification failed: {e}")
        raise HTTPException(status_code=401, detail="Invalid or expired token")
