# StatusPulse Infrastructure as Code

This directory contains the Terraform configuration to provision the necessary AWS resources for the StatusPulse application using the AWS Free Tier.

## Resources Created
- EC2 Instance (`t2.micro` - Free Tier eligible)
- Security Group (Allows SSH, HTTP, HTTPS)
- Elastic IP (Static Public IP)
- Automatically configured via `user_data`:
  - Docker & Docker Compose installation
  - Swap file setup (1GB) to help with the 1GB RAM limit on `t2.micro`
  - Unattended Upgrades for security
  - UFW Firewall enabled
  - Non-root `deploy` user creation

## Prerequisites
1. Install [Terraform](https://developer.hashicorp.com/terraform/downloads)
2. Configure AWS credentials locally (`aws configure` or set environment variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`)

## Usage

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Review the execution plan:
   ```bash
   terraform plan
   ```

3. Apply the configuration to create resources:
   ```bash
   terraform apply
   ```

4. Type `yes` when prompted to confirm.

5. After successful completion, Terraform will output the Server IP and the SSH command. The private key (`statuspulse-key.pem`) will be saved in this directory.

   ```bash
   # Connect to the server
   ssh -i statuspulse-key.pem deploy@<Server_IP>
   ```

## Teardown

To destroy the infrastructure and stop incurring costs (though this uses free tier resources):
```bash
terraform destroy
```
