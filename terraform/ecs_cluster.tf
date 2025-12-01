resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Project = var.project_name
  }
}


resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project_name}-ecs-lt-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = "t2.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "ECS_CLUSTER=${aws_ecs_cluster.this.name}" >> /etc/ecs/ecs.config
              EOF
  )

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ecs_instances.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = "${var.project_name}-ecs-instance"
      Project = var.project_name
    }
  }
}


resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project_name}-ecs-asg"
  desired_capacity    = 3
  min_size            = 1
  max_size            = 4
  vpc_zone_identifier = module.vpc.private_subnets
  health_check_type   = "EC2"
  force_delete        = true

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ecs-instance"
    propagate_at_launch = true
  }
}


resource "aws_ecs_capacity_provider" "ecs_asg" {
  name = "${var.project_name}-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 75
    }

    managed_termination_protection = "DISABLED"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = [aws_ecs_capacity_provider.ecs_asg.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_asg.name
    weight            = 1
  }
}
