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

# NAT Gateways
resource "aws_eip" "nat-a" {
  vpc = true
}

resource "aws_nat_gateway" "nat-a" {
  allocation_id = aws_eip.nat-a.id
  subnet_id     = aws_subnet.jobify-public-subnet-a.id

  tags = {
    Name = "jobify-nat-a"
  }
}

resource "aws_eip" "nat-b" {
  vpc = true
}

resource "aws_nat_gateway" "nat-b" {
  allocation_id = aws_eip.nat-b.id
  subnet_id     = aws_subnet.jobify-public-subnet-b.id

  tags = {
    Name = "jobify-nat-b"
  }
}


# Private Route Table A
resource "aws_route_table" "jobify-private-rt-a" {
  vpc_id = aws_vpc.jobify-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-a.id  # Route through NAT gateway A
  }

  tags = {
    Name = "jobify-private-rt-a"
  }
}

# Private Route Table B
resource "aws_route_table" "jobify-private-rt-b" {
  vpc_id = aws_vpc.jobify-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-b.id  # Route through NAT gateway B
  }

  tags = {
    Name = "jobify-private-rt-b"
  }
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "private-a" {
  subnet_id      = aws_subnet.jobify-private-subnet-a.id
  route_table_id = aws_route_table.jobify-private-rt-a.id
}

resource "aws_route_table_association" "private-b" {
  subnet_id      = aws_subnet.jobify-private-subnet-b.id
  route_table_id = aws_route_table.jobify-private-rt-b.id
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
  ami                    = "ami-0ec0e125bb6c6e8ec" # Amazon Linux 2 AMI
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name
  subnet_id              = aws_subnet.jobify-public-subnet-a.id
  vpc_security_group_ids = [aws_security_group.jobify-bastion-sg.id]
  associate_public_ip_address = true
  key_name               = "ec2key"

  tags = {
    Name = "jobify-bastion-host"
  }
}

# Auto Scaling Group Launch Configuration
resource "aws_launch_configuration" "jobify-launch-config" {
  name_prefix       = "jobify-lc"
  image_id          = "ami-0ec0e125bb6c6e8ec"  # Amazon Linux 2 AMI
  instance_type     = "t2.micro"
  security_groups   = [aws_security_group.jobify-app-sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name
  key_name          = "ec2key"

  user_data = <<-EOF
    #!/bin/bash
    set -e  # Exit immediately if a command exits with a non-zero status
    sudo yum update -y
    
    #Install Node.js and npm
    curl -sL https://rpm.nodesource.com/setup_18.x | bash -
    yum install -y nodejs

    #Download and unzip the backend code
    cd /home/ec2-user
    sudo aws s3 cp s3://${aws_s3_bucket.jobify-artifacts.bucket}/backend-code.zip ./backend-code.zip
    sudo unzip -o /home/ec2-user/backend-code.zip -d /home/ec2-user/jobify-server
    sudo rm ./backend-code.zip

    #Install dependencies and start the server
    cd jobify-server
    npm install
    cd ..
    

    # Create the systemd service file
    cat <<EOT > jobify.service
    [Unit]
    Description=My Node.js Application
    After=network.target

    [Service]
    ExecStart=/usr/bin/npm run server
    Restart=always
    User=nobody
    Group=nobody
    Environment=PATH=/usr/bin:/usr/local/bin
    Environment=NODE_ENV=production
    WorkingDirectory=/home/ec2-user/jobify-server

    [Install]
    WantedBy=multi-user.target
    EOT

    sudo mv /home/ec2-user/jobify.service /etc/systemd/system/

    # Reload systemd, enable and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable jobify.service
    sudo systemctl start jobify.service
  EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "jobify-asg" {
  name                      = "jobify-asg"
  desired_capacity          = 2
  max_size                  = 4
  min_size                  = 2
  launch_configuration      = aws_launch_configuration.jobify-launch-config.name
  vpc_zone_identifier       = [
    aws_subnet.jobify-private-subnet-a.id,
    aws_subnet.jobify-private-subnet-b.id
  ]

  tag {
    key                 = "Name"
    value               = "jobify-app-server"
    propagate_at_launch = true
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
    Name = "jobify-target-group"
  }
}

# Load Balancer Listener
resource "aws_lb_listener" "jobify-alb-listener" {
  load_balancer_arn = aws_lb.jobify-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jobify-target-group.arn
  }
}

# Attach ASG to Target Group
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.jobify-asg.name
  lb_target_group_arn   = aws_lb_target_group.jobify-target-group.arn
}

# IAM Role for EC2 instances to access S3 and SSM
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2_ssm_role"

  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        }
      }
    ]
  }
  EOF

  tags = {
    Name = "ec2_ssm_role"
  }
}

# IAM Policy for the role
resource "aws_iam_policy" "ec2_ssm_policy" {
  name = "ec2_ssm_policy"

  policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ssm:DescribeInstanceInformation",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ec2:DescribeInstances",
          "s3:GetObject"
        ],
        "Resource": "*"
      }
    ]
  }
  EOF

  tags = {
    Name = "ec2_ssm_policy"
  }
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "ec2_ssm_role_policy_attachment" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = aws_iam_policy.ec2_ssm_policy.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2_ssm_profile"
  role = aws_iam_role.ec2_ssm_role.name
}


