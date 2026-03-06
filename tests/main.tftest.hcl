# -----------------------------------------------------------------------------
# Terraform Tests — terraform-aws-opensearch module
# Validates Security Hub FSBP controls: ES.1-ES.8, encryption, VPC, logging
# -----------------------------------------------------------------------------

# Mock the AWS provider for plan-mode tests
mock_provider "aws" {}

# ---------------------------------------------------------------------------
# Variables shared across test runs
# ---------------------------------------------------------------------------

variables {
  environment = "dev"
  project     = "test-project"

  domain_name    = "test-domain"
  engine_version = "OpenSearch_2.11"

  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/test-key-id"

  subnet_ids         = ["subnet-abc123", "subnet-def456"]
  security_group_ids = ["sg-abc123"]

  master_user_name            = "admin"
  secret_name_master_password = "test/opensearch/master-password"

  tags = {
    TestSuite = "terraform-test"
  }
}

# ---------------------------------------------------------------------------
# Test: ES.1 — Encryption at rest with KMS CMK
# ---------------------------------------------------------------------------

run "encryption_at_rest_enabled" {
  command = plan

  assert {
    condition     = aws_opensearch_domain.this.encrypt_at_rest[0].enabled == true
    error_message = "ES.1: Encryption at rest must be enabled."
  }

  assert {
    condition     = aws_opensearch_domain.this.encrypt_at_rest[0].kms_key_id == "arn:aws:kms:us-east-1:123456789012:key/test-key-id"
    error_message = "ES.1: Encryption at rest must use the provided KMS CMK."
  }
}

# ---------------------------------------------------------------------------
# Test: ES.3 — Node-to-node encryption
# ---------------------------------------------------------------------------

run "node_to_node_encryption_enabled" {
  command = plan

  assert {
    condition     = aws_opensearch_domain.this.node_to_node_encryption[0].enabled == true
    error_message = "ES.3: Node-to-node encryption must be enabled by default."
  }
}

# ---------------------------------------------------------------------------
# Test: ES.8 — HTTPS enforcement with TLS 1.2
# ---------------------------------------------------------------------------

run "https_enforced_with_tls12" {
  command = plan

  assert {
    condition     = aws_opensearch_domain.this.domain_endpoint_options[0].enforce_https == true
    error_message = "ES.8: HTTPS must be enforced on the domain endpoint."
  }

  assert {
    condition     = aws_opensearch_domain.this.domain_endpoint_options[0].tls_security_policy == "Policy-Min-TLS-1-2-PFQ-2023-10"
    error_message = "ES.8: TLS security policy must enforce TLS 1.2 minimum."
  }
}

# ---------------------------------------------------------------------------
# Test: ES.2 — VPC deployment (not publicly accessible)
# ---------------------------------------------------------------------------

run "vpc_deployment" {
  command = plan

  assert {
    condition     = length(aws_opensearch_domain.this.vpc_options[0].subnet_ids) == 2
    error_message = "ES.2: Domain must be deployed in VPC with subnet IDs."
  }

  assert {
    condition     = length(aws_opensearch_domain.this.vpc_options[0].security_group_ids) == 1
    error_message = "ES.2: Domain must have security group IDs configured."
  }
}

# ---------------------------------------------------------------------------
# Test: ES.5 — Advanced security options (fine-grained access control)
# ---------------------------------------------------------------------------

run "advanced_security_enabled" {
  command = plan

  assert {
    condition     = aws_opensearch_domain.this.advanced_security_options[0].enabled == true
    error_message = "ES.5: Advanced security options must be enabled."
  }

  assert {
    condition     = aws_opensearch_domain.this.advanced_security_options[0].internal_user_database_enabled == true
    error_message = "ES.5: Internal user database must be enabled."
  }

  assert {
    condition     = aws_opensearch_domain.this.advanced_security_options[0].anonymous_auth_enabled == false
    error_message = "ES.5: Anonymous authentication must be disabled."
  }
}

# ---------------------------------------------------------------------------
# Test: ES.7 — Zone awareness for HA
# ---------------------------------------------------------------------------

