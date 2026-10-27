# Security groups – web (80/8080) and RDS (5432, only from the app server).

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
