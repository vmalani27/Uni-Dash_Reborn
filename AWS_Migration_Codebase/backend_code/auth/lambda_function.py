import json
import os
import requests
import boto3
import traceback
from typing import Dict, Any, Optional

# --- SSM Parameter Cache ---
_ssm_cache = {}
ssm = boto3.client("ssm")


def get_param(name: str, decrypt: bool = False) -> str:
    """Fetch parameter from SSM with simple in-memory caching."""
    if name not in _ssm_cache:
        resp = ssm.get_parameter(Name=name, WithDecryption=decrypt)
        _ssm_cache[name] = resp["Parameter"]["Value"]
    return _ssm_cache[name]


# Load config at cold start
SUPABASE_URL = get_param("/unidash/dev/supabase/url", decrypt=False)
SUPABASE_KEY = get_param("/unidash/dev/supabase/sevice_key", decrypt=True)
ALLOWED_ORIGINS = get_param("/unidash/dev/allowed_origins").split(",")


# --- CORS ---
def get_cors_headers(origin: Optional[str]) -> Dict[str, str]:
    allowed = origin if origin in ALLOWED_ORIGINS else ALLOWED_ORIGINS[0]

    return {
        "Access-Control-Allow-Origin": allowed,
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "OPTIONS,POST,PUT,GET",
        "Access-Control-Max-Age": "86400",
    }


# --- Supabase Client ---
def supabase_request(
    method: str,
    path: str,
    data: Optional[Dict] = None,
    query: Optional[Dict] = None,
) -> Any:
    url = f"{SUPABASE_URL}/rest/v1/{path}"

    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
    }

    if method in ("POST", "PATCH", "PUT"):
        headers["Prefer"] = "return=representation"

    resp = requests.request(
        method,
        url,
        headers=headers,
        json=data,
        params=query,
        timeout=30,
    )

    if resp.status_code >= 400:
        raise Exception(f"Supabase {resp.status_code}: {resp.text}")

    # Handle empty response (e.g., PATCH 204 No Content)
    if not resp.text.strip():
        return {"_success": True}

    result = resp.json()

    return (
        result[0]
        if isinstance(result, list) and len(result) == 1
        else result
    )


# --- Normalize camelCase → snake_case ---
def normalize_input(body: Dict[str, Any]) -> Dict[str, Any]:
    mapping = {
        "fullName": "full_name",
        "admissionYear": "admission_year",
    }

    return {
        mapping.get(k, k): v
        for k, v in body.items()
    }


# --- Lambda Handler ---
def lambda_handler(event, context):
    origin = event.get("headers", {}).get("origin")
    cors = get_cors_headers(origin)

    # Preflight
    if (
        event.get("requestContext", {})
        .get("http", {})
        .get("method")
        == "OPTIONS"
    ):
        return {
            "statusCode": 204,
            "headers": cors,
            "body": "",
        }

    try:
        method = (
            event.get("httpMethod")
            or event["requestContext"]["http"]["method"]
        )

        claims = event["requestContext"]["authorizer"]["jwt"]["claims"]

        uid = claims["sub"]
        email = claims.get("email", "")

        # Parse body (GET requests will have empty body)
        raw_body = json.loads(event.get("body", "{}") or "{}")
        body = normalize_input(raw_body)

        # Fetch existing profile
        existing_list = supabase_request(
            "GET",
            "users",
            query={"uid": f"eq.{uid}"}
        )

        existing = (
            existing_list[0]
            if isinstance(existing_list, list) and existing_list
            else None
        )

        # ================= GET =================
        if method == "GET":
            if not existing:
                return {
                    "statusCode": 404,
                    "headers": cors,
                    "body": json.dumps({
                        "error": "User not found"
                    }),
                }

            return {
                "statusCode": 200,
                "headers": cors,
                "body": json.dumps(existing),
            }

        # ================= POST =================
        elif method == "POST":
            if existing:
                return {
                    "statusCode": 409,
                    "headers": cors,
                    "body": json.dumps({
                        "error": "User already exists"
                    }),
                }

            required_fields = [
                "full_name",
                "degree",
                "branch",
                "admission_year",
                "sid",
            ]

            for field in required_fields:
                if (
                    field not in body
                    or not str(body[field]).strip()
                ):
                    return {
                        "statusCode": 400,
                        "headers": cors,
                        "body": json.dumps({
                            "error": f"Missing field: {field}"
                        }),
                    }

            sid_value = body["sid"].strip().lower()

            sid_check = supabase_request(
                "GET",
                "users",
                query={"sid": f"eq.{sid_value}"}
            )

            if (
                sid_check
                and isinstance(sid_check, list)
                and sid_check
            ):
                return {
                    "statusCode": 409,
                    "headers": cors,
                    "body": json.dumps({
                        "error": "SID already registered"
                    }),
                }

            new_user = {
                "uid": uid,
                "email": email,
                "full_name": body["full_name"].strip(),
                "degree": body["degree"].strip(),
                "branch": body["branch"].strip(),
                "admission_year": int(body["admission_year"]),
                "sid": sid_value,
                "profile_completed": True,
                "oauth_connected": False,
                "reauth_required": False,
            }

            created = supabase_request(
                "POST",
                "users",
                data=new_user
            )

            return {
                "statusCode": 201,
                "headers": cors,
                "body": json.dumps(created),
            }

        # ================= PUT =================
        elif method == "PUT":
            if not existing:
                return {
                    "statusCode": 404,
                    "headers": cors,
                    "body": json.dumps({
                        "error": "User not found"
                    }),
                }

            for field in ["sid", "uid", "email"]:
                if (
                    field in body
                    and body[field] is not None
                    and body[field] != existing.get(field)
                ):
                    return {
                        "statusCode": 400,
                        "headers": cors,
                        "body": json.dumps({
                            "error": f"Field '{field}' cannot be updated"
                        }),
                    }

            allowed = [
                "full_name",
                "degree",
                "branch",
                "admission_year",
            ]

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
                        return {
                            "statusCode": 400,
                            "headers": cors,
                            "body": json.dumps({
                                "error": "Invalid admission_year"
                            }),
                        }

                elif isinstance(val, str):
                    val = val.strip()

                    if not val:
                        return {
                            "statusCode": 400,
                            "headers": cors,
                            "body": json.dumps({
                                "error": f"{field} cannot be empty"
                            }),
                        }

                update_data[field] = val

            if not update_data:
                return {
                    "statusCode": 200,
                    "headers": cors,
                    "body": json.dumps(existing),
                }

            updated = supabase_request(
                "PATCH",
                f"users?uid=eq.{uid}",
                data=update_data
            )

            # If PATCH returns empty success marker,
            # merge locally for consistent response
            if (
                isinstance(updated, dict)
                and updated.get("_success")
            ):
                updated_profile = {
                    **existing,
                    **update_data,
                }

                return {
                    "statusCode": 200,
                    "headers": cors,
                    "body": json.dumps(updated_profile),
                }

            return {
                "statusCode": 200,
                "headers": cors,
                "body": json.dumps(updated),
            }

        else:
            return {
                "statusCode": 405,
                "headers": cors,
                "body": json.dumps({
                    "error": "Method not allowed"
                }),
            }

    except KeyError:
        return {
            "statusCode": 401,
            "headers": cors,
            "body": json.dumps({
                "error": "Unauthorized"
            }),
        }

    except Exception as e:
        print(f"[LAMBDA_ERROR] {type(e).__name__}: {str(e)}")
        print(traceback.format_exc())

        return {
            "statusCode": 500,
            "headers": cors,
            "body": json.dumps({
                "error": "Internal server error"
            }),
        }