run "zone_awareness_enabled" {
  command = plan

  assert {
    condition     = aws_opensearch_domain.this.cluster_config[0].zone_awareness_enabled == true
    error_message = "ES.7: Zone awareness must be enabled by default."
  }

  assert {
    condition     = aws_opensearch_domain.this.cluster_config[0].instance_count == 2
    error_message = "Instance count must default to 2."
  }
}

# ---------------------------------------------------------------------------
# Test: ES.4 — CloudWatch log publishing (default log types)
# ---------------------------------------------------------------------------

run "log_publishing_enabled" {
  command = plan

  assert {
    condition     = length(aws_opensearch_domain.this.log_publishing_options) == 3
    error_message = "ES.4: All three default log types must be configured for publishing."
  }
}

# ---------------------------------------------------------------------------
# Test: EBS options configured
# ---------------------------------------------------------------------------

run "ebs_configured" {
  command = plan

  assert {
    condition     = aws_opensearch_domain.this.ebs_options[0].ebs_enabled == true
    error_message = "EBS must be enabled."
  }

  assert {
    condition     = aws_opensearch_domain.this.ebs_options[0].volume_size == 100
    error_message = "EBS volume size must default to 100 GiB."
  }

  assert {
    condition     = aws_opensearch_domain.this.ebs_options[0].volume_type == "gp3"
    error_message = "EBS volume type must default to gp3."
  }
}

# ---------------------------------------------------------------------------
# Test: Tags are applied correctly with module defaults
# ---------------------------------------------------------------------------

run "tags_applied" {
  command = plan

  assert {
    condition     = aws_opensearch_domain.this.tags["Project"] == "test-project"
    error_message = "Project tag must be set correctly."
  }

  assert {
    condition     = aws_opensearch_domain.this.tags["Environment"] == "dev"
    error_message = "Environment tag must be set correctly."
  }

  assert {
    condition     = aws_opensearch_domain.this.tags["ManagedBy"] == "terraform"
    error_message = "ManagedBy tag must be set to 'terraform'."
  }

  assert {
    condition     = aws_opensearch_domain.this.tags["Module"] == "terraform-aws-opensearch"
    error_message = "Module tag must be set to 'terraform-aws-opensearch'."
  }

  assert {
    condition     = aws_opensearch_domain.this.tags["TestSuite"] == "terraform-test"
    error_message = "Custom tags must be merged into the tag set."
  }

  assert {
    condition     = aws_opensearch_domain.this.tags["Name"] == "test-domain"
    error_message = "Name tag must match domain name."
  }
}

# ---------------------------------------------------------------------------
# Test: Domain name and engine version are correct
# ---------------------------------------------------------------------------

run "domain_config" {
  command = plan

  assert {
    condition     = aws_opensearch_domain.this.domain_name == "test-domain"
    error_message = "Domain name must match provided value."
  }

  assert {
    condition     = aws_opensearch_domain.this.engine_version == "OpenSearch_2.11"
    error_message = "Engine version must match provided value."
  }
}

# ---------------------------------------------------------------------------
# Test: No domain policy when access_policy is null
# ---------------------------------------------------------------------------

run "no_policy_by_default" {
  command = plan

  assert {
    condition     = length(aws_opensearch_domain_policy.this) == 0
    error_message = "Domain policy should not be created when access_policy is null."
  }
}

# ---------------------------------------------------------------------------
# Test: Domain policy created when access_policy is provided
# ---------------------------------------------------------------------------

run "policy_when_provided" {
  command = plan

  variables {
    access_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"AWS\":\"*\"},\"Action\":\"es:*\",\"Resource\":\"*\"}]}"
  }

  assert {
    condition     = length(aws_opensearch_domain_policy.this) == 1
    error_message = "Domain policy must be created when access_policy is provided."
  }
}

# ---------------------------------------------------------------------------
# Test: No VPC endpoint by default
# ---------------------------------------------------------------------------

run "no_vpc_endpoint_by_default" {
  command = plan

  assert {
    condition     = length(aws_opensearch_vpc_endpoint.this) == 0
    error_message = "VPC endpoint should not be created by default."
  }
}

# ---------------------------------------------------------------------------
# Test: No SAML options by default
# ---------------------------------------------------------------------------

run "no_saml_by_default" {
  command = plan

  assert {
    condition     = length(aws_opensearch_domain_saml_options.this) == 0
    error_message = "SAML options should not be created by default."
  }
}
