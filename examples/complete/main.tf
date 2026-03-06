# -----------------------------------------------------------------------------
# Complete Example — OpenSearch domain with VPC, KMS encryption, logging,
#                    fine-grained access control, and compliance defaults
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

# -----------------------------------------------------------------------------
# VPC (simulated — in production this comes from terraform-aws-vpc module)
# -----------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project}-${var.environment}-vpc"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.project}-${var.environment}-private-${count.index}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_security_group" "opensearch" {
  name_prefix = "${var.project}-${var.environment}-opensearch-"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
    description = "HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-opensearch-sg"
    Project     = var.project
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# KMS Key (simulated — in production this comes from terraform-aws-kms module)
# -----------------------------------------------------------------------------

resource "aws_kms_key" "opensearch" {
  description             = "KMS key for OpenSearch domain encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_kms_alias" "opensearch" {
  name          = "alias/${var.project}-${var.environment}-opensearch"
  target_key_id = aws_kms_key.opensearch.key_id
}

# -----------------------------------------------------------------------------
# Secrets Manager — Master user password
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "master_password" {
  name                    = "${var.project}/${var.environment}/opensearch/master-password"
  description             = "OpenSearch master user password"
  recovery_window_in_days = 30
  kms_key_id              = aws_kms_key.opensearch.arn

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "master_password" {
  secret_id     = aws_secretsmanager_secret.master_password.id
  secret_string = "ChangeMe!Secur3P@ssw0rd"
}

# -----------------------------------------------------------------------------
# CloudWatch Log Groups for OpenSearch logs
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "opensearch" {
  for_each = toset(["INDEX_SLOW_LOGS", "SEARCH_SLOW_LOGS", "ES_APPLICATION_LOGS"])

  name              = "/aws/opensearch/${var.project}-${var.environment}/${lower(replace(each.key, "_", "-"))}"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.opensearch.arn

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_resource_policy" "opensearch" {
  policy_name = "${var.project}-${var.environment}-opensearch-logs"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
        }
        Action = [
          "logs:PutLogEvents",
          "logs:PutLogEventsBatch",
          "logs:CreateLogStream",
        ]
        Resource = "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/opensearch/${var.project}-${var.environment}/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# OpenSearch Module
# -----------------------------------------------------------------------------

module "opensearch" {
  source = "../../"

  environment = var.environment
  project     = var.project

  domain_name    = "${var.project}-${var.environment}"
  engine_version = "OpenSearch_2.11"

  # Cluster configuration
  instance_type  = "r6g.large.search"
  instance_count = 2
  zone_awareness = true

  # EBS storage
  ebs_volume_size = 100
  ebs_volume_type = "gp3"

  # Encryption (ES.1 + ES.3)
  kms_key_arn             = aws_kms_key.opensearch.arn
  node_to_node_encryption = true

  # HTTPS enforcement (ES.8)
  enforce_https       = true
  tls_security_policy = "Policy-Min-TLS-1-2-PFQ-2023-10"

  # VPC deployment (ES.2)
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.opensearch.id]

  # Fine-grained access control (ES.5)
  master_user_name            = "admin"
  secret_name_master_password = aws_secretsmanager_secret.master_password.name

  # CloudWatch logging (ES.4)
  log_types = ["INDEX_SLOW_LOGS", "SEARCH_SLOW_LOGS", "ES_APPLICATION_LOGS"]
  cloudwatch_log_group_arns = {
    INDEX_SLOW_LOGS     = aws_cloudwatch_log_group.opensearch["INDEX_SLOW_LOGS"].arn
    SEARCH_SLOW_LOGS    = aws_cloudwatch_log_group.opensearch["SEARCH_SLOW_LOGS"].arn
    ES_APPLICATION_LOGS = aws_cloudwatch_log_group.opensearch["ES_APPLICATION_LOGS"].arn
  }

  # Access policy
  access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = data.aws_caller_identity.current.account_id }
        Action    = "es:*"
        Resource  = "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/${var.project}-${var.environment}/*"
      }
    ]
  })

  tags = {
    CostCenter         = "data-platform"
    DataClassification = "Confidential"
  }

  depends_on = [
    aws_cloudwatch_log_resource_policy.opensearch,
    aws_secretsmanager_secret_version.master_password,
  ]
}
