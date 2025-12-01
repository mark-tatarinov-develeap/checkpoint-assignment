data "aws_iam_policy_document" "grafana_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_kms_key" "ssm" {
  key_id = "alias/aws/ssm"
}

data "aws_lb" "main" {
  name = "checkpoint-exam-alb"
}

data "aws_subnets" "ecs_private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_lb.main.vpc_id]
  }
}

data "aws_security_group" "alb" {
  id = tolist(data.aws_lb.main.security_groups)[0]
}

data "aws_ecs_cluster" "main" {
  cluster_name = "checkpoint-exam-ecs-cluster"
}

data "aws_ssm_parameter" "grafana_admin_user" {
  name            = "/devops-exam/grafana/admin_user"
  with_decryption = true
}

data "aws_ssm_parameter" "grafana_admin_password" {
  name            = "/devops-exam/grafana/admin_pass"
  with_decryption = true
}

