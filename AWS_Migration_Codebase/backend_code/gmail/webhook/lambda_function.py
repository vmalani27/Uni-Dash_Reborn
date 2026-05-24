import json
import base64
import boto3
import requests
from typing import Optional

_ssm_cache = {}
ssm = boto3.client("ssm")

def get_param(name: str, decrypt: bool = False) -> str:
    if name not in _ssm_cache:
        resp = ssm.get_parameter(Name=name, WithDecryption=decrypt)
        _ssm_cache[name] = resp["Parameter"]["Value"]
    return _ssm_cache[name]

SUPABASE_URL = get_param("/unidash/dev/supabase/url")
SUPABASE_KEY = get_param("/unidash/dev/supabase/service_key", decrypt=True)
# A shared secret you'll add as ?token=xxx in the Pub/Sub push subscription URL
# This prevents random internet traffic from triggering your webhook
WEBHOOK_SECRET = get_param("/unidash/dev/webhook_secret", decrypt=True)


def supabase_request(method, path, data=None, query=None):
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
    }
    if method in ("POST", "PATCH"):
        headers["Prefer"] = "return=representation"
    resp = requests.request(method, url, headers=headers, json=data, params=query, timeout=10)
    if resp.status_code >= 400:
        raise Exception(f"Supabase {resp.status_code}: {resp.text}")
    return resp.json() if resp.text.strip() else {"_success": True}


def lambda_handler(event, context):
    """
    Receives Pub/Sub push notifications from Google when new Gmail arrives.
    Pub/Sub expects HTTP 200 to acknowledge. Non-200 triggers a retry.

    Flow:
    1. Validate webhook secret in query string
    2. Decode the Pub/Sub message (base64 JSON)
    3. Extract emailAddress + historyId
    4. Look up user by Gmail email in oauth_tokens
    5. Update gmail_sync_status.last_history_id
       (actual email fetching happens in a separate sync Lambda — keep this fast)
    """

    # Validate secret token in query string
    query_params = event.get("queryStringParameters") or {}
    incoming_secret = query_params.get("token", "")
    if incoming_secret != WEBHOOK_SECRET:
        print("[gmail/webhook] Invalid webhook secret")
        # Return 200 anyway to stop Pub/Sub retrying with bad requests
        return {"statusCode": 200, "body": ""}

    try:
        body = json.loads(event.get("body") or "{}")
        message = body.get("message", {})

        if not message:
            print("[gmail/webhook] No message in payload")
            return {"statusCode": 200, "body": ""}

        # Pub/Sub message data is base64-encoded JSON
        raw_data = message.get("data", "")
        if not raw_data:
            return {"statusCode": 200, "body": ""}

        decoded = json.loads(base64.b64decode(raw_data).decode("utf-8"))
        email_address = decoded.get("emailAddress")
        history_id    = decoded.get("historyId")

        print(f"[gmail/webhook] Notification for {email_address}, historyId={history_id}")

        if not email_address or not history_id:
            return {"statusCode": 200, "body": ""}

        # Find user by Gmail email stored in oauth_tokens
        rows = supabase_request("GET", "oauth_tokens", query={"email": f"eq.{email_address}"})
        if not isinstance(rows, list) or not rows:
            print(f"[gmail/webhook] No user found for email {email_address}")
            return {"statusCode": 200, "body": ""}

        uid = rows[0]["uid"]

        # Update last_history_id so the sync Lambda knows where to start
        existing_status = supabase_request("GET", "gmail_sync_status", query={"uid": f"eq.{uid}"})
        if isinstance(existing_status, list) and existing_status:
            supabase_request("PATCH", f"gmail_sync_status?uid=eq.{uid}", data={
                "last_history_id": str(history_id),
            })
        else:
            supabase_request("POST", "gmail_sync_status", data={
                "uid": uid,
                "last_history_id": str(history_id),
                "sync_type": "push",
            })

        print(f"[gmail/webhook] Updated history_id={history_id} for uid={uid}")
        return {"statusCode": 200, "body": ""}

    except Exception as e:
        print(f"[gmail/webhook] {type(e).__name__}: {e}")
        # Always return 200 to Pub/Sub — non-200 causes exponential retries
        return {"statusCode": 200, "body": ""}
