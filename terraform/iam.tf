resource "aws_iam_role" "lambda_exec" {
  name = "finops-ec2-scheduler-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_ec2_opt_in" {
  name = "finops-ec2-opt-in-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DescribeInstancesReadOnly"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        Sid      = "StopOnlyOptInTaggedInstances"
        Effect   = "Allow"
        Action   = ["ec2:StopInstances"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/AutoStop" = "True"
          }
        }
      },
      {
        Sid      = "CloudWatchLogsWrite"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.lambda_logs.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role" "scheduler_exec" {
  name = "finops-ec2-scheduler-trigger-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_invoke_lambda" {
  name = "finops-scheduler-invoke-lambda"
  role = aws_iam_role.scheduler_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = aws_lambda_function.finops_scheduler.arn
    }]
  })
}
