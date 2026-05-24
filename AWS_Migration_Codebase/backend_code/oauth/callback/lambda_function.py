import json
import datetime
import boto3
import requests
from cryptography.fernet import Fernet
from typing import Optional, Dict

# --- SSM Cache ---
_ssm_cache = {}
ssm = boto3.client("ssm")

def get_param(name: str, decrypt: bool = False) -> str:
    if name not in _ssm_cache:
        resp = ssm.get_parameter(Name=name, WithDecryption=decrypt)
        _ssm_cache[name] = resp["Parameter"]["Value"]
    return _ssm_cache[name]

SUPABASE_URL     = get_param("/unidash/dev/supabase/url")
SUPABASE_KEY     = get_param("/unidash/dev/supabase/service_key", decrypt=True)
GCP_CLIENT_ID    = get_param("/unidash/dev/gcp/client_id", decrypt=True)
GCP_CLIENT_SECRET = get_param("/unidash/dev/gcp/client_secret", decrypt=True)
FERNET_KEY       = get_param("/unidash/dev/fernet_key", decrypt=True)
FRONTEND_URL     = get_param("/unidash/dev/frontend_url")
PUBSUB_TOPIC     = get_param("/unidash/dev/pubsub_topic")  # projects/f-r-i-d-a-y-vlelfh/topics/gmail-notifications

TOKEN_URL        = "https://oauth2.googleapis.com/token"
USERINFO_URL     = "https://www.googleapis.com/oauth2/v2/userinfo"
GMAIL_WATCH_URL  = "https://gmail.googleapis.com/gmail/v1/users/me/watch"

fernet = Fernet(FERNET_KEY.encode())


def encrypt_token(token: str) -> str:
    return fernet.encrypt(token.encode()).decode()


def supabase_request(method, path, data=None, query=None):
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
    }
    if method in ("POST", "PATCH"):
        headers["Prefer"] = "return=representation"
    resp = requests.request(method, url, headers=headers, json=data, params=query, timeout=15)
    if resp.status_code >= 400:
        raise Exception(f"Supabase {resp.status_code}: {resp.text}")
    return resp.json() if resp.text.strip() else {"_success": True}


def start_gmail_watch(access_token: str, uid: str) -> Optional[str]:
    """Register gmail.watch() so GCP Pub/Sub pushes new mail notifications."""
    resp = requests.post(
        GMAIL_WATCH_URL,
        headers={"Authorization": f"Bearer {access_token}"},
        json={
            "labelIds": ["INBOX"],
            "topicName": PUBSUB_TOPIC,
        },
        timeout=10,
    )
    if resp.status_code != 200:
        print(f"[oauth/callback] gmail.watch failed for uid={uid}: {resp.text}")
        return None

    data = resp.json()
    history_id = data.get("historyId")
    expiration_ms = data.get("expiration")

    # Update gmail_sync_status with watch details
    expiry_dt = None
    if expiration_ms:
        expiry_dt = datetime.datetime.utcfromtimestamp(int(expiration_ms) / 1000).isoformat()

    existing = supabase_request("GET", "gmail_sync_status", query={"uid": f"eq.{uid}"})
    if isinstance(existing, list) and existing:
        supabase_request(
            "PATCH",
            f"gmail_sync_status?uid=eq.{uid}",
            data={
                "last_history_id": str(history_id) if history_id else None,
                "watch_expiration": expiry_dt,
            }
        )
    else:
        supabase_request(
            "POST",
            "gmail_sync_status",
            data={
                "uid": uid,
                "last_history_id": str(history_id) if history_id else None,
                "watch_expiration": expiry_dt,
                "sync_type": "watch",
            }
        )

    return str(history_id) if history_id else None


