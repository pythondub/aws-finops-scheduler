data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../src/scheduler.py"
  output_path = "${path.module}/scheduler.zip"
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/finops-ec2-scheduler"
  retention_in_days = 14
}

resource "aws_lambda_function" "finops_scheduler" {
  function_name    = "finops-ec2-scheduler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "scheduler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      DRY_RUN          = var.dry_run
      TARGET_TAG_KEY   = "AutoStop"
      TARGET_TAG_VALUE = "True"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}

resource "aws_scheduler_schedule" "daily_stop" {
  state                        = "DISABLED"
  name                         = "finops-ec2-daily-stop"
  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.schedule_timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.finops_scheduler.arn
    role_arn = aws_iam_role.scheduler_exec.arn
  }
}
