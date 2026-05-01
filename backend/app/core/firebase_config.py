'''============== code approved by developer after review since the developer himself wrote it =============='''


import firebase_admin
from firebase_admin import credentials
import logging
import os
import json

''' This module initializes the Firebase Admin SDK using a service account key stored in a local JSON file.'''



def _load_firebase_credential() -> tuple[credentials.Base, str]:
    # 1) Raw JSON in env (best for container deployments)
    raw_json = os.getenv("FIREBASE_CREDENTIALS_JSON")
    if raw_json:
        try:
            payload = json.loads(raw_json)
            return credentials.Certificate(payload), "FIREBASE_CREDENTIALS_JSON"
        except Exception as exc:
            raise RuntimeError(f"Invalid FIREBASE_CREDENTIALS_JSON: {exc}") from exc

    # 2) Explicit path from env
    explicit_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
    if explicit_path:
        if not os.path.exists(explicit_path):
            raise RuntimeError(
                f"FIREBASE_CREDENTIALS_PATH does not exist: {explicit_path}"
            )
        return credentials.Certificate(explicit_path), "FIREBASE_CREDENTIALS_PATH"

    # 3) Standard Google env path
    gac_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    if gac_path:
        if not os.path.exists(gac_path):
            raise RuntimeError(
                "GOOGLE_APPLICATION_CREDENTIALS is set but file does not exist: "
                f"{gac_path}"
            )
        return credentials.Certificate(gac_path), "GOOGLE_APPLICATION_CREDENTIALS"

    # 4) Local development fallback
    local_path = os.path.join(os.path.dirname(__file__), "credentials.json")
    if os.path.exists(local_path):
        return credentials.Certificate(local_path), local_path

    # 5) Cloud-hosted fallback (metadata service / workload identity)
    return credentials.ApplicationDefault(), "ApplicationDefault"


project_id = os.getenv("FIREBASE_PROJECT_ID") or os.getenv("NEXT_PUBLIC_FIREBASE_PROJECT_ID")

if not firebase_admin._apps:
    try:
        cred, source = _load_firebase_credential()
        options = {"projectId": project_id} if project_id else None
        firebase_admin.initialize_app(cred, options)
        logging.info(
            "Firebase Admin initialized successfully (source=%s, project_id=%s).",
            source,
            project_id or "auto",
        )
    except Exception as e:
        logging.critical("Firebase Admin initialization failed: %s", e)
        raise
