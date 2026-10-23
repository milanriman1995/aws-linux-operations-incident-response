
# Infrastructure Baseline

## Project 1 — AWS Linux Operations

### AWS Environment

- Region: eu-west-2 (London)
- VPC: Existing default VPC
- VPC CIDR: 172.31.0.0/16
- Subnet: 172.31.16.0/20 (eu-west-2a)

### EC2 Configuration

- Operating system: Amazon Linux 2023
- Instance type: t3.micro
- Storage: 8 GiB gp3 EBS
- Administration: AWS Systems Manager Session Manager
- IAM role: project1-ec2-ssm-role
- Security group: project1-ec2-sg
- Inbound rules: None
- Outbound rules: HTTPS (TCP 443)
- IMDSv2: Required

### Initial Verification

- EC2 instance running
- EC2 status checks: 2/2 passed
- Session Manager connection: Successful
- SSM Agent: Active (running)

### Project Status

Infrastructure foundation deployed.
Linux operations and monitoring exercises in progress.
