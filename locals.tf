################################################################################
# Local Values
################################################################################

locals {
  # Resolved master user password: prefer direct input, fall back to Secrets Manager
  master_user_password = coalesce(
    var.master_user_password,
    try(data.aws_secretsmanager_secret_version.master_password[0].secret_string, null)
  )

  common_tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "terraform-aws-opensearch"
  })

  name_prefix = "${var.project}-${var.environment}"

  # Determine number of AZs from subnet count for zone awareness
  az_count = length(var.subnet_ids)

  # Build log publishing map from the log_types list
  log_publishing = {
    for lt in var.log_types :
    lt => lookup(var.cloudwatch_log_group_arns, lt, null)
  }
}
