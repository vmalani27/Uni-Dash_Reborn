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

def parse_gmail_payload(payload):
    """
    Recursively extract text/plain and text/html from a Gmail MIME payload.
    """
    import base64
    import quopri

    text_body = ""
    html_body = ""
    
    def decode_data(data):
        if not data:
            return ""
        try:
            # Gmail uses URL-safe base64 encoding. Padding is required.
            return base64.urlsafe_b64decode(data + '===').decode(errors="ignore")
        except Exception:
            try:
                return quopri.decodestring(data).decode(errors="ignore")
            except Exception:
                return ""

    mime_type = payload.get("mimeType", "")
    data = payload.get("body", {}).get("data", "")
    
    if mime_type == "text/plain" and data:
        text_body = decode_data(data)
    elif mime_type == "text/html" and data:
        html_body = decode_data(data)
        
    for part in payload.get("parts", []):
        t, h = parse_gmail_payload(part)
        if t: text_body += t + "\n"
        if h: html_body += h + "\n"
        
    return text_body.strip(), html_body.strip()

def extract_body(msg):
    payload = msg.get("payload", {})
    text, _ = parse_gmail_payload(payload)
    return text

def extract_timestamp(msg):
    return msg.get("internalDate", "")


def extract_headers_map(msg_or_payload):
    """
    Safely extract headers from a Gmail message or payload and return a dict mapping
    header name -> value. Header names are returned with their original case but
    lookups should generally be case-insensitive.
    """
    headers = []
    # msg_or_payload may be a full message dict or a payload dict
    if isinstance(msg_or_payload, dict):
        # Try payload.headers first
        payload = msg_or_payload.get("payload") if "payload" in msg_or_payload else msg_or_payload
        headers = payload.get("headers", []) if payload else []

    result = {}
    for h in headers:
        try:
            name = h.get("name")
            value = h.get("value")
            if name:
                result[name] = value
        except Exception:
            continue

    return result

def normalize_gmail(msg):
    return {
        "source": "gmail",
        "id": msg.get("id"),
        "title": extract_subject(msg),
        "body": extract_body(msg),
        "sender": extract_sender(msg),
        "timestamp": extract_timestamp(msg),
    }
