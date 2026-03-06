################################################################################
# OpenSearch Domain
#
# Satisfies:
#   - Security Hub ES.1: OpenSearch domains should have encryption at rest
#     enabled with KMS CMK
#   - Security Hub ES.2: OpenSearch domains should be in a VPC (not public)
#   - Security Hub ES.3: OpenSearch domains should encrypt data sent between
#     nodes (node-to-node encryption)
#   - Security Hub ES.4: OpenSearch domain error logging to CloudWatch Logs
#     should be enabled
#   - Security Hub ES.5: OpenSearch domains should have audit logging enabled
#     (fine-grained access control)
#   - Security Hub ES.7: OpenSearch domains should be configured with at least
#     three dedicated master nodes (zone awareness for HA)
#   - Security Hub ES.8: Connections to OpenSearch domains should be encrypted
#     using TLS 1.2 (enforce_https + TLS policy)
#   - FedRAMP High SC-28: Protection of information at rest
#   - FedRAMP High SC-8: Transmission confidentiality and integrity
#   - FedRAMP High SC-12: Cryptographic key management
#   - FedRAMP High AU-2: Audit events (CloudWatch logging)
#   - FedRAMP High AC-4: Information flow enforcement (VPC)
#   - SOC2 CC6.1: Logical and physical access controls
#   - SOC2 CC6.6: Security measures against threats outside system boundaries
#   - SOC2 CC6.7: Restriction of data transmission/movement
#   - CIS AWS 2.x: Encryption standards
################################################################################

resource "aws_opensearch_domain" "this" {
  domain_name    = var.domain_name
  engine_version = var.engine_version

  # --- Cluster configuration (ES.7: zone awareness for HA) ---
  cluster_config {
    instance_type  = var.instance_type
    instance_count = var.instance_count

    zone_awareness_enabled = var.zone_awareness

    dynamic "zone_awareness_config" {
      for_each = var.zone_awareness ? [1] : []
      content {
        availability_zone_count = local.az_count >= 3 ? 3 : 2
      }
    }

    dedicated_master_enabled = var.dedicated_master_enabled
    dedicated_master_count   = var.dedicated_master_enabled ? var.dedicated_master_count : null
    dedicated_master_type    = var.dedicated_master_enabled ? var.dedicated_master_type : null

    warm_enabled = var.warm_enabled
    warm_count   = var.warm_enabled ? var.warm_count : null
    warm_type    = var.warm_enabled ? var.warm_type : null
  }

  # --- EBS storage ---
  ebs_options {
    ebs_enabled = true
    volume_size = var.ebs_volume_size
    volume_type = var.ebs_volume_type
    iops        = contains(["gp3", "io1", "io2"], var.ebs_volume_type) ? var.ebs_iops : null
    throughput  = var.ebs_volume_type == "gp3" ? var.ebs_throughput : null
  }

  # --- ES.1: Encryption at rest with KMS CMK ---
  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_arn
  }

  # --- ES.3: Node-to-node encryption ---
  node_to_node_encryption {
    enabled = var.node_to_node_encryption
  }

  # --- ES.8: HTTPS enforcement with TLS 1.2 ---
  domain_endpoint_options {
    enforce_https       = var.enforce_https
    tls_security_policy = var.tls_security_policy

    custom_endpoint_enabled         = var.custom_endpoint != null ? var.custom_endpoint.enabled : false
    custom_endpoint                 = var.custom_endpoint != null ? var.custom_endpoint.hostname : null
    custom_endpoint_certificate_arn = var.custom_endpoint != null ? var.custom_endpoint.certificate_arn : null
  }

  # --- ES.2: VPC deployment (not publicly accessible) ---
  vpc_options {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  # --- ES.5: Advanced security options (fine-grained access control) ---
  advanced_security_options {
    enabled                        = true
    anonymous_auth_enabled         = false
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = var.master_user_name
      master_user_password = local.master_user_password
    }
  }

  # --- ES.4: CloudWatch log publishing ---
  dynamic "log_publishing_options" {
    for_each = local.log_publishing
    content {
      log_type                 = log_publishing_options.key
      cloudwatch_log_group_arn = log_publishing_options.value
      enabled                  = true
    }
  }

  # --- Cognito integration (optional) ---
  dynamic "cognito_options" {
    for_each = var.cognito_options != null ? [var.cognito_options] : []
    content {
      enabled          = cognito_options.value.enabled
      user_pool_id     = cognito_options.value.user_pool_id
      identity_pool_id = cognito_options.value.identity_pool_id
      role_arn         = cognito_options.value.role_arn
    }
  }

  # --- Auto-Tune (optional) ---
  dynamic "auto_tune_options" {
    for_each = var.auto_tune != null ? [var.auto_tune] : []
    content {
      desired_state       = auto_tune_options.value.desired_state
      rollback_on_disable = auto_tune_options.value.rollback_on_disable

      dynamic "maintenance_schedule" {
        for_each = auto_tune_options.value.maintenance_schedules
        content {
          cron_expression_for_recurrence = maintenance_schedule.value.cron_expression_for_recurrence
          start_at                       = maintenance_schedule.value.start_at

          duration {
            value = maintenance_schedule.value.duration_value
            unit  = maintenance_schedule.value.duration_unit
          }
        }
      }
    }
  }

  # --- Advanced options ---
  advanced_options = var.advanced_options

  tags = merge(local.common_tags, {
    Name = var.domain_name
  })
}

################################################################################
# OpenSearch Domain Policy
#
# Satisfies:
#   - FedRAMP High AC-3: Access enforcement
#   - FedRAMP High AC-4: Information flow enforcement
#   - SOC2 CC6.1: Logical and physical access controls
################################################################################

resource "aws_opensearch_domain_policy" "this" {
  count = var.access_policy != null ? 1 : 0

  domain_name     = aws_opensearch_domain.this.domain_name
  access_policies = var.access_policy
}

################################################################################
# OpenSearch Domain SAML Options (optional)
#
# Satisfies:
#   - FedRAMP High IA-2: Identification and authentication (federated)
#   - FedRAMP High IA-8: Identification and authentication (non-org users)
#   - SOC2 CC6.1: Logical and physical access controls
################################################################################

resource "aws_opensearch_domain_saml_options" "this" {
  count = var.saml_options != null ? 1 : 0

  domain_name = aws_opensearch_domain.this.domain_name

  saml_options {
    enabled = var.saml_options.enabled

    idp {
      entity_id        = var.saml_options.idp_entity_id
      metadata_content = var.saml_options.idp_metadata_content
    }

    master_user_name        = var.saml_options.master_user_name
    master_backend_role     = var.saml_options.master_backend_role
    roles_key               = var.saml_options.roles_key
    subject_key             = var.saml_options.subject_key
    session_timeout_minutes = var.saml_options.session_timeout_minutes
  }
}

################################################################################
# OpenSearch VPC Endpoint (optional)
#
# Provides cross-VPC access to the OpenSearch domain without public exposure.
################################################################################

resource "aws_opensearch_vpc_endpoint" "this" {
  count = var.create_vpc_endpoint ? 1 : 0

  domain_arn = aws_opensearch_domain.this.arn

  vpc_options {
    subnet_ids         = length(var.vpc_endpoint_subnet_ids) > 0 ? var.vpc_endpoint_subnet_ids : var.subnet_ids
    security_group_ids = length(var.vpc_endpoint_security_group_ids) > 0 ? var.vpc_endpoint_security_group_ids : var.security_group_ids
  }
}
