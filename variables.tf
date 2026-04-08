# 1. Region for infrastructure
variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# 2. Local IP (Required for Bastion Security)
variable "my_ip" {
  description = "Your public IP address for SSH access (e.g., 1.2.3.4/32)"
  type        = string
}

# 3. AWS Key Pair Name
variable "key_name" {
  description = "The name of the SSH key pair created in AWS Console"
  type        = string
}

# 4. Instance Types
variable "instance_type_micro" {
  default = "t3.micro"
}

variable "instance_type_db" {
  default = "t3.small"
}