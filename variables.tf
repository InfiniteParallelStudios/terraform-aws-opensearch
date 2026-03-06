################################################################################
# Standard Variables
################################################################################

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod). Used in resource naming and tagging."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,19}$", var.environment))
    error_message = "Environment must start with a lowercase letter, contain only lowercase alphanumeric characters and hyphens, and be at most 20 characters."
  }
}

variable "project" {
  description = "Project name. Used in resource naming and tagging."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,29}$", var.project))
    error_message = "Project must start with a lowercase letter, contain only lowercase alphanumeric characters and hyphens, and be at most 30 characters."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources. Merged with standard module tags."
  type        = map(string)
  default     = {}
}

################################################################################
# Domain Configuration
################################################################################

variable "domain_name" {
  description = "Name of the OpenSearch domain. Must be lowercase, start with a letter, and be between 3-28 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,27}$", var.domain_name))
    error_message = "Domain name must start with a lowercase letter, contain only lowercase alphanumeric characters and hyphens, and be 3-28 characters."
  }
}

variable "engine_version" {
  description = "OpenSearch engine version (e.g. OpenSearch_2.11, Elasticsearch_7.10)."
  type        = string
  default     = "OpenSearch_2.11"
}

################################################################################
# Cluster Configuration — Security Hub ES.7 (zone awareness for HA)
################################################################################

variable "instance_type" {
  description = "Instance type for data nodes."
  type        = string
  default     = "r6g.large.search"
}

variable "instance_count" {
  description = "Number of data node instances. Must be a multiple of AZ count when zone awareness is enabled (ES.7)."
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1
    error_message = "Instance count must be at least 1."
  }
}

variable "zone_awareness" {
  description = "Whether to enable zone awareness for high availability. Required for Security Hub ES.7 compliance."
  type        = bool
  default     = true
}

variable "dedicated_master_enabled" {
  description = "Whether to enable dedicated master nodes."
  type        = bool
  default     = false
}

variable "dedicated_master_count" {
  description = "Number of dedicated master nodes. Should be 3 or 5 for production."
  type        = number
  default     = 3
}

variable "dedicated_master_type" {
  description = "Instance type for dedicated master nodes."
  type        = string
  default     = "r6g.large.search"
}

variable "warm_enabled" {
  description = "Whether to enable warm storage nodes (UltraWarm)."
  type        = bool
  default     = false
}

variable "warm_count" {
  description = "Number of warm storage nodes."
  type        = number
  default     = 2
}

variable "warm_type" {
  description = "Instance type for warm storage nodes."
  type        = string
  default     = "ultrawarm1.medium.search"
}

################################################################################
# EBS Configuration
################################################################################

variable "ebs_volume_size" {
  description = "Size of EBS volumes attached to data nodes (in GiB)."
  type        = number
  default     = 100

  validation {
    condition     = var.ebs_volume_size >= 10
    error_message = "EBS volume size must be at least 10 GiB."
  }
}

variable "ebs_volume_type" {
  description = "Type of EBS volumes. Valid values: gp3, gp2, io1, io2, standard."
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp3", "gp2", "io1", "io2", "standard"], var.ebs_volume_type)
    error_message = "EBS volume type must be one of: gp3, gp2, io1, io2, standard."
  }
}

variable "ebs_iops" {
  description = "Provisioned IOPS for EBS volumes. Only applicable for io1/io2/gp3 volume types."
  type        = number
  default     = 3000
}

variable "ebs_throughput" {
  description = "Provisioned throughput in MiB/s for gp3 volumes."
  type        = number
  default     = 125
}

################################################################################
# Encryption — Security Hub ES.1 (encrypt at rest) + ES.3 (node-to-node)
################################################################################

variable "kms_key_arn" {
  description = "ARN of the KMS customer managed key for encryption at rest. Required for Security Hub ES.1 and FedRAMP High SC-28 compliance."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be a valid KMS key ARN starting with 'arn:aws:kms:'."
  }
}

variable "node_to_node_encryption" {
  description = "Whether to enable node-to-node encryption. Required for Security Hub ES.3 compliance."
  type        = bool
  default     = true
}

################################################################################
# Domain Endpoint — Security Hub ES.8 (HTTPS + TLS 1.2)
################################################################################

variable "enforce_https" {
  description = "Whether to enforce HTTPS on the domain endpoint. Required for Security Hub ES.8 compliance."
  type        = bool
  default     = true
}

variable "tls_security_policy" {
  description = "TLS security policy for the HTTPS endpoint. Must be TLS 1.2+ for Security Hub ES.8."
  type        = string
  default     = "Policy-Min-TLS-1-2-PFQ-2023-10"

  validation {
    condition     = can(regex("^Policy-Min-TLS-1-2", var.tls_security_policy))
    error_message = "TLS security policy must enforce TLS 1.2 minimum (Policy-Min-TLS-1-2-*)."
  }
}

################################################################################
# VPC Configuration — Security Hub ES.2 (not publicly accessible)
################################################################################

variable "subnet_ids" {
  description = "List of subnet IDs for the OpenSearch domain VPC configuration. Required for Security Hub ES.2 compliance (domain must not be publicly accessible)."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "At least one subnet ID must be provided for VPC deployment (ES.2 compliance)."
  }
}

variable "security_group_ids" {
  description = "List of security group IDs for the OpenSearch domain."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) >= 1
    error_message = "At least one security group ID must be provided."
  }
}

################################################################################
# Advanced Security Options — Security Hub ES.5 (fine-grained access control)
################################################################################

