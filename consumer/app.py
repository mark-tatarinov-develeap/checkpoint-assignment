import os
import time
import json
import logging
from typing import List, Dict, Any

import boto3
from botocore.exceptions import ClientError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

SQS_QUEUE_URL = os.environ["SQS_QUEUE_URL"]
OUTPUT_BUCKET = os.environ["OUTPUT_BUCKET"]
AWS_REGION = os.environ.get("AWS_REGION", "us-west-2")
POLL_INTERVAL_SECONDS = int(os.environ.get("POLL_INTERVAL_SECONDS", "10"))

sqs = boto3.client("sqs", region_name=AWS_REGION)
s3 = boto3.client("s3", region_name=AWS_REGION)


def process_messages(messages: List[Dict[str, Any]]) -> None:
    """
    For each SQS message:
      - upload its body to S3 as JSON
      - delete the message from the queue
    """
    for msg in messages:
        body = msg["Body"]
        receipt_handle = msg["ReceiptHandle"]
        message_id = msg["MessageId"]

        # Decide on a key – for example:
        # emails/<message_id>.json
        key = f"emails/{message_id}.json"

        logger.info("Uploading message %s to s3://%s/%s", message_id, OUTPUT_BUCKET, key)

        try:
            s3.put_object(
                Bucket=OUTPUT_BUCKET,
                Key=key,
                Body=body.encode("utf-8"),
                ContentType="application/json",
            )
        except ClientError as e:
            logger.error("Failed to upload to S3 for message %s: %s", message_id, e, exc_info=True)
            # Do NOT delete message, so it can be retried later
            continue

        # Only delete the message if upload succeeded
        try:
            sqs.delete_message(
                QueueUrl=SQS_QUEUE_URL,
                ReceiptHandle=receipt_handle,
            )
            logger.info("Deleted message %s from SQS", message_id)
        except ClientError as e:
            logger.error("Failed to delete SQS message %s: %s", message_id, e, exc_info=True)


def poll_loop() -> None:
    """
    Poll SQS every X seconds and process messages.
    Checks the queue once per interval instead of aggressively long-polling.
    """
    logger.info(
        "Starting SQS consumer. Queue=%s, bucket=%s, poll_interval=%ss",
        SQS_QUEUE_URL,
        OUTPUT_BUCKET,
        POLL_INTERVAL_SECONDS,
    )

    while True:
        try:
            logger.info("Checking SQS queue for messages...")
            resp = sqs.receive_message(
                QueueUrl=SQS_QUEUE_URL,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=0,
            )
        except ClientError as e:
            logger.error("Error receiving messages from SQS: %s", e, exc_info=True)
            logger.info("Sleeping for %s seconds before next poll (after error)...", POLL_INTERVAL_SECONDS)
            time.sleep(POLL_INTERVAL_SECONDS)
            continue

        messages = resp.get("Messages", [])
        if not messages:
            logger.debug("No messages received from SQS.")
        else:
            logger.info("Received %d messages from SQS", len(messages))
            process_messages(messages)

        logger.debug("Sleeping for %s seconds before next poll...", POLL_INTERVAL_SECONDS)
        time.sleep(POLL_INTERVAL_SECONDS)



if __name__ == "__main__":
    poll_loop()
