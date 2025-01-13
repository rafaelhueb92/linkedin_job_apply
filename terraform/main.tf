resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Update the Lambda execution role to allow access to the secret
resource "aws_iam_policy" "lambda_secrets_access" {
  name   = "LambdaSecretsAccessPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = aws_secretsmanager_secret.linkedin_token.arn
      }
    ]
  })
}

# Create a Secrets Manager secret for LinkedIn token
resource "aws_secretsmanager_secret" "linkedin_token" {
  name        = "linkedin-token"
  description = "LinkedIn API token for Lambda function"
}

resource "aws_iam_role_policy_attachment" "lambda_secrets_attachment" {
  role       = aws_iam_role.lambda_role .name
  policy_arn = aws_iam_policy.lambda_secrets_access.arn
}

resource "aws_iam_policy_attachment" "lambda_logs" {
  name       = "lambda_logs"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "linkedin_job_apply" {
  filename         = "lambda_function.zip"
  function_name    = "linkedin_job_apply"
  role             = aws_iam_role.lambda_role.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.9"
  timeout          = 300
  source_code_hash = filebase64sha256("lambda_function.zip")
  environment {
    variables = {
      LINKEDIN_API_TOKEN = aws_secretsmanager_secret.linkedin_token.name,
      LINKEDIN_API_URL = "api.linkedin.com/v2"
    }
  }
}

resource "aws_cloudwatch_event_rule" "schedule" {
  name        = "weekday_11am"
  description = "Trigger Lambda at 11 AM Monday to Friday"
  schedule_expression = "cron(0 11 ? * MON-FRI *)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  arn       = aws_lambda_function.linkedin_job_apply.arn
}`

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.linkedin_job_apply.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}
