locals {
  interface_endpoints = {
    sqs            = "com.amazonaws.${var.aws_region}.sqs"
    ecr_api        = "com.amazonaws.${var.aws_region}.ecr.api"
    ecr_dkr        = "com.amazonaws.${var.aws_region}.ecr.dkr"
    logs           = "com.amazonaws.${var.aws_region}.logs"
    ssm            = "com.amazonaws.${var.aws_region}.ssm"
    ecs            = "com.amazonaws.${var.aws_region}.ecs"
    ecs_agent      = "com.amazonaws.${var.aws_region}.ecs-agent"
    ecs_telemetry  = "com.amazonaws.${var.aws_region}.ecs-telemetry"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = module.vpc.private_route_table_ids

  tags = {
    Name    = "${var.project_name}-s3-endpoint"
    Project = var.project_name
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each          = local.interface_endpoints
  vpc_id            = module.vpc.vpc_id
  service_name      = each.value
  vpc_endpoint_type = "Interface"

  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name    = "${var.project_name}-${each.key}-endpoint"
    Project = var.project_name
  }
}

