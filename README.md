# TechCorp Cloud Infrastructure Deployment (Month 1 Assessment)

## Project Overview
This project provisions a highly available, three-tier VPC architecture on AWS using Terraform. The infrastructure includes public and private subnets across two Availability Zones, a Bastion host for secure access, and an Application Load Balancer.

## Prerequisites
* Terraform v1.0+
* AWS CLI configured with IAM permissions
* An existing AWS Key Pair named `month-one`

## Deployment Instructions
1. Initialize Terraform: `terraform init`
2. View Deployment Plan: `terraform plan`
3. Deploy Infrastructure: `terraform apply --auto-approve`
4. Cleanup: `terraform destroy --auto-approve`

## Troubleshooting & Known Issues
### VcpuLimitExceeded Error
During the deployment of EC2 instances, an AWS Service Quota limitation was encountered:
`api error VcpuLimitExceeded: vCPU limit of 1`

**Resolution:**
The networking layer (VPC, Subnets, IGW, NAT GW) and the Application Load Balancer were successfully provisioned and verified in the AWS Console. Due to account-level restrictions, the EC2 instances were validated via `terraform plan` but could not be fully instantiated. Documentation of this limit is included in the `evidence/` folder.
