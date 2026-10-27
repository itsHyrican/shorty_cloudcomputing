# IAM resources.
#
# Two roles:
#   1. github_actions – assumed by GitHub Actions via OIDC (no long-lived
#      credentials stored anywhere). The trust policy is restricted to this
#      repository (owner/name via var.github_repo).
#   2. ec2_app – instance profile of the app server; it only allows the
#      CloudWatch agent to write logs into the project's log group.

# --- GitHub Actions (OIDC) ---------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = { Name = "${var.project_name}-${var.environment}-github-oidc" }
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-${var.environment}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = ["sts:AssumeRoleWithWebIdentity"]
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_repo}:push",
            "repo:${var.github_repo}:pull_request",
            "repo:${var.github_repo}:workflow_dispatch",
          ]
        }
      }
    }]
  })

  tags = { Name = "${var.project_name}-${var.environment}-github-actions" }
}

# Scoped permission set for everything `terraform plan/apply/destroy` of
# this module touches. If AWS rejects an action during an apply, add it
# here – the error message names the missing action.
resource "aws_iam_role_policy" "github_actions" {
  name = "shorty-deploy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "TerraformManagedServices"
      Effect = "Allow"
      Action = [
        # EC2 / VPC: app server, networking, security groups
        "ec2:AllocateAddress",
        "ec2:AssociateAddress",
        "ec2:DisassociateAddress",
        "ec2:ReleaseAddress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:CreateInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:AssociateRouteTable",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:ModifySubnetAttribute",
        "ec2:ModifyVpcAttribute",
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:Describe*",
        # RDS: PostgreSQL database
        "rds:CreateDBInstance",
        "rds:DeleteDBInstance",
        "rds:ModifyDBInstance",
        "rds:RestartDBInstance",
        "rds:DescribeDBInstances",
        "rds:CreateDBSubnetGroup",
        "rds:DeleteDBSubnetGroup",
        "rds:ModifyDBSubnetGroup",
        "rds:DescribeDBSubnetGroups",
        # S3: remote state bucket
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetBucketTagging",
        "s3:PutBucketTagging",
        "s3:DeleteBucketTagging",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetEncryptionConfiguration",
        "s3:PutEncryptionConfiguration",
        "s3:DeleteEncryptionConfiguration",
        "s3:ListBucket",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:DeleteObjectVersion",
        # DynamoDB: state lock table
        "dynamodb:CreateTable",
        "dynamodb:DeleteTable",
        "dynamodb:UpdateTable",
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        # CloudWatch: alarms and dashboard
        "cloudwatch:PutMetricAlarm",
        "cloudwatch:DeleteAlarm",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:CreateDashboard",
        "cloudwatch:DeleteDashboard",
        "cloudwatch:GetDashboard",
        "cloudwatch:ListDashboards",
        # CloudWatch Logs: log group management
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DescribeLogGroups",
        "logs:PutRetentionPolicy",
        "logs:DescribeLogStreams",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        # SNS: alarm notification topic
        "sns:CreateTopic",
        "sns:DeleteTopic",
        "sns:GetTopicAttributes",
        "sns:SetTopicAttributes",
        "sns:Publish",
        "sns:Subscribe",
        "sns:Unsubscribe",
        "sns:ListSubscriptionsByTopic",
        "sns:TagResource",
        "sns:UntagResource",
        # IAM: manage the roles/providers this module itself creates
        "iam:CreateOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:GetOpenIDConnectProvider",
        "iam:ListOpenIDConnectProviders",
        "iam:UpdateOpenIDConnectProvider",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:PutRolePolicy",
        "iam:GetRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        # STS
        "sts:GetCallerIdentity",
        "sts:AssumeRoleWithWebIdentity"
      ]
      Resource = ["*"]
    }]
  })
}

# --- App server instance profile (CloudWatch agent) ---------------------------

resource "aws_iam_role" "ec2_app" {
  name = "${var.project_name}-${var.environment}-ec2-app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = ["sts:AssumeRole"]
    }]
  })

  tags = { Name = "${var.project_name}-${var.environment}-ec2-app" }
}

resource "aws_iam_role_policy" "ec2_app" {
  name = "cloudwatch-logs"
  role = aws_iam_role.ec2_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "CloudWatchAgentLogs"
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents"
      ]
      Resource = [
        aws_cloudwatch_log_group.app.arn,
        "${aws_cloudwatch_log_group.app.arn}:*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_app" {
  name = "${var.project_name}-${var.environment}-ec2-app"
  role = aws_iam_role.ec2_app.name
}

output "github_actions_role_arn" {
  description = "ARN of the role GitHub Actions assumes – store as the AWS_ROLE_ARN repository secret."
  value       = aws_iam_role.github_actions.arn
}
