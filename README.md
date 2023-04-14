# Akvelon AWS task for SDE

See explanation of the task in https://docs.google.com/document/d/1IIVrTdXShYHmQr2zP_mIx2pQUXkF93UyP8QwcU3wnAk/edit

Based on code from https://github.com/Hvukov/AWS-TASK

Expected to be implemented on "Free Tier" https://aws.amazon.com/free

### Set up:
1. https://spacelift.io/blog/terraform-tutorial - install Terraform, AWS CLI, setup user for AWS, generate Access Key for it, configure AWS CLI (`aws configure --profile MY_PROFILE`). List of profiles may be checked with `aws configure list-profiles`.
2. Go to "backend_setup", update 'defaults' in "variables.tf" file with required values and run `terraform init`, `terraform apply` to prepare backend (AWS S3 for tfstate and DynamoDB table for lock).
3. To setup cluster return back to root and run `terraform init`, `terraform apply` TODO