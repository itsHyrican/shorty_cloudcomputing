variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Prefix for all resource names."
  type        = string
  default     = "shorty"
}

variable "environment" {
  description = "Environment label used in resource names and tags."
  type        = string
  default     = "dev"
}

# --- Networking -------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block of the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_cidr_blocks" {
  description = "CIDR ranges allowed to reach the web (80) and API (8080) ports. Restrict this in production!"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# --- App server -------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type for the app server. t3.small (2 GB) plus swap is enough for the image builds."
  type        = string
  default     = "t3.small"
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair for SSH access. Empty = no key attached."
  type        = string
  default     = ""
}

variable "frontend_allowed_hosts" {
  description = "Extra hostnames accepted by the Angular SSR Host check (comma-separated). The instance's Elastic IP is always added automatically."
  type        = string
  default     = "localhost,127.0.0.1"
}

# --- Source code ------------------------------------------------------------

variable "repo_url" {
  description = "Git URL cloned by the app server at first boot."
  type        = string
  default     = "https://github.com/itsHyrican/shorty_cloudcomputing.git"
}

variable "repo_branch" {
  description = "Branch to clone."
  type        = string
  default     = "main"
}

variable "repo_token" {
  description = "Optional GitHub token (PAT with `repo` scope) when the repository is private."
  type        = string
  sensitive   = true
  default     = ""
}

# --- Database ---------------------------------------------------------------

variable "db_name" {
  description = "Name of the initial PostgreSQL database."
  type        = string
  default     = "shorty"
}

variable "db_user" {
  description = "Master username of the RDS instance."
  type        = string
  default     = "shorty"
}

variable "db_password" {
  description = "Master password of the RDS instance. Change the default!"
  type        = string
  sensitive   = true
  default     = "shorty"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16.4"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS storage in GiB."
  type        = number
  default     = 20
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot when the RDS instance is destroyed (course project default: true)."
  type        = bool
  default     = true
}

# --- Short link behaviour (backend ShortUrlOptions) --------------------------

variable "default_ttl_hours" {
  description = "Default lifetime of a short link in hours."
  type        = number
  default     = 24
}

variable "max_ttl_hours" {
  description = "Maximum lifetime of a short link in hours."
  type        = number
  default     = 720
}

variable "cleanup_interval_minutes" {
  description = "How often the backend sweeps expired links (minutes)."
  type        = number
  default     = 15
}
