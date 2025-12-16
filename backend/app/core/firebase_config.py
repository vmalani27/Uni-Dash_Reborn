import firebase_admin
from firebase_admin import credentials
import logging
import os

cred_path = os.path.join(os.path.dirname(__file__), "credentials.json")

logging.info(f"Firebase Admin: attempting to load service account key from: {cred_path}")

if not firebase_admin._apps:
    try:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        logging.info("Firebase Admin initialized successfully.")
    except Exception as e:
        logging.error(f"Firebase Admin initialization failed: {e}")
