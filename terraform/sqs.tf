resource "aws_sqs_queue" "producer_queue" {
  name = "${var.project_name}-queue"

  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400  # 1 day
  receive_wait_time_seconds  = 10

  tags = {
    Project = var.project_name
  }
}