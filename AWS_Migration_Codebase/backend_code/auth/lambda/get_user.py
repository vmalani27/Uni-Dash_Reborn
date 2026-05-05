import json
import requests
import os

# --- CONFIGURATION ---
# Removed Cognito variables as API Gateway handles verification now
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_SERVICE_KEY"]

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*", 
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
}

def supabase_request(method, path, query=None):
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
    }
    response = requests.request(method, url, headers=headers, params=query)
    if response.status_code >= 400:
        raise Exception(f"Supabase error: {response.text}")
    return response.json()

def lambda_handler(event, context):
    # Handle Preflight
    if event.get("requestContext", {}).get("http", {}).get("method") == "OPTIONS":
        return {"statusCode": 200, "headers": CORS_HEADERS}

    try:
        # GET USER ID FROM AUTHORIZER
        # API Gateway puts the decoded JWT claims here automatically
        authorizer_claims = event.get("requestContext", {}).get("authorizer", {}).get("jwt", {}).get("claims", {})
        uid = authorizer_claims.get("sub")

        if not uid:
            return {
                "statusCode": 403,
                "headers": CORS_HEADERS,
                "body": json.dumps({"error": "Unauthorized: No user context found"}),
            }

        # Query Supabase using the UID from Cognito
        users = supabase_request("GET", "users", query={"uid": f"eq.{uid}"})

        if not users:
            return {
                "statusCode": 404,
                "headers": CORS_HEADERS,
                "body": json.dumps({"error": "User not found in database"}),
            }

        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps(users[0]),
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": str(e)}),
        }
