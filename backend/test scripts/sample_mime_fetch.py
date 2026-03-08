import os
import sys
import json
import base64
import requests
from dotenv import load_dotenv
from bs4 import BeautifulSoup

import sqlalchemy as sa
from sqlalchemy.orm import sessionmaker

# Change directory context so we can import from app
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app.models.oauthToken import OAuthToken
from app.utils.google_oauth import get_access_token
from app.utils.encryption import decrypt_token

load_dotenv()
SUPABASE_DB_URL = os.getenv("USER_DATABASE_URL")
if not SUPABASE_DB_URL:
    print("Missing USER_DATABASE_URL")
    sys.exit(1)

# Recursive MIME parser from the updated code
def extract_bodies(payload):
    text_body = ""
    html_body = ""
    
    def decode_data(data):
        if not data:
            return ""
        try:
            missing_padding = 4 - len(data) % 4
            if missing_padding:
                data += "=" * missing_padding
            return base64.urlsafe_b64decode(data).decode(errors="ignore")
        except Exception as e:
            return ""

    mime_type = payload.get("mimeType", "")
    data = payload.get("body", {}).get("data", "")
    
    if mime_type == "text/plain" and data:
        text_body = decode_data(data)
    elif mime_type == "text/html" and data:
        html_body = decode_data(data)
        
    for part in payload.get("parts", []):
        t, h = extract_bodies(part)
        if t: text_body += t + "\n"
        if h: html_body += h + "\n"
        
    return text_body.strip(), html_body.strip()

def main():
    engine = sa.create_engine(SUPABASE_DB_URL)
    Session = sessionmaker(bind=engine)
    db = Session()

    print("Fetching an OAuth token from DB...")
    token = db.query(OAuthToken).first()
    if not token:
        print("No OAuth users found. Please login via frontend first.")
        sys.exit(1)
        
    try:
        access_token = get_access_token(decrypt_token(token.refresh_token))
        print("Successfully refreshed access token.")
    except Exception as e:
        print(f"Error fetching token: {e}")
        sys.exit(1)

    headers = {"Authorization": f"Bearer {access_token}"}
    
    print("\nFetching latest 10 messages from Gmail API...")
    resp = requests.get(
        "https://gmail.googleapis.com/gmail/v1/users/me/messages",
        headers=headers,
        params={"maxResults": 10},
        timeout=10
    )
    resp.raise_for_status()
    message_ids = [m["id"] for m in resp.json().get("messages", [])]
    
    print("\n================ RAW PAYLOAD EXTRACTION ================\n")
    
    for i, msg_id in enumerate(message_ids):
        msg_resp = requests.get(
            f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{msg_id}",
            headers=headers,
            params={"format": "full"},
            timeout=10
        )
        msg_resp.raise_for_status()
        full = msg_resp.json()
        payload = full.get("payload", {})
        
        # Get Headers
        headers_map = {h["name"]: h["value"] for h in payload.get("headers", [])}
        subject = headers_map.get("Subject", "(No Subject)")
        
        text_body, html_body = extract_bodies(payload)
        
        # Fallback to parsing text from HTML if text is empty
        used_fallback = False
        if not text_body and html_body:
            soup = BeautifulSoup(html_body, "html.parser")
            text_body = soup.get_text(separator="\n").strip()
            used_fallback = True
        
        print(f"[{i+1}/{len(message_ids)}] ID: {msg_id}")
        print(f"Subject: {subject}")
        print(f"Top-level MimeType: {payload.get('mimeType')}")
        print(f"Parts Count: {len(payload.get('parts', []))}")
        print(f"Extracted Text Size: {len(text_body)} chars")
        print(f"Extracted HTML Size: {len(html_body)} chars")
        if used_fallback:
            print(f"Parsed text from HTML fallback.")
        
        # Print a snippet of the text_body to verify it's clean
        snippet = text_body[:200].replace('\n', ' ')
        print(f"Snippet: {snippet}...")
        
        print("-" * 60)
        
        if len(text_body) == 0 and len(html_body) == 0:
            print("WARNING: Genuinely empty body, missing parts, or undiscovered edge-case!")
        
    print("\nTest completed.")

if __name__ == "__main__":
    main()
