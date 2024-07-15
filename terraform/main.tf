provider "aws" {
  region = "ap-south-1"
}

# VPC
resource "aws_vpc" "jobify-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "jobify-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "jobify-gw" {
  vpc_id = aws_vpc.jobify-vpc.id

  tags = {
    Name = "jobify-gw"
  }
}

# Route Table
resource "aws_route_table" "jobify-rt" {
  vpc_id = aws_vpc.jobify-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jobify-gw.id
  }

  tags = {
    Name = "jobify-rt"
  }
}

# Subnets
resource "aws_subnet" "jobify-public-subnet-a" {
  vpc_id            = aws_vpc.jobify-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "jobify-public-subnet-a"
  }
}

resource "aws_subnet" "jobify-public-subnet-b" {
  vpc_id            = aws_vpc.jobify-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "jobify-public-subnet-b"
  }
}

resource "aws_subnet" "jobify-private-subnet-a" {
  vpc_id            = aws_vpc.jobify-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "jobify-private-subnet-a"
  }
}

resource "aws_subnet" "jobify-private-subnet-b" {
  vpc_id            = aws_vpc.jobify-vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "jobify-private-subnet-b"
  }
}

# Route Table Associations
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.jobify-public-subnet-a.id
  route_table_id = aws_route_table.jobify-rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.jobify-public-subnet-b.id
  route_table_id = aws_route_table.jobify-rt.id
}

# Security Group for Bastion Host
resource "aws_security_group" "jobify-bastion-sg" {
  vpc_id = aws_vpc.jobify-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jobify-bastion-sg"
  }
}

# Security Group for EC2 Instances
resource "aws_security_group" "jobify-app-sg" {
  vpc_id = aws_vpc.jobify-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jobify-app-sg"
  }
}

# Bastion Host
resource "aws_instance" "jobify-bastion-host" {
  ami           = "ami-0ec0e125bb6c6e8ec" # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.jobify-public-subnet-a.id
  vpc_security_group_ids= [aws_security_group.jobify-bastion-sg.id]

  tags = {
    Name = "jobify-bastion-host"
  }
}

# EC2 Instances
resource "aws_instance" "jobify-app-server-a" {
  ami           = "ami-0ec0e125bb6c6e8ec" # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.jobify-private-subnet-a.id
  vpc_security_group_ids = [aws_security_group.jobify-app-sg.id]

  tags = {
    Name = "jobify-app-server-a"
  }
}

resource "aws_instance" "jobify-app-server-b" {
  ami           = "ami-0ec0e125bb6c6e8ec" # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.jobify-private-subnet-b.id
  vpc_security_group_ids = [aws_security_group.jobify-app-sg.id]

  tags = {
    Name = "jobify-app-server-b"
  }
}



# Auto Scaling Group
resource "aws_autoscaling_group" "jobify-asg" {
  desired_capacity     = 1
  max_size             = 4
  min_size             = 1
  # health_check_type    = "EC2"
  # health_check_grace_period = 300
  force_delete         = true
  launch_configuration = aws_launch_configuration.jobify-launch-config.name
  vpc_zone_identifier  = [
    aws_subnet.jobify-private-subnet-a.id,
    aws_subnet.jobify-private-subnet-b.id
  ]

  tag {
    key                 = "Name"
    value               = "jobify-app-server"
    propagate_at_launch = true
  }
}

# Launch Configuration
# Launch Configuration
resource "aws_launch_configuration" "jobify-launch-config" {
  name_prefix   = "jobify-lc"
  image_id      = "ami-0ec0e125bb6c6e8ec"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  security_groups = [aws_security_group.jobify-app-sg.id]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y aws-cli unzip
    aws s3 cp s3://${aws_s3_bucket.jobify-artifacts.bucket}/build/artifact.zip /tmp/artifact.zip
    unzip -o /tmp/artifact.zip -d /var/www/html
    rm /tmp/artifact.zip

    # Create the systemd service file
    cat <<EOT > /etc/systemd/system/myapp.service
    [Unit]
    Description=My Node.js Application
    After=network.target

    [Service]
    ExecStart=/usr/bin/node /var/www/html/index.js
    Restart=always
    User=nobody
    Group=nobody
    Environment=PATH=/usr/bin:/usr/local/bin
    Environment=NODE_ENV=production
    WorkingDirectory=/var/www/html

    [Install]
    WantedBy=multi-user.target
    EOT

    # Reload systemd, enable and start the service
    systemctl daemon-reload
    systemctl enable myapp.service
    systemctl start myapp.service
  EOF

  lifecycle {
    create_before_destroy = true
  }
}



# S3 Bucket for Jenkins Artifacts
resource "aws_s3_bucket" "jobify-artifacts" {
  bucket = "jobify-artifacts-bucket"

  tags = {
    Name = "jobify-artifacts-bucket"
  }
}


# Application Load Balancer (ALB)
resource "aws_lb" "jobify-alb" {
  name               = "jobify-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.jobify-app-sg.id]
  subnets            = [aws_subnet.jobify-public-subnet-a.id, aws_subnet.jobify-public-subnet-b.id]

  tags = {
    Name = "jobify-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "jobify-target-group" {
  name     = "main-targets"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.jobify-vpc.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "main-targets"
  }
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.jobify-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jobify-target-group.arn
  }
}

# Registering Targets
resource "aws_lb_target_group_attachment" "app_server_a" {
  target_group_arn = aws_lb_target_group.jobify-target-group.arn
  target_id        = aws_instance.jobify-app-server-a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "app_server_b" {
  target_group_arn = aws_lb_target_group.jobify-target-group.arn
  target_id        = aws_instance.jobify-app-server-b.id
  port             = 80
}


# SNS Topic
resource "aws_sns_topic" "jobify-build-updates" {
  name = "jobify-build-updates"
}

# SQS Queue
resource "aws_sqs_queue" "jobify-build-queue" {
  name = "jobify-build-queue"
}

# SNS Subscription to SQS
resource "aws_sns_topic_subscription" "jobify-sns-to-sqs" {
  topic_arn = aws_sns_topic.jobify-build-updates.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.jobify-build-queue.arn
}

# Lambda Function
resource "aws_lambda_function" "jobify-deploy-lambda" {
  filename         = "../lambdas/updateBuild.zip"
  function_name    = "jobifyDeployFunction"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "updateBuild.handler"
  runtime          = "nodejs16.x"

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.jobify-artifacts.bucket
    }
  }

  source_code_hash = filebase64sha256("../lambdas/updateBuild.zip")
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM Role Policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambda_policy"
  role   = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:*",
          "s3:*",
          "ec2:*",
          "autoscaling:*"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Lambda Permission for SNS
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jobify-deploy-lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.jobify-build-updates.arn
}
