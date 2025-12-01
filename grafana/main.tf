module "ecs_service_grafana" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 6.10"

  name        = "grafana"
  cluster_arn = data.aws_ecs_cluster.main.arn

  requires_compatibilities = ["EC2"]
  launch_type              = "EC2"

  cpu    = 256
  memory = 265

  container_definitions = {
    grafana = {
      image     = "grafana/grafana-oss:latest"
      essential = true
      cpu       = 256
      memory    = 265

      portMappings = [
        {
          name          = "http"
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      readonlyRootFilesystem = false

      # SSM → ECS secrets (from data sources)
      secrets = [
        {
          name      = "GF_SECURITY_ADMIN_USER"
          valueFrom = data.aws_ssm_parameter.grafana_admin_user.arn
        },
        {
          name      = "GF_SECURITY_ADMIN_PASSWORD"
          valueFrom = data.aws_ssm_parameter.grafana_admin_password.arn
        }
      ]

      environment = [
        {
          name  = "GF_SERVER_ROOT_URL"
          value = "%(protocol)s://%(domain)s:3000/"
        }
      ]

      enable_cloudwatch_logging              = true
      create_cloudwatch_log_group            = true
      cloudwatch_log_group_name              = "/ecs/grafana"
      cloudwatch_log_group_retention_in_days = 3
    }
  }

  # Existing ALB target group for Grafana, resolved via data source
  load_balancer = {
    service = {
      target_group_arn = aws_lb_target_group.grafana_tg.arn
      container_name   = "grafana"
      container_port   = 3000
    }
  }

  # Subnets for ECS tasks – from a data source
  subnet_ids = data.aws_subnets.ecs_private.ids

  # SG for the service; allow traffic from the ALB SG (data source)
  security_group_ingress_rules = {
    alb_http_3000 = {
      description                  = "Allow HTTP 3000 from ALB"
      from_port                    = 3000
      to_port                      = 3000
      ip_protocol                  = "tcp"
      referenced_security_group_id = data.aws_security_group.alb.id
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  create_task_exec_iam_role = false
  task_exec_iam_role_arn    = aws_iam_role.grafana_execution_role.arn
  create_task_exec_policy   = false

  create_tasks_iam_role = false
  tasks_iam_role_arn    = aws_iam_role.grafana_task_role.arn

  tags = {
    Service = "grafana"
  }
}
