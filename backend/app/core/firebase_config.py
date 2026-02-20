'''============== code approved by developer after review since the developer himself wrote it =============='''


import firebase_admin
from firebase_admin import credentials
import logging
import os

''' This module initializes the Firebase Admin SDK using a service account key stored in a local JSON file.'''



cred_path = os.path.join(os.path.dirname(__file__), "credentials.json")

logging.info(f"Firebase Admin: attempting to load service account key from: {cred_path}")

if not firebase_admin._apps:
    try:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        logging.info("Firebase Admin initialized successfully.")
    except Exception as e:
        logging.error(f"Firebase Admin initialization failed: {e}")
