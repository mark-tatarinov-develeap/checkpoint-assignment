import os
import logging
from typing import Dict, Any

from flask import Flask, request, jsonify
import boto3
from botocore.exceptions import ClientError


app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

SQS_QUEUE_URL = os.environ["SQS_QUEUE_URL"]
TOKEN_PARAM_NAME = os.environ["TOKEN_PARAM_NAME"]
AWS_REGION = os.environ.get("AWS_REGION", "us-west-2")

sqs = boto3.client("sqs", region_name=AWS_REGION)
ssm = boto3.client("ssm", region_name=AWS_REGION)

_cached_token: str | None = None


def get_expected_token() -> str:
    try:
        resp = ssm.get_parameter(
            Name=TOKEN_PARAM_NAME,
            WithDecryption=True,
        )
        token = resp["Parameter"]["Value"]
        logger.info("Successfully loaded token from SSM parameter %s", TOKEN_PARAM_NAME)
        return token
    except ClientError as e:
        logger.error("Failed to get token from SSM: %s", e, exc_info=True)
        raise



def validate_payload(payload: Dict[str, Any]) -> tuple[bool, str]:
    """
    Validate:
      - top-level keys: "data" and "token"
      - token correctness against SSM
      - 'data' has the required 4 text fields
    """
    if not isinstance(payload, dict):
        return False, "Payload must be a JSON object"

    if "data" not in payload or "token" not in payload:
        return False, 'Payload must contain "data" and "token" fields'

    data = payload["data"]
    token = payload["token"]

    if not isinstance(data, dict):
        return False, '"data" must be an object'

    required_fields = [
        "email_subject",
        "email_sender",
        "email_timestream",
        "email_content",
    ]

    for field in required_fields:
        if field not in data:
            return False, f'Missing required field in "data": {field}'
        if not isinstance(data[field], str) or not data[field].strip():
            return False, f'Field "{field}" must be a non-empty string'

    # Validate timestream is numeric
    if not data["email_timestream"].isdigit():
        return False, '"email_timestream" must be a numeric string (Unix timestamp)'

    try:
        expected_token = get_expected_token()
    except Exception:
        return False, "Failed to load token from SSM"

    if token != expected_token:
        return False, "Invalid token"

    return True, ""


def send_to_sqs(payload: Dict[str, Any]) -> None:
    """
    Send the payload as JSON string to SQS.
    """
    import json

    body = json.dumps(payload)
    try:
        resp = sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=body,
        )
        logger.info("Sent message to SQS. MessageId=%s", resp.get("MessageId"))
    except ClientError as e:
        logger.error("Failed to send message to SQS: %s", e, exc_info=True)
        raise




@app.route("/health", methods=["GET"])
def health():
    """
    ALB health check endpoint.
    """
    return jsonify({"status": "ok"}), 200


@app.route("/process", methods=["POST"])
def process():
    ...
    payload = request.get_json(silent=True)
    is_valid, error_msg = validate_payload(payload)

    if not is_valid:
        logger.warning("Invalid payload: %s", error_msg)
        return jsonify({"error": error_msg}), 400

    try:
        # ⬇ send only the data section
        send_to_sqs(payload["data"])
    except Exception:
        return jsonify({"error": "Failed to publish message to SQS"}), 500

    return jsonify({"status": "accepted"}), 202



if __name__ == "__main__":
    # Flask will listen on 0.0.0.0:80 so ECS/ALB can reach it
    app.run(host="0.0.0.0", port=80)
