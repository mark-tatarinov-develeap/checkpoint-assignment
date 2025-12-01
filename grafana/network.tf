resource "aws_lb_target_group" "grafana_tg" {
  name        = "grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = data.aws_lb.main.vpc_id
  target_type = "ip"

  health_check {
    path                = "/login"
    matcher             = "200-399"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "grafana" {
  load_balancer_arn = data.aws_lb.main.arn
  port              = 3000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana_tg.arn
  }
}

resource "aws_security_group" "grafana_task_sg" {
  name        = "grafana-task-sg"
  description = "Security group for Grafana ECS task"
  vpc_id      = data.aws_lb.main.vpc_id

  ingress {
    description = "HTTP from anywhere (ALB fronting it)"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "grafana-task-sg"
  }
}