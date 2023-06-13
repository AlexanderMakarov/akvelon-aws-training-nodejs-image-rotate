provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

terraform {
  backend "s3" {} # Use "-backend-config" argument to populate values.
}

# Create S3 bucket.
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-bucket-name" # Replace with your desired bucket name
  acl    = "private"
  tags = {
    Project        = var.project_name
  }
}

# Create DynamoDB table.
resource "aws_dynamodb_table" "my_table" {
  name         = "my-table-name" # Replace with your desired table name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute { # TODO
    name = "id"
    type = "S"
  }
  tags = {
    Project        = var.project_name
  }
}

# Create SQS queue.
resource "aws_sqs_queue" "my_queue" {
  name = "my-queue-name" # Replace with your desired queue name
  tags = {
    Project        = var.project_name
  }
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

resource "aws_iam_role_policy_attachment" "lambda_s3_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

# Prepare ZIP with Lamdba code.
provider "archive" {}

data "archive_file" "zip" {
  type        = "zip"
  source_file = "lambda/serviceWorker.js"
  output_path = "lambda_code.zip"
}

# Create Lambda function.
resource "aws_lambda_function" "my_lambda" {
  function_name    = "my-lambda-function"
  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  role             = aws_iam_role.lambda_role.arn
  timeout          = 10
  memory_size      = 128

  # Pass environment variables for S3 bucket name and DynamoDB table name
  environment {
    variables = {
      S3_BUCKET_NAME      = aws_s3_bucket.my_bucket.bucket
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.my_table.name
    }
  }
  tags = {
    Project        = var.project_name
  }
}

# Grant the Lambda function permission to access the SQS queue
resource "aws_lambda_permission" "my_lambda_sqs_permission" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda.function_name
  principal     = "sqs.amazonaws.com"

  source_arn = aws_sqs_queue.my_queue.arn
}
