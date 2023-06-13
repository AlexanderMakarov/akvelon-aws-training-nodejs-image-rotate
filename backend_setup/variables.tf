variable "aws_region" {
  description = "The AWS region to deploy the infrastructure in"
  type        = string
  default     = "eu-west-3"
}
variable "aws_profile" {
  description = "The AWS CLI profile to use for the authentication"
  type        = string
  default     = "alexander.makarov@akvelon.com"
}
variable "s3_bucket_name" {
  description = "The name of the S3 bucket to store Terraform state"
  type        = string
  default     = "akvelon-aws-training-nodejs-image-rotate-tfstate"
}
variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table for Terraform state locking"
  type        = string
  default     = "akvelon-aws-training-nodejs-image-rotate-tflock"
}
variable "project_name" {
  description = "The name of the project to put in tag 'project'."
  type        = string
  default     = "akvelon-aws-training-nodejs-image-rotate"
}
