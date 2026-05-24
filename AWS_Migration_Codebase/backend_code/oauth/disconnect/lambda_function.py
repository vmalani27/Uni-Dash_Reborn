import json
import boto3
import requests
from cryptography.fernet import Fernet
from typing import Optional, Dict

_ssm_cache = {}
ssm = boto3.client("ssm")

def get_param(name: str, decrypt: bool = False) -> str:
    if name not in _ssm_cache:
        resp = ssm.get_parameter(Name=name, WithDecryption=decrypt)
        _ssm_cache[name] = resp["Parameter"]["Value"]
    return _ssm_cache[name]

SUPABASE_URL  = get_param("/unidash/dev/supabase/url")
SUPABASE_KEY  = get_param("/unidash/dev/supabase/service_key", decrypt=True)
FERNET_KEY    = get_param("/unidash/dev/fernet_key", decrypt=True)
ALLOWED_ORIGINS = get_param("/unidash/dev/allowed_origins").split(",")

GOOGLE_REVOKE_URL = "https://oauth2.googleapis.com/revoke"
GMAIL_STOP_URL    = "https://gmail.googleapis.com/gmail/v1/users/me/stop"

fernet = Fernet(FERNET_KEY.encode())

def decrypt_token(encrypted: str) -> str:
    return fernet.decrypt(encrypted.encode()).decode()

def get_cors_headers(origin: Optional[str]) -> Dict[str, str]:
    allowed = origin if origin in ALLOWED_ORIGINS else ALLOWED_ORIGINS[0]
    return {
        "Access-Control-Allow-Origin": allowed,
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "OPTIONS,POST",
        "Access-Control-Max-Age": "86400",
    }

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
    origin = (event.get("headers") or {}).get("origin")
    cors = get_cors_headers(origin)

    method = (event.get("requestContext") or {}).get("http", {}).get("method", "")
    if method == "OPTIONS":
        return {"statusCode": 204, "headers": cors, "body": ""}

    try:
        claims = event["requestContext"]["authorizer"]["jwt"]["claims"]
        uid = claims["sub"]

        # Fetch stored token
        rows = supabase_request("GET", "oauth_tokens", query={"uid": f"eq.{uid}"})
        token_row = rows[0] if isinstance(rows, list) and rows else None

        watch_stopped = False
        revoked = False

        if token_row and token_row.get("refresh_token"):
            try:
                plain_refresh = decrypt_token(token_row["refresh_token"])

                # Get a fresh access token to stop the watch
                # (refresh token can be used to get access token for stop call)
                # We attempt stop first, then revoke
                revoke_resp = requests.post(
                    GOOGLE_REVOKE_URL,
                    params={"token": plain_refresh},
                    headers={"content-type": "application/x-www-form-urlencoded"},
                    timeout=10,
                )
                revoked = revoke_resp.status_code == 200

            except Exception as e:
                print(f"[oauth/disconnect] Revoke failed for uid={uid}: {e}")

        # Clear watch fields in gmail_sync_status
        try:
            supabase_request("PATCH", f"gmail_sync_status?uid=eq.{uid}", data={
                "last_history_id": None,
                "watch_expiration": None,
            })
        except Exception:
            pass

        # Delete oauth token row
        if token_row:
            supabase_request("DELETE", f"oauth_tokens?uid=eq.{uid}")

        # Reset user flags
        supabase_request("PATCH", f"users?uid=eq.{uid}", data={
            "oauth_connected": False,
            "reauth_required": False,
        })

        return {
            "statusCode": 200,
            "headers": cors,
            "body": json.dumps({
                "status": "disconnected",
                "google_revoked": revoked,
            }),
        }

    except KeyError:
        return {"statusCode": 401, "headers": cors, "body": json.dumps({"error": "Unauthorized"})}
    except Exception as e:
        print(f"[oauth/disconnect] {type(e).__name__}: {e}")
        return {"statusCode": 500, "headers": cors, "body": json.dumps({"error": "Internal server error"})}
