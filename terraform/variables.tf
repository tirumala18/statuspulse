variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type (must be free tier eligible)"
  type        = string
  default     = "t3.micro"
}

variable "ssh_port" {
  description = "Port to use for SSH"
  type        = number
  default     = 22
}
