import json
import datetime
import os
import secrets
import urllib.parse
import boto3
from typing import Optional, Dict

# --- SSM Cache ---
_ssm_cache = {}
ssm = boto3.client("ssm")

def get_param(name: str, decrypt: bool = False) -> str:
    if name not in _ssm_cache:
        resp = ssm.get_parameter(Name=name, WithDecryption=decrypt)
        _ssm_cache[name] = resp["Parameter"]["Value"]
    return _ssm_cache[name]

# Cold start config
SUPABASE_URL     = get_param("/unidash/dev/supabase/url")
SUPABASE_KEY     = get_param("/unidash/dev/supabase/service_key", decrypt=True)
GCP_CLIENT_ID    = get_param("/unidash/dev/gcp/client_id", decrypt=True)
ALLOWED_ORIGINS  = get_param("/unidash/dev/allowed_origins").split(",")
FRONTEND_URL     = get_param("/unidash/dev/frontend_url")

GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"

SCOPES = [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/classroom.courses.readonly",
    "https://www.googleapis.com/auth/classroom.announcements.readonly",
    "https://www.googleapis.com/auth/classroom.coursework.students.readonly",
    "openid",
    "email",
    "profile",
]

import requests

def get_cors_headers(origin: Optional[str]) -> Dict[str, str]:
    allowed = origin if origin in ALLOWED_ORIGINS else ALLOWED_ORIGINS[0]
    return {
        "Access-Control-Allow-Origin": allowed,
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "OPTIONS,GET",
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

    # Preflight
    method = (event.get("requestContext") or {}).get("http", {}).get("method", "")
    if method == "OPTIONS":
        return {"statusCode": 204, "headers": cors, "body": ""}

    try:
        claims = event["requestContext"]["authorizer"]["jwt"]["claims"]
        uid = claims["sub"]

        # Generate a secure random state token
        state = secrets.token_urlsafe(32)
        expires_at = (
            datetime.datetime.utcnow()
            + datetime.timedelta(minutes=10)
        ).isoformat()

        # Store state in Supabase oauth_states table
        # uid + state allows us to look up who initiated the flow in the callback
        supabase_request(
            "POST",
            "oauth_states",
            data={
                "uid": uid,
                "state": state,
                "expires_at": expires_at,
            }
        )

        # Build the redirect URI — this must match exactly what's registered in GCP Console
        redirect_uri = f"{FRONTEND_URL}/auth/google/callback"

        params = {
            "client_id": GCP_CLIENT_ID,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": " ".join(SCOPES),
            "access_type": "offline",
            "prompt": "consent",   # force consent so we always get a refresh_token
            "state": state,
        }

        auth_url = GOOGLE_AUTH_URL + "?" + urllib.parse.urlencode(params)

        return {
            "statusCode": 200,
            "headers": cors,
            "body": json.dumps({"auth_url": auth_url}),
        }

    except KeyError:
        return {"statusCode": 401, "headers": cors, "body": json.dumps({"error": "Unauthorized"})}
    except Exception as e:
        print(f"[oauth/url] {type(e).__name__}: {e}")
        return {"statusCode": 500, "headers": cors, "body": json.dumps({"error": "Internal server error"})}
