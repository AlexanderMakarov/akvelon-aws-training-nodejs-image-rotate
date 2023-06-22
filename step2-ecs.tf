# Create ECR to store our Docker image.
resource "aws_ecr_repository" "api_repo" {
  name = var.project_name
}
resource "aws_ecr_lifecycle_policy" "api_repo_lifecycle_policy" {
  repository = aws_ecr_repository.api_repo.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire images older than 90 days"
      selection = {
        tagStatus   = "any"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 90
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# Build and push the Docker image to the ECR repository.
# It is not a recommended way but I want to automate it is as much as possible.
# Also see https://github.com/onnimonni/terraform-ecr-docker-build-module.
resource "null_resource" "build_push_image" {
  # Re-build and re-push image on any api/src changes.
  triggers = {
    source_code = sha256(join("", fileset("${path.module}/api/src/**", "${path.module}/api/src/*")))
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/api"
    command     = <<-EOT
      AWS_PROFILE=${var.aws_profile} aws ecr get-login-password \
        --region ${var.aws_region} | \
      docker login \
        --username AWS \
        --password-stdin ${aws_ecr_repository.api_repo.registry_id}.dkr.ecr.${var.aws_region}.amazonaws.com && \
      docker build -t ${aws_ecr_repository.api_repo.repository_url}:latest . && \
      docker push ${aws_ecr_repository.api_repo.repository_url}:latest
    EOT
  }
}

# Define image.
data "aws_ecr_image" "api_image" {
  repository_name = aws_ecr_repository.api_repo.name
  image_tag       = "latest"
  depends_on      = [null_resource.build_push_image]
}

# IAM:
# ECS Task -> ECR, ECS?
# EC2 -> ECR register, S3, DynamoDB, SQS send.
# Network:
# EC2 -> from ALB 3000, from my IP 22
# ALB -> from the internet 3000

# Create ECS to run API server.
resource "aws_ecs_cluster" "api_ecs_cluster" {
  name = var.project_name
}

# Create ECS Task role and provide access to ECR.
resource "aws_iam_role" "api_ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "api_task_role_policy_attachment_ecr" {
  role       = aws_iam_role.api_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "api_task_role_policy_attachment_ecs" {
  role       = aws_iam_role.api_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create CloudWatch log group for API server.
resource "aws_cloudwatch_log_group" "api_log_group" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

# Create ECS Task to run docker image from ECR.
resource "aws_ecs_task_definition" "api_ecs_task_definition" {
  family                   = "${var.project_name}-api"
  execution_role_arn       = aws_iam_role.api_ecs_task_execution_role.arn
  network_mode             = "bridge" # awsvcp is designed for Fargate! And doesn't work.
  requires_compatibilities = ["EC2"]

  container_definitions = <<EOF
[
  {
    "name": "${var.project_name}",
    "image": "${aws_ecr_repository.api_repo.repository_url}:latest",
    "portMappings": [
      {
        "containerPort": 3000,
        "hostPort": 3000,
        "protocol": "tcp",
        "hostIp": "0.0.0.0"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.api_log_group.name}",
        "awslogs-region": "${var.aws_region}",
        "awslogs-stream-prefix": "api"
      }
    },
    "memory": 256,
    "environment": [
      {
        "name": "AWS_REGION",
        "value": "${var.aws_region}"
      },
      {
        "name": "S3_IMAGES",
        "value": "${aws_s3_bucket.s3_images.bucket}"
      },
      {
        "name": "DYNAMODB_TASKS",
        "value": "${aws_dynamodb_table.dynamodb_tasks.name}"
      },
      {
        "name": "SQS_TASKS",
        "value": "${aws_sqs_queue.sqs_tasks.name}"
      }
    ]
  }
]
  EOF
}

# Configure network for ECS - let it be the default VPC.
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [aws_default_vpc.default.id]
  }
}

# Get current machine IP address to allow SSH access from it. Save it in local variable.
# https://gist.github.com/gmirsky/7e43121ab6118896397ffe66aa2ebd9a
data "http" "icanhazip" {
  url = "http://icanhazip.com"
}
locals {
  my_terraform_environmnet_public_ip = chomp(data.http.icanhazip.response_body)
}

# Buld local SSH keys for EC2 instances.
resource "tls_private_key" "api_ec2_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "local_file" "api_ec2_ssh_key_file" {
  content         = tls_private_key.api_ec2_ssh_key.private_key_pem
  filename        = "${var.project_name}_ssh_key.pem"
  file_permission = "0600"
}
resource "aws_key_pair" "api_key_pair" {
  key_name   = var.project_name
  public_key = tls_private_key.api_ec2_ssh_key.public_key_openssh
}

# Due to Fargate doesn't have free tier we will use raw EC2-s to host API.
# Therefore need launch EC2 with ECS agent on it in order to connect to ECS cluster and run tasks from it.
# To allow scalability create Auto Scaling Group and Load Balancer.

