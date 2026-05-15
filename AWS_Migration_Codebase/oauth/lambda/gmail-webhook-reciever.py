import json
import base64
import os
import logging
import boto3
from typing import Dict, Any, Optional

# Configure logging for CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients (reused across warm invocations)
sqs = boto3.client("sqs")

# Environment variables
SQS_QUEUE_URL = os.environ["GMAIL_SYNC_QUEUE_URL"]
ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "*").split(",")

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    # CORS headers (API Gateway HTTP API can also handle this natively)
    origin = event.get("headers", {}).get("origin", "")
    allowed_origin = origin if origin in ALLOWED_ORIGINS else ALLOWED_ORIGINS[0]
    cors_headers = {
        "Access-Control-Allow-Origin": allowed_origin,
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "POST,OPTIONS",
    }

    # Handle OPTIONS preflight
    http_method = event.get("requestContext", {}).get("http", {}).get("method", "").upper()
    if http_method == "OPTIONS":
        return {"statusCode": 204, "headers": cors_headers, "body": ""}

    # Parse request body
    try:
        body = json.loads(event.get("body", "{}"))
    except json.JSONDecodeError:
        logger.warning("Invalid JSON received")
        return {"statusCode": 400, "headers": cors_headers, "body": "Invalid JSON"}

    # Google sends a verification challenge without a "message" key
    if "message" not in body:
        logger.info("Received verification/keepalive request from Google")
        return {"statusCode": 200, "headers": cors_headers, "body": "OK"}

    try:
        message = body["message"]
        data_b64 = message.get("data", "")
        message_id = message.get("messageId", "unknown")

        # Decode base64 payload
        if data_b64:
            decoded_data = base64.b64decode(data_b64).decode("utf-8")
            payload = json.loads(decoded_data)
        else:
            payload = {}

        # Extract UID from attributes or payload
        attributes = message.get("attributes", {})
        uid = attributes.get("uid") or payload.get("uid")
        email_address = payload.get("emailAddress")

        # Fallback: resolve UID from email if missing
        if not uid and email_address:
            uid = _resolve_uid_from_email(email_address)

        if not uid:
            logger.warning(f"Message {message_id} has no resolvable UID. Acknowledging to prevent redelivery.")
            return {"statusCode": 200, "headers": cors_headers, "body": "OK"}

        history_id = payload.get("historyId")
        logger.info(f"Gmail notification for UID: {uid[:8]}... | historyId: {history_id} | messageId: {message_id}")

        # Queue for async processing
        sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps({
                "uid": uid,
                "payload": payload,
                "message_id": message_id
            }),
            MessageAttributes={
                "uid": {"DataType": "String", "StringValue": uid}
            }
        )

        return {"statusCode": 200, "headers": cors_headers, "body": "OK"}

    except Exception as e:
        logger.error(f"Webhook processing error: {str(e)}")
        # Always return 200 to ACK. Returning 4xx/5xx causes Google to retry indefinitely.
        return {"statusCode": 200, "headers": cors_headers, "body": "OK"}


def _resolve_uid_from_email(email: str) -> Optional[str]:
    """
    Stub: Query Supabase to resolve UID from email.
    For now, we rely on UID being passed in Pub/Sub attributes.
    Add Supabase query here only if you can't guarantee UID in attributes.
    """
    logger.debug(f"UID resolution stub called for: {email}")
    return None