def lambda_handler(event, context):
    """
    Google redirects here with ?code=...&state=...
    This is a GET with NO Authorization header — it's an open redirect endpoint.
    We validate via the state token stored in Supabase.
    """
    params = event.get("queryStringParameters") or {}
    code  = params.get("code")
    state = params.get("state")
    error = params.get("error")

    redirect_base = f"{FRONTEND_URL}/dashboard"
    error_redirect = f"{FRONTEND_URL}/connect-gmail?error="

    if error:
        return {"statusCode": 302, "headers": {"Location": f"{error_redirect}google_denied"}, "body": ""}

    if not code or not state:
        return {"statusCode": 302, "headers": {"Location": f"{error_redirect}missing_params"}, "body": ""}

    try:
        # Validate state — look it up in oauth_states table
        state_rows = supabase_request("GET", "oauth_states", query={"state": f"eq.{state}"})
        if not isinstance(state_rows, list) or not state_rows:
            return {"statusCode": 302, "headers": {"Location": f"{error_redirect}invalid_state"}, "body": ""}

        state_row = state_rows[0]
        uid = state_row["uid"]

        # Delete used state immediately (one-time use)
        supabase_request("DELETE", f"oauth_states?state=eq.{state}")

        # Exchange code for tokens
        redirect_uri = f"{FRONTEND_URL}/auth/google/callback"
        token_resp = requests.post(
            TOKEN_URL,
            data={
                "client_id": GCP_CLIENT_ID,
                "client_secret": GCP_CLIENT_SECRET,
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": redirect_uri,
            },
            timeout=10,
        )
        if token_resp.status_code != 200:
            print(f"[oauth/callback] Token exchange failed: {token_resp.text}")
            return {"statusCode": 302, "headers": {"Location": f"{error_redirect}token_exchange_failed"}, "body": ""}

        token_data    = token_resp.json()
        access_token  = token_data.get("access_token")
        refresh_token = token_data.get("refresh_token")
        expires_in    = token_data.get("expires_in")
        scopes        = token_data.get("scope")

        # Fetch Google email
        userinfo_resp = requests.get(
            USERINFO_URL,
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=10,
        )
        if userinfo_resp.status_code != 200:
            return {"statusCode": 302, "headers": {"Location": f"{error_redirect}userinfo_failed"}, "body": ""}

        gmail_email = userinfo_resp.json().get("email")

        # Calculate expiry
        expires_at = None
        if expires_in:
            expires_at = (
                datetime.datetime.utcnow() + datetime.timedelta(seconds=int(expires_in))
            ).isoformat()

        # Upsert oauth_tokens
        existing_token = supabase_request("GET", "oauth_tokens", query={"uid": f"eq.{uid}"})
        has_existing   = isinstance(existing_token, list) and existing_token

        if has_existing:
            patch_data = {
                "email": gmail_email,
                "expires_at": expires_at,
                "scopes": scopes,
                "updated_at": datetime.datetime.utcnow().isoformat(),
            }
            if refresh_token:
                patch_data["refresh_token"] = encrypt_token(refresh_token)
            supabase_request("PATCH", f"oauth_tokens?uid=eq.{uid}", data=patch_data)
        else:
            if not refresh_token:
                return {"statusCode": 302, "headers": {"Location": f"{error_redirect}no_refresh_token"}, "body": ""}
            supabase_request("POST", "oauth_tokens", data={
                "uid": uid,
                "email": gmail_email,
                "refresh_token": encrypt_token(refresh_token),
                "scopes": scopes,
                "expires_at": expires_at,
                "token_type": "Bearer",
                "created_at": datetime.datetime.utcnow().isoformat(),
                "updated_at": datetime.datetime.utcnow().isoformat(),
            })

        # Update user oauth_connected flag
        supabase_request("PATCH", f"users?uid=eq.{uid}", data={
            "oauth_connected": True,
            "reauth_required": False,
        })

        # Start Gmail watch for Pub/Sub push notifications
        start_gmail_watch(access_token, uid)

        return {
            "statusCode": 302,
            "headers": {"Location": redirect_base},
            "body": "",
        }

    except Exception as e:
        print(f"[oauth/callback] {type(e).__name__}: {e}")
        return {
            "statusCode": 302,
            "headers": {"Location": f"{error_redirect}server_error"},
            "body": "",
        }
