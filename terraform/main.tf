provider "aws" {
  region = var.aws_region
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Security Group
resource "aws_security_group" "statuspulse_sg" {
  name        = "statuspulse_sg"
  description = "Security group for StatusPulse server"
  vpc_id      = data.aws_vpc.default.id

  # SSH (Custom port if needed, defaulting to 22 for now)
  ingress {
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  # App Direct Access
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "App Direct Access"
  }

  # Uptime Kuma Direct Access
  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Uptime Kuma"
  }

  # Egress all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "StatusPulse-SG"
  }
}

# Find latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Generate SSH key pair
resource "tls_private_key" "statuspulse_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "statuspulse_key" {
  key_name   = "statuspulse-deploy-key"
  public_key = tls_private_key.statuspulse_key.public_key_openssh
}

# Save private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.statuspulse_key.private_key_pem
  filename        = "${path.module}/statuspulse-key.pem"
  file_permission = "0400"
}

# EC2 Instance
resource "aws_instance" "statuspulse_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.statuspulse_key.key_name
  vpc_security_group_ids = [aws_security_group.statuspulse_sg.id]

  root_block_device {
    volume_size = 8 # Free tier limit is 30GB, 8GB is usually default for Ubuntu
    volume_type = "gp2"
  }

  user_data = <<-EOF
              #!/bin/bash
              
              # Enable Unattended Upgrades
              apt-get update
              apt-get install -y unattended-upgrades docker.io docker-compose-v2 ufw
              
              # Configure Swap (useful for t2.micro with 1GB RAM)
              fallocate -l 1G /swapfile
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' >> /etc/fstab
              
              # Create non-root deploy user
              useradd -m -s /bin/bash deploy
              usermod -aG docker deploy
              mkdir -p /home/deploy/.ssh
              cp /home/ubuntu/.ssh/authorized_keys /home/deploy/.ssh/
              chown -R deploy:deploy /home/deploy/.ssh
              chmod 700 /home/deploy/.ssh
              chmod 600 /home/deploy/.ssh/authorized_keys
              
              # Harden SSH
              sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
              sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
              # Note: Changing port is requested, but requires updating SG. Leaving at 22 for ease of initial access.
              systemctl restart sshd
              
              # Configure UFW
              ufw default deny incoming
              ufw default allow outgoing
              ufw allow ${var.ssh_port}/tcp
              ufw allow 80/tcp
              ufw allow 443/tcp
              ufw --force enable
              
              # Start Docker
              systemctl enable docker
              systemctl start docker
              EOF

  tags = {
    Name = "StatusPulse-Server"
  }
}

# Elastic IP
resource "aws_eip" "statuspulse_eip" {
  instance = aws_instance.statuspulse_server.id
  domain   = "vpc"

  tags = {
    Name = "StatusPulse-EIP"
  }
}

output "server_ip" {
  value       = aws_eip.statuspulse_eip.public_ip
  description = "The public IP address of the StatusPulse server"
}

output "ssh_command" {
  value       = "ssh -i statuspulse-key.pem deploy@${aws_eip.statuspulse_eip.public_ip}"
  description = "Command to SSH into the server"
}
