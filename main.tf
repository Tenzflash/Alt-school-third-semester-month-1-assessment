# --- PROVIDER BLOCK ---
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- 1. VIRTUAL PRIVATE CLOUD (VPC) ---
resource "aws_vpc" "techcorp_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "techcorp-vpc"
  }
}
# --- 2. PUBLIC SUBNETS ---

# Public Subnet 1 (AZ a)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.techcorp_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true # This makes it "Public"

  tags = { Name = "techcorp-public-subnet-1" }
}

# Public Subnet 2 (AZ b)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.techcorp_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = { Name = "techcorp-public-subnet-2" }
}

# --- 3. PRIVATE SUBNETS ---

# Private Subnet 1 (AZ a)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.techcorp_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"

  tags = { Name = "techcorp-private-subnet-1" }
}

# Private Subnet 2 (AZ b)
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.techcorp_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.aws_region}b"

  tags = { Name = "techcorp-private-subnet-2" }
}
# Internet Gateway for the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.techcorp_vpc.id
  tags   = { Name = "techcorp-igw" }
}

# Elastic IP for NAT Gateway (AWS requires a static IP for NAT)
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateway (Placed in Public Subnet 1)
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id # Must be in a public subnet!
  tags          = { Name = "techcorp-nat-gw" }
}
# --- 4. ROUTE TABLES ---

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.techcorp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "techcorp-public-rt" }
}

# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.techcorp_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = { Name = "techcorp-private-rt" }
}

# --- 5. ROUTE TABLE ASSOCIATIONS ---

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private_1_assoc" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_2_assoc" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}
# --- 6. SECURITY GROUPS ---

# Bastion Security Group (SSH from your IP only)
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH from my IP"
  vpc_id      = aws_vpc.techcorp_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Web Security Group (HTTP/HTTPS from anywhere, SSH from Bastion)
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  vpc_id      = aws_vpc.techcorp_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # Only Bastion can SSH
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Database Security Group (Postgres from Web, SSH from Bastion)
resource "aws_security_group" "db_sg" {
  name        = "db-sg"
  description = "Allow Postgres from Web SG and SSH from Bastion SG"
  vpc_id      = aws_vpc.techcorp_vpc.id

  ingress {
    description     = "Postgres from Web Servers"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # The "Blue Badge" logic
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Find the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# 1. Bastion Host (Public Subnet)
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type_micro
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = var.key_name
  associate_public_ip_address = true

  tags = { Name = "techcorp-bastion" }
}

# 2. Web Servers (One in each Private Subnet)
resource "aws_instance" "web" {
  count                  = 2
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type_micro
  subnet_id              = count.index == 0 ? aws_subnet.private_1.id : aws_subnet.private_2.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = var.key_name
  user_data              = file("user_data/web_server_setup.sh")

  tags = { Name = "techcorp-web-${count.index + 1}" }
}

# 3. Database Server (Private Subnet)
resource "aws_instance" "db" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type_db
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  key_name               = var.key_name
  user_data              = file("user_data/db_server_setup.sh")

  tags = { Name = "techcorp-db" }
}
# Application Load Balancer
resource "aws_lb" "web_alb" {
  name               = "techcorp-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

# ALB Target Group
resource "aws_lb_target_group" "web_tg" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.techcorp_vpc.id

  health_check {
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }
}

# ALB Listener
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Attach Web Instances to Target Group
resource "aws_lb_target_group_attachment" "web_attachment" {
  count            = 2
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}