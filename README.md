# Akvelon AWS task for SDE

See explanation of the task in https://docs.google.com/document/d/1IIVrTdXShYHmQr2zP_mIx2pQUXkF93UyP8QwcU3wnAk/edit

Implemented completely on "Free Tier" https://aws.amazon.com/free.

# Set up:

Note that it was tested only on Ubuntu 22.04.2 LTS. Terraform inside runs Shell scripts. 

1. https://spacelift.io/blog/terraform-tutorial - install Terraform, AWS CLI,
   setup user for AWS, generate Access Key for it, configure AWS CLI (`aws configure --profile MY_PROFILE`).
   List of profiles may be printed with `aws configure list-profiles`.
2. Go to [backend_setup](/backend_setup/) folder - it is separate Terraform module to prepare "state".
   Set right values in [variables.tf](/backend_setup/variables.tf) file.
3. From [backend_setup](/backend_setup/) run `terraform init`, `terraform apply` (will ask to type "yes")
   to create backend (AWS S3 for tfstate and DynamoDB table for lock).
   It will generate "backend.tfvars" file in the root.
4. Go to [lambdaFlipper](/lambdaFlipper/) and run `npm i`. It may fail due to "sharp" package dependencies,
   try to run `sudo apt-get install -y libvips` or whatever works on your OS.
   It will prepare Lambda code for distribution.
5. Go to [ecs](/ecs) forlder and run `npm i`. It will prepare ECS image for distribution.
6. Return back to root and run `terraform init -backend-config=backend.tfvars`.
   It should use "backend.tfvars" file and output should contain "Successfully configured the backend "s3"!".
7. Run `terraform apply` from here. It would create all AWS infra and deploy Lambda with ECS task.
   Also it would print out something like
   ```
   api_ec2_ssh_key_file = "akvelon-aws-training-nodejs-image-rotate_ssh_key.pem"
   api_service_url = "http://akvelon-aws-training-nodejs-imag-1502784303.eu-west-3.elb.amazonaws.com:3000/api-docs"
   my_terraform_environmnet_public_ip = "12.34.56.78"
   ```
   where `api_service_url` is an URL to open API server on.
8. Open Swagger at `api_service_url` provided in Terraform output.
   Or find ALB DNS name in AWS console and append ":3000/api-docs" to it
9. Provide some picture into POST /tasks less than 5MB in size. It will respond with JSON containing `taskId`.
10. Call any GET endpoint with this `taskId` - Lambda takes near 2 seconds to flip image.

# Local testing.

For local testing still need to have AWS S3 bucket, DynamoDB table. For API server need to have SQS queue as well.
To provision these resources rename [step2-ecs.tf](/step2-ecs.tf) to don't have "*.tf" extension.
Run `terraform apply` - it should create all these things (with name equal to `project_name` Terraform variable)
and deploy current Lambda code which won't work without new messages into SQS queue.

## Lambda.

Precondition for all options:
- Upload "test.jpg" into created S3 bucket.
- Create DynamoDB item with "taskId=1".

In VS Code (with debug abilities):

1. Remove ".example" suffix from file [.env.example](/.env.example) and update with your values.
2. Run 'Debug Lambda' configuration.

In console:

1. Go to [lambdaFlipper](/lambdaFlipper/) folder.
2. Set in console the same environment variables as in [.env.example](/.env.example).
3. Run `node testLocally.js`. Will stop after execution.

## API server.

In VS Code (with debug abilities):

1. Remove ".example" suffix for [.env.example](/.env.example) and update with your data.
2. Run 'Debug API' configuration. If it fails with "tsc not found" then install it globally
   with something like `sudo npm install -g typescript`.

In console:

1. Go to [api](/api/) folder.
2. Set in console the same environment variables as in [.env.example](/.env.example).
3. Run `npm run dev`. Will dynamically restart server with any code changes.