# Create all required IAM accesses for EC2 instances.
resource "aws_iam_role" "api_ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  # Provide all required accesses for ECS agent to connect to EC2.
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"]
}
resource "aws_iam_role_policy" "api_ec2_role_policy" {
  name   = "ec2_dynamodb+s3+sqs_policy"
  role   = aws_iam_role.api_ec2_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:Scan",
        "dynamodb:Query",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "${aws_dynamodb_table.dynamodb_tasks.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "${aws_s3_bucket.s3_images.arn}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage"
      ],
      "Resource": "${aws_sqs_queue.sqs_tasks.arn}"
    }
  ]
}
EOF
}

# Prepare EC2 Launch template.
data "template_file" "api_ec2_user_data" {
  # We need connect to ECS cluster.
  # If add `shutdown -h +60` in the script to don't forget disable it then it won't help,
  # at least because ASG will launch new instance and it still would consume EC2 time.
  # So to stop EC2 hours consumption it is better to scale ASG into 0.
  template = <<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.api_ecs_cluster.id}" >> /etc/ecs/ecs.config
  EOF
}
resource "aws_iam_instance_profile" "api_iam_instance_profile" {
  name = var.project_name
  role = aws_iam_role.api_ec2_role.name
}
resource "aws_launch_template" "api_launch_template" {
  name_prefix = var.project_name
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/launch_container_instance.html#linux-liw-ami
  image_id               = "ami-0619a87524af4765e" # "ami-00a215c1938e59989"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.api_key_pair.key_name
  user_data              = base64encode(data.template_file.api_ec2_user_data.rendered)
  vpc_security_group_ids = [aws_security_group.api_ec2_security_group.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.api_iam_instance_profile.name
  }
}

# Create ASG with lauch template configured above and ALB target group to be connected to.
resource "aws_autoscaling_group" "api_auto_scaling_group" {
  name                      = var.project_name
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = data.aws_subnets.default.ids
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.api_launch_template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.api_lb_target_group.arn]
}

# Configure ASG security group.
# To don't make cycles configure EC2 security group AFTER ALB was created to allow input traffic only from ALB.
resource "aws_security_group" "api_ec2_security_group" {
  name        = "${var.project_name}-ec2"
  description = "Security group for API EC2 instances" # Should be max 256 characters length.
}
resource "aws_security_group_rule" "api_ec2_security_group_alb_ingress" {
  security_group_id        = aws_security_group.api_ec2_security_group.id
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = tolist(aws_lb.api_load_balancer.security_groups)[0]

  depends_on = [aws_lb.api_load_balancer]
}
resource "aws_security_group_rule" "api_ec2_security_group_ssh_ingress" {
  security_group_id = aws_security_group.api_ec2_security_group.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["${local.my_terraform_environmnet_public_ip}/32"]

  depends_on = [aws_lb.api_load_balancer] # TODO remove
}
resource "aws_security_group_rule" "api_ec2_security_group_engress" {
  security_group_id = aws_security_group.api_ec2_security_group.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]

  depends_on = [aws_lb.api_load_balancer] # TODO remove
}

# Network Load balancer (OSI level 4) looks better here, to don't mess with endpoints configuration of application.
# But AWS Free Tier doesn't provide NLB, only ALB (Classic LB is deprecated already).

# Create security group for ALB. Open only 3000 port.
resource "aws_security_group" "api_alb_security_group" {
  name        = "${var.project_name}-alb"
  description = "Security group for API ALB" # Should be max 256 characters length.

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create ALB (OSI level 7).
resource "aws_lb" "api_load_balancer" {
  name               = substr(var.project_name, 0, 32) # Here we have 32 characters length limitation.
  load_balancer_type = "application"
  security_groups    = [aws_security_group.api_alb_security_group.id]
  subnets            = data.aws_subnets.default.ids
}
resource "aws_lb_target_group" "api_lb_target_group" {
  name     = substr(var.project_name, 0, 32) # Here we have 32 characters length limitation.
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_default_vpc.default.id

  health_check {
    port                = "traffic-port"
    protocol            = "HTTP"
    path                = "/api-docs/" # It is the place where API server responds 200 even without access to DynamoDB.
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 15
  }
}
resource "aws_lb_listener" "api_listener" {
  load_balancer_arn = aws_lb.api_load_balancer.arn
  port              = 3000
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.api_lb_target_group.arn
    type             = "forward"
  }
}

# Create ECS service - long running process with our API.
resource "aws_ecs_service" "api_ecs_service" {
  name            = "${var.project_name}-api"
  cluster         = aws_ecs_cluster.api_ecs_cluster.id
  task_definition = aws_ecs_task_definition.api_ecs_task_definition.arn
  desired_count   = 1
  launch_type     = "EC2" # Default but specify explicitly that we want EC2 instead of no-free-tier Fargate.
}

# FYI in case of error like:
# > registering targets with target group: ValidationError: Instance ID 'akvelon-aws-training-nodejs-image-rotate' is not valid
# SSH to the EC2 instance and run `tail /var/log/ecs/ecs-agent.log` on it to see what ECS agent is complying on.
# If fix is available in-place the restart ECS agent with `sudo systemctl restart ecs`
# See https://repost.aws/knowledge-center/ecs-container-instance-agent-error
