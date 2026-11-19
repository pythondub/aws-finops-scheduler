variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "dry_run" {
  type        = string
  default     = "true"
  description = "Fail-safe: за замовчуванням лише симуляція"
}

variable "schedule_expression" {
  type        = string
  default     = "cron(0 19 * * ? *)"
  description = "Щодня о 19:00"
}

variable "schedule_timezone" {
  type    = string
  default = "Europe/Rome"
}
