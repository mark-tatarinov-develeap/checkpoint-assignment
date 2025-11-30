module "ecs_service_consumer" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 6.10"

  name        = "${var.project_name}-consumer"
  cluster_arn = aws_ecs_cluster.this.arn

  requires_compatibilities = ["EC2"]
  launch_type              = "EC2"

  capacity_provider_strategy = {
    asg = {
      capacity_provider = aws_ecs_capacity_provider.ecs_asg.name
      weight            = 1
      base              = 1
    }
  }

  cpu    = 256
  memory = 512

  container_definitions = {
    consumer = {
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-west-2.amazonaws.com/consumer:${var.consumer_image_tag}"
      essential = true
      cpu       = 256
      memory    = 512

      environment = [
        { name = "SQS_QUEUE_URL", value = aws_sqs_queue.producer_queue.url },
        { name = "OUTPUT_BUCKET", value = aws_s3_bucket.messages.bucket }
      ]

      enable_cloudwatch_logging         = true
      create_cloudwatch_log_group       = true
      cloudwatch_log_group_name         = "/ecs/${var.project_name}/consumer"
      cloudwatch_log_group_retention_in_days = 3
    }
  }


  subnet_ids = module.vpc.private_subnets


  security_group_ingress_rules = {}

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  create_task_exec_iam_role = false
  task_exec_iam_role_arn    = aws_iam_role.ecs_task_execution.arn
  create_task_exec_policy   = false

  create_tasks_iam_role = false
  tasks_iam_role_arn    = aws_iam_role.consumer_task.arn

  tags = {
    Project = var.project_name
    Service = "consumer"
  }
}
