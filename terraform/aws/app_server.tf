# App server (EC2) – runs the backend and frontend in Docker.

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
  iam_instance_profile   = aws_iam_instance_profile.ec2_app.name

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    environment              = var.environment
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
