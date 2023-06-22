// Needed only to prepare "state" management for the main project.

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      "project" = var.project_name
    }
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = var.s3_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_acl" "terraform_state_acl" {
  bucket = aws_s3_bucket.terraform_state.id
}

resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# Run Shell script to create "backend.tfvars" for the main project.
resource "null_resource" "generate_backend_tfvars" {
  # Run it each "apply" call.
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" { # Note that command below need in Unix "cat" command and Shell pipes.
    command = <<-EOT
      cat > ../backend.tfvars <<EOF
      region         = "${var.aws_region}"
      bucket         = "${var.s3_bucket_name}"
      key            = "terraform/terraform.tfstate"
      dynamodb_table = "${var.dynamodb_table_name}"
      encrypt        = true
      profile        = "${var.aws_profile}"
      EOF
    EOT
  }
}
