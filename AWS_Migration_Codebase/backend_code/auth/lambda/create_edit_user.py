import json
import os
import requests

# ENV
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_SERVICE_KEY"]

# --- CORS SETTINGS ---
CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*", # Replace with http://localhost:3000 for better security
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "OPTIONS,POST,PUT,GET"
}

# ---------------------------
# SUPABASE
# ---------------------------
def supabase_request(method, path, data=None, query=None):
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }
    response = requests.request(method, url, headers=headers, json=data, params=query)
    if response.status_code >= 400:
        raise Exception(response.text)
    return response.json()

def lambda_handler(event, context):
    # 1. Handle CORS Preflight (OPTIONS)
    if event.get("requestContext", {}).get("http", {}).get("method") == "OPTIONS":
        return {
            "statusCode": 204, # No Content is standard for OPTIONS
            "headers": CORS_HEADERS,
            "body": ""
        }

    try:
        # HTTP API method extraction
        method = (
            event.get("httpMethod")
            or event.get("requestContext", {}).get("http", {}).get("method")
        )

        # Get claims from API Gateway JWT authorizer
        claims = event["requestContext"]["authorizer"]["jwt"]["claims"]
        uid = claims["sub"]
        email = claims.get("email", "")

        body = json.loads(event.get("body", "{}") or "{}")

        # Field validation
        if method == "POST":
            required_fields = ["full_name", "degree", "branch", "admission_year", "sid"]
        else:
            required_fields = ["full_name", "degree", "branch", "admission_year"]

        for field in required_fields:
            if field not in body:
                return {
                    "statusCode": 400,
                    "headers": CORS_HEADERS,
                    "body": json.dumps({"error": f"Missing field: {field}"}),
                }

        # Check if user exists
        existing = supabase_request("GET", "users", query={"uid": f"eq.{uid}"})

        # ---------------------------
        # POST → CREATE
        # ---------------------------
        if method == "POST":
            if existing:
                return {
                    "statusCode": 409,
                    "headers": CORS_HEADERS,
                    "body": json.dumps({"error": "User already exists"}),
                }

            if not body.get("sid"):
                return {
                    "statusCode": 400,
                    "headers": CORS_HEADERS,
                    "body": json.dumps({"error": "SID is required and cannot be empty"}),
                }

            new_user = {
                "uid": uid,
                "email": email,
                "full_name": body["full_name"],
                "degree": body["degree"],
                "branch": body["branch"],
                "admission_year": body["admission_year"],
                "sid": body["sid"],
                "profile_completed": True,
                "oauth_connected": False,
                "reauth_required": False
            }

            created = supabase_request("POST", "users", data=new_user)
            return {
                "statusCode": 201,
                "headers": CORS_HEADERS,
                "body": json.dumps(created[0]),
            }

        # ---------------------------
        # PUT → UPDATE
        # ---------------------------
        elif method == "PUT":
            if not existing:
                return {
                    "statusCode": 404,
                    "headers": CORS_HEADERS,
                    "body": json.dumps({"error": "User not found"}),
                }

            if "sid" in body:
                return {
                    "statusCode": 400,
                    "headers": CORS_HEADERS,
                    "body": json.dumps({"error": "SID cannot be updated"}),
                }

            update_data = {
                "full_name": body["full_name"],
                "degree": body["degree"],
                "branch": body["branch"],
                "admission_year": body["admission_year"],
            }

            updated = supabase_request("PATCH", "users", data=update_data, query={"uid": f"eq.{uid}"})
            return {
                "statusCode": 200,
                "headers": CORS_HEADERS,
                "body": json.dumps(updated[0]),
            }

        else:
            return {
                "statusCode": 405,
                "headers": CORS_HEADERS,
                "body": json.dumps({"error": "Method not allowed"}),
            }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": str(e)}),
        }
