variable aws_region {
  type        = string
  default     = "us-west-2"
}

variable project_name {
  type        = string
  default     = "checkpoint-exam"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "producer_image_tag" {
  description = "ECR image tag for the producer"
  type        = string
}

variable "consumer_image_tag" {
  description = "ECR image tag for the consumer"
  type        = string
}

variable "token_parameter_arn" {
  type        = string
  default     = "arn:aws:ssm:us-west-2:371670420772:parameter/devops-exam/token"
  description = "The ARN of the Token SSM Parameter, created manually"
}

variable "token_ssm_path" {
  type        = string
  default     = "/devops-exam/token"
  description = "The path of the Token SSM Parameter"
}
