data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions_plan" {
  name = "finops-scheduler-github-plan-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:pythondub/aws-finops-scheduler:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_plan_policy" {
  name = "finops-scheduler-github-plan-policy"
  role = aws_iam_role.github_actions_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "TerraformStateAccess"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::tfstate-finops-254405569998-eu-west-1"
      },
      {
        Sid    = "TerraformStateReadAndLock"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::tfstate-finops-254405569998-eu-west-1/finops-scheduler/*"
      },
      {
        Sid    = "TerraformPlanReadOnly"
        Effect = "Allow"
        Action = [
          "iam:Get*",
          "iam:List*",
          "lambda:Get*",
          "lambda:List*",
          "scheduler:Get*",
          "logs:Describe*",
          "logs:List*"
        ]
        Resource = "*"
      }
    ]
  })
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_plan.arn
  description = "ARN ролі для GitHub Actions OIDC"
}
