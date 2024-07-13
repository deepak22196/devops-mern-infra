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

# Application Load Balancer (ALB)
resource "aws_lb" "jobify-alb" {
  name               = "jobify-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.jobify-app-sg.id]
  subnets            = [aws_subnet.jobify-public-subnet-a.id,aws_subnet.jobify-public-subnet-b.id]

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


# Elastic Load Balancer
# resource "aws_lb" "jobify-elb" {
#   name               = "jobify-elb"
#   availability_zones = ["ap-south-1a", "ap-south-1b"]
#   security_groups = [aws_security_group.jobify-app-sg.id]

#   listener {
#     instance_port     = 80
#     instance_protocol = "HTTP"
#     lb_port           = 80
#     lb_protocol       = "HTTP"
#   }

#   health_check {
#     target              = "HTTP:80/"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#   }

#   instances = [aws_instance.jobify-app-server-a.id,aws_instance.jobify-app-server-b.id]

#   tags = {
#     Name = "jobify-elb"
#   }
# }

# Elastic IPs for Bastion Host (optional)
# resource "aws_eip" "bastion_eip" {
#   instance = aws_instance.bastion.id
# }
