import json
import os
import requests
import traceback
from typing import Dict, Any, Optional

# ENV
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_SERVICE_KEY"]
ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "http://localhost:3000").split(",")

# --- CORS ---
def get_cors_headers(origin: Optional[str]) -> Dict[str, str]:
    allowed_origin = origin if origin in ALLOWED_ORIGINS else ALLOWED_ORIGINS[0]
    return {
        "Access-Control-Allow-Origin": allowed_origin,
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "OPTIONS,POST,PUT",
        "Access-Control-Max-Age": "86400",
    }

# --- Supabase Client ---
def supabase_request(method: str, path: str, data: Optional[Dict] = None, query: Optional[Dict] = None) -> Any:
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }
    resp = requests.request(method, url, headers=headers, json=data, params=query, timeout=30)
    if resp.status_code >= 400:
        raise Exception(f"Supabase {resp.status_code}: {resp.text}")
    result = resp.json()
    return result[0] if isinstance(result, list) and len(result) == 1 else result

# --- Normalize camelCase → snake_case ---
def normalize_input(body: Dict[str, Any]) -> Dict[str, Any]:
    mapping = {"fullName": "full_name", "admissionYear": "admission_year"}
    return {mapping.get(k, k): v for k, v in body.items()}

# --- Lambda Handler ---
def lambda_handler(event, context):
    origin = event.get("headers", {}).get("origin")
    cors = get_cors_headers(origin)

    # OPTIONS preflight
    if event.get("requestContext", {}).get("http", {}).get("method") == "OPTIONS":
        return {"statusCode": 204, "headers": cors, "body": ""}

    try:
        method = event.get("httpMethod") or event["requestContext"]["http"]["method"]
        claims = event["requestContext"]["authorizer"]["jwt"]["claims"]
        uid = claims["sub"]
        email = claims.get("email", "")
        raw_body = json.loads(event.get("body", "{}") or "{}")
        body = normalize_input(raw_body)

        # Fetch existing profile
        existing_list = supabase_request("GET", "users", query={"uid": f"eq.{uid}"})
        existing = existing_list[0] if isinstance(existing_list, list) and existing_list else None

        # ================= POST: CREATE =================
        if method == "POST":
            if existing:
                return {"statusCode": 409, "headers": cors, "body": json.dumps({"error": "User already exists"})}

            # Required fields
            for field in ["full_name", "degree", "branch", "admission_year", "sid"]:
                if field not in body or not str(body[field]).strip():
                    return {"statusCode": 400, "headers": cors, "body": json.dumps({"error": f"Missing field: {field}"})}

            # SID uniqueness
            sid_check = supabase_request("GET", "users", query={"sid": f"eq.{body['sid'].strip().lower()}"})
            if sid_check and isinstance(sid_check, list) and sid_check:
                return {"statusCode": 409, "headers": cors, "body": json.dumps({"error": "SID already registered"})}

            new_user = {
                "uid": uid,
                "email": email,
                "full_name": body["full_name"].strip(),
                "degree": body["degree"].strip(),
                "branch": body["branch"].strip(),
                "admission_year": int(body["admission_year"]),
                "sid": body["sid"].strip().lower(),
                "profile_completed": True,
                "oauth_connected": False,
                "reauth_required": False,
            }
            created = supabase_request("POST", "users", data=new_user)
            return {"statusCode": 201, "headers": cors, "body": json.dumps(created)}

        # ================= PUT: UPDATE =================
        elif method == "PUT":
            if not existing:
                return {"statusCode": 404, "headers": cors, "body": json.dumps({"error": "User not found"})}

            # Immutable fields: reject if changed
            for field in ["sid", "uid", "email"]:
                if field in body and body[field] is not None and body[field] != existing.get(field):
                    return {"statusCode": 400, "headers": cors, "body": json.dumps({"error": f"Field '{field}' cannot be updated"})}

            # Mutable fields only
            allowed = ["full_name", "degree", "branch", "admission_year"]
            update_data = {}
            for field in allowed:
                if field not in body:
                    continue

                val = body[field]
                if val is None:
                    continue

                if field == "admission_year":
                    try:
                        val = int(val)
                        if not (1900 <= val <= 2100):
                            raise ValueError
                    except Exception:
                        return {"statusCode": 400, "headers": cors, "body": json.dumps({"error": "Invalid admission_year"})}
                elif isinstance(val, str):
                    val = val.strip()
                    if not val:
                        return {"statusCode": 400, "headers": cors, "body": json.dumps({"error": f"{field} cannot be empty"})}

                update_data[field] = val

            if not update_data:
                return {"statusCode": 200, "headers": cors, "body": json.dumps(existing)}

            updated = supabase_request("PATCH", f"users?uid=eq.{uid}", data=update_data)
            return {"statusCode": 200, "headers": cors, "body": json.dumps(updated)}

        else:
            return {"statusCode": 405, "headers": cors, "body": json.dumps({"error": "Method not allowed"})}

    except KeyError:
        return {"statusCode": 401, "headers": cors, "body": json.dumps({"error": "Unauthorized"})}
    except Exception as e:
        print(f"[LAMBDA_ERROR] {type(e).__name__}: {str(e)}")
        print(traceback.format_exc())
        return {"statusCode": 500, "headers": cors, "body": json.dumps({"error": "Internal server error"})}