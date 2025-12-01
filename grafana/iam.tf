resource "aws_iam_role" "grafana_task_role" {
  name               = "grafana-task-role"
  assume_role_policy = data.aws_iam_policy_document.grafana_task_assume_role.json
}

resource "aws_iam_role_policy_attachment" "grafana_task_cw_readonly" {
  role       = aws_iam_role.grafana_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

resource "aws_iam_role" "grafana_execution_role" {
  name               = "grafana-execution-role"
  assume_role_policy = data.aws_iam_policy_document.grafana_task_assume_role.json
}

resource "aws_iam_role_policy_attachment" "grafana_execution_role_policy" {
  role       = aws_iam_role.grafana_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "grafana_execution_ssm" {
  name = "grafana-execution-ssm"
  role = aws_iam_role.grafana_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReadGrafanaParams"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          data.aws_ssm_parameter.grafana_admin_user.arn,
          data.aws_ssm_parameter.grafana_admin_password.arn
        ]
      },
      {
        Sid    = "AllowKmsDecryptForSsm"
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = data.aws_kms_key.ssm.arn
      }
    ]
  })
}