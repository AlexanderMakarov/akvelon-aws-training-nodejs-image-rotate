variable "project_name" {
  description = "Name of project. Intended to use in name for all resources inside."
  type        = string
  default     = "akvelon-aws-training-nodejs-image-rotate"
}
variable "aws_profile" {
  description = "The AWS CLI profile to work under."
  type        = string
  default     = "alexander.makarov@akvelon.com"
}
variable "aws_region" {
  description = "The AWS region to deploy the infrastructure in."
  type        = string
  default     = "eu-west-3"
}
