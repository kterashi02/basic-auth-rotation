module "lambda_at_edge" {
  source = "terraform-aws-modules/lambda/aws"
  providers = {
    aws = aws.virginia
  }

  lambda_at_edge = true

  function_name = "basicAuth"
  handler       = "lambda_handler.lambda_handler"
  runtime       = "python3.12"
  source_path = "src/basic_auth_lambda_at_edge/lambda_handler.py"
  attach_policy_json = true
  policy_json = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "secretsmanager:GetSecretValue"
          Resource = aws_secretsmanager_secret.basic_auth.arn
        }
      ]
    }
  )
}

module "secrets_manager_rotation" {
  source = "terraform-aws-modules/lambda/aws"
  function_name = "basic_auth_rotation"
  runtime       = "python3.12"
  handler       = "lambda_handler.lambda_handler"
  source_path = "src/basic_auth_rotation/lambda_handler.py"
  allowed_triggers = {
    SecretsManager ={
      "service": "secretsmanager"
      "source_arn": aws_secretsmanager_secret.basic_auth.arn
    }
  }
  create_current_version_allowed_triggers = false
  attach_policy_json = true
  policy_json = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = [
            "secretsmanager:DescribeSecret",
            "secretsmanager:GetSecretValue",
            "secretsmanager:PutSecretValue",
            "secretsmanager:UpdateSecretVersionStage"
          ]
          Resource = aws_secretsmanager_secret.basic_auth.arn
        },
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetRandomPassword"
            ],
            "Resource": "*"
        },
      ]
    }
  )
}

resource "aws_secretsmanager_secret" "basic_auth" {
  name = "/dev/basic-auth"
}


resource "aws_secretsmanager_secret_rotation" "basic_auth_rotation" {
  secret_id           = aws_secretsmanager_secret.basic_auth.id
  rotation_lambda_arn = module.secrets_manager_rotation.lambda_function_arn

  rotation_rules {
    automatically_after_days = 30
  }
}