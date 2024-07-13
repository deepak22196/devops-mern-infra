variable "region" {
  description = "The AWS region to deploy in"
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_a" {
  description = "CIDR block for public subnet in AZ A"
  default     = "10.0.1.0/24"
}

variable "public_subnet_cidr_b" {
  description = "CIDR block for public subnet in AZ B"
  default     = "10.0.2.0/24"
}

variable "private_subnet_cidr_a" {
  description = "CIDR block for private subnet in AZ A"
  default     = "10.0.3.0/24"
}

variable "private_subnet_cidr_b" {
  description = "CIDR block for private subnet in AZ B"
  default     = "10.0.4.0/24"
}
