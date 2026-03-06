################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

################################################################################
# Secrets Manager — Master User Password (conditional)
#
# Only queried when master_user_password is not provided directly and
# secret_name_master_password is set. Direct input takes precedence.
################################################################################

data "aws_secretsmanager_secret" "master_password" {
  count = var.master_user_password == null && var.secret_name_master_password != null ? 1 : 0
  name  = var.secret_name_master_password
}

data "aws_secretsmanager_secret_version" "master_password" {
  count     = var.master_user_password == null && var.secret_name_master_password != null ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.master_password[0].id
}
