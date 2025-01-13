#!/bin/bash

# Create folders
mkdir -p terraform lambda .github/workflows

# Create Terraform files
cat << 'EOF' > terraform/provider.tf
provider "aws" {
  region = "us-east-1"
}
EOF

cat << 'EOF' > terraform/main.tf
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
      LINKEDIN_API_TOKEN = var.linkedin_api_token
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
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.linkedin_job_apply.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}
EOF

cat << 'EOF' > terraform/variables.tf
variable "linkedin_api_token" {
  description = "API token for LinkedIn"
  type        = string
}
EOF

cat << 'EOF' > terraform/outputs.tf
output "lambda_function_name" {
  value = aws_lambda_function.linkedin_job_apply.function_name
}
EOF

# Create Lambda files
cat << 'EOF' > lambda/app.py
import os
import requests

LINKEDIN_API_TOKEN = os.getenv("LINKEDIN_API_TOKEN")

def lambda_handler(event, context):
    headers = {
        "Authorization": f"Bearer {LINKEDIN_API_TOKEN}",
        "Content-Type": "application/json"
    }
    
    search_criteria = {
        "keywords": ["Python", "Node.js"],
        "jobTypes": ["FULL_TIME"],
        "description": "relocation"
    }
    
    jobs = search_jobs(headers, search_criteria)
    apply_to_jobs(headers, jobs)
    return {"statusCode": 200, "message": "Applied to jobs successfully."}

def search_jobs(headers, criteria):
    response = requests.post("https://api.linkedin.com/v2/jobSearch", json=criteria, headers=headers)
    response.raise_for_status()
    return response.json().get("elements", [])

def apply_to_jobs(headers, jobs):
    for job in jobs:
        if job.get("applicationType") == "SIMPLE":
            apply_response = requests.post(
                f"https://api.linkedin.com/v2/jobs/{job['id']}/apply", headers=headers)
            apply_response.raise_for_status()
EOF

cat << 'EOF' > lambda/requirements.txt
requests
EOF

# Create GitHub Actions workflow
cat << 'EOF' > .github/workflows/deploy.yml
name: Deploy Lambda

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: "3.9"

      - name: Install Dependencies
        run: pip install -r lambda/requirements.txt

      - name: Run Tests
        run: pytest tests

      - name: Zip Lambda Function
        run: |
          cd lambda
          zip -r ../lambda_function.zip .

      - name: Deploy to AWS
        uses: aws-actions/configure-aws-credentials@v3
        with:
          role-to-assume: ${{ secrets.AWS_ROLE }}
          aws-region: us-east-1

      - name: Apply Terraform
        run: terraform apply -auto-approve
EOF

echo "Project structure created successfully!"
