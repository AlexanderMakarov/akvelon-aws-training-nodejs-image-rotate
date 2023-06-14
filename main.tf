provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      "project" = var.project_name
    }
  }
}

terraform {
  backend "s3" {} # Use "-backend-config" argument to populate values.
}

# Create S3 bucket.
resource "aws_s3_bucket" "s3_images" {
  bucket = var.project_name
}

# Create DynamoDB table.
resource "aws_dynamodb_table" "dynamodb_tasks" {
  name         = var.project_name
  billing_mode = "PAY_PER_REQUEST"

  # Define attributes which are required and may be used as hash/range key of table/LSI/GSI.
  attribute {
    name = "taskId"
    type = "N"
  }

  # Don't use rangeKey because it would require to add it into each "update" request.
  hash_key  = "taskId"
}

# Create SQS queue.
resource "aws_sqs_queue" "sqs_tasks" {
  name = var.project_name
}

# Prepare and attach IAM roles for Lambda function to access S3, DynamoDB, SQS.
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"

  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name   = "lambda-s3-policy"
  role   = aws_iam_role.lambda_role.name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "${aws_s3_bucket.s3_images.arn}/*"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name   = "lambda-dynamodb-policy"
  role   = aws_iam_role.lambda_role.name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "${aws_dynamodb_table.dynamodb_tasks.arn}"
    }
  ]
}
EOF
}

# Prepare ZIP with Lamdba code.
provider "archive" {}

data "archive_file" "zip" {
  type       = "zip"
  source_dir = "${path.module}/lambdaFlipper"
  excludes = [
    "testLocally.js",
    "exampleSqsEvent.json",
    "package-lock.json",
    "package.json"
  ]
  output_path = "lambda_code.zip"
}

# Create Lambda function.
resource "aws_lambda_function" "lambda_image_rotator" {
  function_name    = var.project_name
  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  role             = aws_iam_role.lambda_role.arn
  timeout          = 2 * 60 # 2 minutes max.
  memory_size      = 128

  # Pass environment variables for S3 bucket name and DynamoDB table name
  environment {
    variables = {
      S3_IMAGES      = aws_s3_bucket.s3_images.bucket
      DYNAMODB_TASKS = aws_dynamodb_table.dynamodb_tasks.name
    }
  }
}

# Grant the Lambda function permission to access the SQS queue
resource "aws_lambda_permission" "lambda_image_rotator_sqs_permission" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_image_rotator.function_name
  principal     = "sqs.amazonaws.com"

  source_arn = aws_sqs_queue.sqs_tasks.arn
}
