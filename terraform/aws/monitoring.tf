# CloudWatch + SNS: project-specific logging, alarms and a dashboard.
#
# The assignment does not count the default metrics AWS emits automatically;
# this module therefore creates dedicated resources:
#   - a log group the CloudWatch agent on the app server writes to
#     (deployment log + Docker container logs),
#   - alarms for CPU saturation of the app server and the database,
#   - a dashboard with the most relevant metrics,
#   - an SNS topic that receives the alarm notifications.

resource "aws_cloudwatch_log_group" "app" {
  name              = "/shorty/${var.environment}/app"
  retention_in_days = 30

  tags = { Name = "${var.project_name}-${var.environment}-logs" }
}

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"

  tags = { Name = "${var.project_name}-${var.environment}-alerts" }
}

resource "aws_cloudwatch_metric_alarm" "app_server_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-app-server-cpu-high"
  alarm_description   = "App server CPU above 80% for 10 minutes."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    InstanceId = aws_instance.app.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.project_name}-${var.environment}-alarm-app-cpu" }
}

resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-database-cpu-high"
  alarm_description   = "RDS PostgreSQL CPU above 80% for 10 minutes."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.project_name}-${var.environment}-alarm-db-cpu" }
}

resource "aws_cloudwatch_dashboard" "shorty" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.app.id]]
          period  = 300
          stat    = "Average"
          region  = var.region
          title   = "App Server - CPU (%)"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.this.identifier]]
          period  = 300
          stat    = "Average"
          region  = var.region
          title   = "Database - CPU (%)"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.this.identifier]]
          period  = 300
          stat    = "Average"
          region  = var.region
          title   = "Database - Connections"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.app.id],
            ["AWS/EC2", "NetworkOut", "InstanceId", aws_instance.app.id],
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "App Server - Network (bytes)"
          view   = "timeSeries"
        }
      },
    ]
  })
}
