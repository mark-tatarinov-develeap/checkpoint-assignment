module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.0"

  name               = "${var.project_name}-alb"
  load_balancer_type = "application"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  create_security_group = true

  security_group_ingress_rules = {
    http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP from the internet"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = var.vpc_cidr
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "producer"
      }
    }
  }

  target_groups = {
    producer = {
      name_prefix = "ms1-"
      protocol    = "HTTP"
      port        = 80
      target_type = "ip"
      create_attachment = false 

      health_check = {
        path                = "/health"
        matcher             = "200-399"
        interval            = 30
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 5
      }
    }
  }

  tags = {
    Project = var.project_name
  }
}
