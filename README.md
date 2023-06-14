# Akvelon AWS task for SDE

See explanation of the task in https://docs.google.com/document/d/1IIVrTdXShYHmQr2zP_mIx2pQUXkF93UyP8QwcU3wnAk/edit

Based on code from https://github.com/Hvukov/AWS-TASK

Expected to be implemented on "Free Tier" https://aws.amazon.com/free

# Set up:
1. https://spacelift.io/blog/terraform-tutorial - install Terraform, AWS CLI,
   setup user for AWS, generate Access Key for it, configure AWS CLI (`aws configure --profile MY_PROFILE`).
   List of profiles may be checked with `aws configure list-profiles`.
2. Go to [backend_setup](/backend_setup/) folder - it is separate Terraform module to prepare "state".
   Update values in [variables.tf](/backend_setup/variables.tf) file with at least your `aws_profile`.
3. From [backend_setup](/backend_setup/) run `terraform init`, `terraform apply` (will ask to type "yes")
   to create backend (AWS S3 for tfstate and DynamoDB table for lock).
   It will generate "backend.tfvars" file in the root.
4. Go to [lambdaFlipper](/lambdaFlipper/) and run `npm i`. It may fail due to "sharp" package dependencies,
   try to run `sudo apt-get install -y libvips` or whatever works on your OS.
   It will prepare Lambda code for distribution.
5. Go to [ecs](/ecs) forlder and run `npm i`. It will prepare ECS image for distribution.
6. Return back to root and run `terraform init -backend-config=backend.tfvars`.
   It should use "backend.tfvars" file and output should contain "Successfully configured the backend "s3"!".
7. Run `terraform apply` from here. It would create all AWS infra and deploy distributions on it.
8. Open Swagger at http://localhost:4000/api-docs.
9. Provide some picture

# Local testing.

## Lambda.

For all options need:
- Upload "test.jpg" into created S3 bucket.
- Create DynamoDB item with "taskId=1".

In VS Code (with debug abilities):

1. Remove ".exampl" suffix for [lambdaFlipper/.env.example](/lambdaFlipper/.env.example) and update with your data.
2. Run 'Debug Lambda' configuration.

In console:

1. Go to [lambdaFlipper](/lambdaFlipper/) folder.
2. Set in console the same environment variables as in [lambdaFlipper/.env.example](/lambdaFlipper/.env.example).
3. Run `node testLocally.js`.

## API

TODO