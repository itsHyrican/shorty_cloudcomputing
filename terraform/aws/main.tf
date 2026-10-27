terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ---------------------------------------------------------------------------
# Network (single AZ on purpose – keep it simple for a course project)
# ---------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-${var.environment}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.project_name}-${var.environment}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-${var.environment}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.project_name}-${var.environment}-public" }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Security groups
# ---------------------------------------------------------------------------

resource "aws_security_group" "web" {
  name        = "${var.project_name}-${var.environment}-web"
  description = "Shorty app server: frontend (80) and backend API (8080)"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = { Name = "${var.project_name}-${var.environment}-web" }
}

resource "aws_security_group_rule" "web_ingress_http" {
  security_group_id = aws_security_group.web.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "Frontend over HTTP"
}

resource "aws_security_group_rule" "web_ingress_api" {
  security_group_id = aws_security_group.web.id
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "Backend API + Swagger UI"
}

resource "aws_security_group" "rds" {
  name   = "${var.project_name}-${var.environment}-rds"
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.project_name}-${var.environment}-rds" }
}

resource "aws_security_group_rule" "rds_ingress_from_app" {
  security_group_id        = aws_security_group.rds.id
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id
  description              = "PostgreSQL only from the app server"
}

# ---------------------------------------------------------------------------
# Database (RDS PostgreSQL)
# ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-${var.environment}-db"
  subnet_ids = [aws_subnet.public.id]

  tags = { Name = "${var.project_name}-${var.environment}-db" }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.project_name}-${var.environment}-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage      = var.db_allocated_storage
  storage_type           = "gp3"
  db_name                = var.db_name
  username               = var.db_user
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 1
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = false
  apply_immediately       = true

  tags = { Name = "${var.project_name}-${var.environment}-db" }
}

# ---------------------------------------------------------------------------
# App server (EC2) – runs the backend and frontend in Docker
# ---------------------------------------------------------------------------

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-2023-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Elastic IP: its address is known before the instance boots, so the
# deployment script can bake it into the frontend image as the API URL.
resource "aws_eip" "app" {
  domain = "vpc"

  tags = { Name = "${var.project_name}-${var.environment}-app" }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    repo_clone_url           = var.repo_token != "" ? replace(var.repo_url, "https://", "https://x-access-token://${var.repo_token}@") : var.repo_url
    repo_branch              = var.repo_branch
    db_host                  = aws_db_instance.this.address
    db_port                  = 5432
    db_name                  = var.db_name
    db_user                  = var.db_user
    db_password              = var.db_password
    api_url                  = "http://${aws_eip.app.public_ip}"
    app_public_ip            = aws_eip.app.public_ip
    frontend_allowed_hosts   = var.frontend_allowed_hosts
    default_ttl_hours        = var.default_ttl_hours
    max_ttl_hours            = var.max_ttl_hours
    cleanup_interval_minutes = var.cleanup_interval_minutes
  })

  # Changing the deployment config should not silently replace (and bill)
  # the instance again; redeploy manually via the log/script if needed.
  user_data_replace_on_change = false

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  tags = { Name = "${var.project_name}-${var.environment}-app" }
}

resource "aws_eip_association" "app" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app.allocation_id
}
