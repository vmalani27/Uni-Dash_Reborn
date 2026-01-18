import requests

def fetch_gmail_messages(access_token: str, max_results: int = 20):
    headers = {"Authorization": f"Bearer {access_token}"}
    resp = requests.get(
        "https://gmail.googleapis.com/gmail/v1/users/me/messages",
        headers=headers,
        params={"maxResults": max_results},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json().get("messages", [])

def fetch_gmail_message_detail(access_token: str, msg_id: str):
    headers = {"Authorization": f"Bearer {access_token}"}
    resp = requests.get(
        f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{msg_id}",
        headers=headers,
        params={"format": "full"},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()

def extract_subject(msg):
    headers = msg.get("payload", {}).get("headers", [])
    for h in headers:
        if h["name"].lower() == "subject":
            return h["value"]
    return ""

def extract_sender(msg):
    headers = msg.get("payload", {}).get("headers", [])
    for h in headers:
        if h["name"].lower() == "from":
            return h["value"]
    return ""

def extract_body(msg):
    payload = msg.get("payload", {})
    if "body" in payload and payload["body"].get("data"):
        import base64
        import quopri
        data = payload["body"]["data"]
        try:
            return base64.urlsafe_b64decode(data + '===').decode(errors="ignore")
        except Exception:
            return quopri.decodestring(data).decode(errors="ignore")
    # If multipart
    for part in payload.get("parts", []):
        if part.get("mimeType", "").startswith("text/plain") and part.get("body", {}).get("data"):
            import base64
            try:
                return base64.urlsafe_b64decode(part["body"]["data"] + '===').decode(errors="ignore")
            except Exception:
                continue
    return ""

def extract_timestamp(msg):
    return msg.get("internalDate", "")

def normalize_gmail(msg):
    return {
        "source": "gmail",
        "id": msg.get("id"),
        "title": extract_subject(msg),
        "body": extract_body(msg),
        "sender": extract_sender(msg),
        "timestamp": extract_timestamp(msg),
    }
