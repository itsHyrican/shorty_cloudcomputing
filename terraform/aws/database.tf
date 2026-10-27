# Database (RDS PostgreSQL).

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