variable "master_user_name" {
  description = "Master user name for the internal user database. Required for Security Hub ES.5 compliance (fine-grained access control)."
  type        = string

  validation {
    condition     = length(var.master_user_name) >= 1 && length(var.master_user_name) <= 64
    error_message = "Master user name must be between 1 and 64 characters."
  }
}

variable "master_user_password" {
  description = "Master user password provided directly. Takes precedence over secret_name_master_password."
  type        = string
  default     = null
  sensitive   = true
}

variable "secret_name_master_password" {
  description = "Name of the AWS Secrets Manager secret containing the master user password. Used when master_user_password is not provided directly."
  type        = string
  default     = null
}

################################################################################
# Logging — Security Hub ES.4 (CloudWatch logging)
################################################################################

variable "log_types" {
  description = "List of log types to publish to CloudWatch. Required for Security Hub ES.4 compliance. Valid values: INDEX_SLOW_LOGS, SEARCH_SLOW_LOGS, ES_APPLICATION_LOGS, AUDIT_LOGS."
  type        = list(string)
  default     = ["INDEX_SLOW_LOGS", "SEARCH_SLOW_LOGS", "ES_APPLICATION_LOGS"]

  validation {
    condition     = alltrue([for lt in var.log_types : contains(["INDEX_SLOW_LOGS", "SEARCH_SLOW_LOGS", "ES_APPLICATION_LOGS", "AUDIT_LOGS"], lt)])
    error_message = "Log type must be one of: INDEX_SLOW_LOGS, SEARCH_SLOW_LOGS, ES_APPLICATION_LOGS, AUDIT_LOGS."
  }
}

variable "cloudwatch_log_group_arns" {
  description = "Map of log type to CloudWatch Log Group ARN for log publishing. Keys should match entries in log_types (e.g. INDEX_SLOW_LOGS, SEARCH_SLOW_LOGS, ES_APPLICATION_LOGS)."
  type        = map(string)
  default     = {}
}

################################################################################
# Cognito Options
################################################################################

variable "cognito_options" {
  description = <<-EOT
    Cognito authentication options for the OpenSearch Dashboards. Set to null to disable.
    - enabled: Whether Cognito authentication is enabled
    - user_pool_id: Cognito User Pool ID
    - identity_pool_id: Cognito Identity Pool ID
    - role_arn: IAM role ARN for Cognito access
  EOT
  type = object({
    enabled          = bool
    user_pool_id     = string
    identity_pool_id = string
    role_arn         = string
  })
  default = null
}

################################################################################
# Access Policy
################################################################################

variable "access_policy" {
  description = "JSON-encoded access policy for the OpenSearch domain. If null, a default VPC-based policy is generated."
  type        = string
  default     = null
}

################################################################################
# SAML Options
################################################################################

variable "saml_options" {
  description = <<-EOT
    SAML authentication options for the OpenSearch Dashboards. Set to null to disable.
    - enabled: Whether SAML authentication is enabled
    - idp_entity_id: Entity ID of the SAML identity provider
    - idp_metadata_content: XML metadata from the SAML identity provider
    - master_user_name: SAML master user name
    - master_backend_role: SAML master backend role
    - roles_key: SAML attribute for roles
    - subject_key: SAML attribute for subject
    - session_timeout_minutes: Session timeout in minutes
  EOT
  type = object({
    enabled                 = bool
    idp_entity_id           = string
    idp_metadata_content    = string
    master_user_name        = optional(string)
    master_backend_role     = optional(string)
    roles_key               = optional(string)
    subject_key             = optional(string)
    session_timeout_minutes = optional(number, 60)
  })
  default = null
}

################################################################################
# VPC Endpoint
################################################################################

variable "create_vpc_endpoint" {
  description = "Whether to create a VPC endpoint for the OpenSearch domain."
  type        = bool
  default     = false
}

variable "vpc_endpoint_subnet_ids" {
  description = "List of subnet IDs for the VPC endpoint. If empty, uses the domain subnet_ids."
  type        = list(string)
  default     = []
}

variable "vpc_endpoint_security_group_ids" {
  description = "List of security group IDs for the VPC endpoint. If empty, uses the domain security_group_ids."
  type        = list(string)
  default     = []
}

################################################################################
# Advanced Options
################################################################################

variable "advanced_options" {
  description = "Map of advanced options for the OpenSearch domain (e.g. rest.action.multi.allow_explicit_index)."
  type        = map(string)
  default     = {}
}

################################################################################
# Auto-Tune
################################################################################

variable "auto_tune" {
  description = <<-EOT
    Auto-Tune configuration for the OpenSearch domain. Set to null to disable.
    - desired_state: ENABLED or DISABLED
    - rollback_on_disable: DEFAULT_ROLLBACK or NO_ROLLBACK
    - maintenance_schedules: List of maintenance schedule objects
  EOT
  type = object({
    desired_state       = string
    rollback_on_disable = optional(string, "DEFAULT_ROLLBACK")
    maintenance_schedules = optional(list(object({
      cron_expression_for_recurrence = string
      start_at                       = string
      duration_value                 = number
      duration_unit                  = optional(string, "HOURS")
    })), [])
  })
  default = null
}

################################################################################
# Custom Endpoint
################################################################################

variable "custom_endpoint" {
  description = <<-EOT
    Custom endpoint configuration for the OpenSearch domain. Set to null to use default endpoint.
    - enabled: Whether custom endpoint is enabled
    - hostname: Custom hostname (e.g. search.example.com)
    - certificate_arn: ARN of the ACM certificate for the custom endpoint
  EOT
  type = object({
    enabled         = bool
    hostname        = string
    certificate_arn = string
  })
  default = null
}
