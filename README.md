# Akvelon AWS task for SDE

See explanation of the task in https://docs.google.com/document/d/1IIVrTdXShYHmQr2zP_mIx2pQUXkF93UyP8QwcU3wnAk/edit

Based on code from https://github.com/Hvukov/AWS-TASK

Expected to be implemented on "Free Tier" https://aws.amazon.com/free

### Set up:
1. https://spacelift.io/blog/terraform-tutorial - install Terraform, AWS CLI,
   setup user for AWS, generate Access Key for it, configure AWS CLI (`aws configure --profile MY_PROFILE`).
   List of profiles may be checked with `aws configure list-profiles`.
2. Go to [backend_setup](/backend_setup/) folder - it is separate Terraform module to prepare "state".
   Update values in [variables.tf](/backend_setup/variables.tf) file with at least your `aws_profile`.
3. From [backend_setup](/backend_setup/) run `terraform init`, `terraform apply` to create backend
   (AWS S3 for tfstate and DynamoDB table for lock). It will generate "backend.tfvars" file in the root.
4. Return back to root and run `terraform init -backend-config=backend.tfvars`.
   It should use "backend.tfvars" file and output should contain "Successfully configured the backend "s3"!".
5. Run `terraform apply` from here.