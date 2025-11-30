module "ecs_service_producer" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 6.10"

  name        = "${var.project_name}-producer"
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
    producer = {
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-west-2.amazonaws.com/producer:${var.consumer_image_tag}"
      essential = true
      cpu       = 256
      memory    = 512

      portMappings = [
        {
          name          = "http"
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "SQS_QUEUE_URL", value = aws_sqs_queue.producer_queue.url },
        { name = "TOKEN_SSM_PATH", value = var.token_ssm_path }
      ]

      enable_cloudwatch_logging         = true
      create_cloudwatch_log_group       = true
      cloudwatch_log_group_name         = "/ecs/${var.project_name}/producer"
      cloudwatch_log_group_retention_in_days = 3
    }
  }

  load_balancer = {
    service = {
      target_group_arn = module.alb.target_groups["producer"].arn
      container_name   = "producer"
      container_port   = 80
    }
  }

  subnet_ids = module.vpc.private_subnets

  security_group_ingress_rules = {
    alb_http = {
      description                = "Allow HTTP from ALB"
      from_port                  = 80
      ip_protocol                = "tcp"
      referenced_security_group_id = module.alb.security_group_id
    }
  }

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
  tasks_iam_role_arn    = aws_iam_role.producer_task.arn

  tags = {
    Project = var.project_name
    Service = "producer"
  }
}
