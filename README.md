# terraform-aws-opensearch

Terraform module for managing AWS OpenSearch Service domains with dual compliance defaults for **FedRAMP High** and **SOC2/CIS + Security Hub FSBP**.

## Features

- **OpenSearch Domain** -- Full domain configuration with cluster, EBS, and engine version settings
- **Encryption at Rest** -- KMS CMK encryption enforced (ES.1)
- **Node-to-Node Encryption** -- TLS between nodes enabled by default (ES.3)
- **HTTPS Enforcement** -- TLS 1.2 minimum on domain endpoint (ES.8)
- **VPC Deployment** -- Domain deployed in VPC, never publicly accessible (ES.2)
- **Fine-Grained Access Control** -- Internal user database with Secrets Manager password (ES.5)
- **Zone Awareness** -- Multi-AZ deployment for high availability (ES.7)
- **CloudWatch Logging** -- Index, search, and application logs published (ES.4)
- **Domain Access Policy** -- Optional JSON-encoded access policy
- **SAML Authentication** -- Optional SAML SSO integration
- **VPC Endpoints** -- Optional cross-VPC access without public exposure
- **Cognito Integration** -- Optional Cognito authentication for Dashboards
- **Auto-Tune** -- Optional performance tuning with maintenance schedules

## Security Hub FSBP Controls

| Control | Description | Implementation |
|---------|-------------|----------------|
| ES.1 | Encryption at rest | `encrypt_at_rest.enabled = true` with KMS CMK |
| ES.2 | VPC deployment | `vpc_options` with subnet_ids (required) |
| ES.3 | Node-to-node encryption | `node_to_node_encryption.enabled = true` |
| ES.4 | CloudWatch logging | `log_publishing_options` for 3 log types |
| ES.5 | Fine-grained access | `advanced_security_options.enabled = true` |
| ES.7 | Zone awareness | `zone_awareness_enabled = true` |
| ES.8 | HTTPS + TLS 1.2 | `enforce_https = true`, TLS 1.2 policy |

## FedRAMP High Controls

| Control | Framework | Implementation |
|---------|-----------|----------------|
| SC-28 | FedRAMP High | Encryption at rest with KMS CMK |
| SC-8 | FedRAMP High | TLS 1.2 for data in transit |
| SC-12 | FedRAMP High | KMS key management |
| AC-3/AC-4 | FedRAMP High | VPC + access policy enforcement |
| AU-2 | FedRAMP High | CloudWatch log publishing |
| CC6.1 | SOC2 | Logical access controls |
| CC6.6/CC6.7 | SOC2 | Network boundary security |

## Usage

```hcl
module "opensearch" {
  source = "path/to/terraform-aws-opensearch"

  environment = "prod"
  project     = "my-project"

  domain_name    = "my-project-prod"
  engine_version = "OpenSearch_2.11"

  # Cluster
  instance_type  = "r6g.large.search"
  instance_count = 2
  zone_awareness = true

  # Storage
  ebs_volume_size = 100
  ebs_volume_type = "gp3"

  # Encryption (ES.1 + ES.3)
  kms_key_arn             = "arn:aws:kms:us-east-1:123456789012:key/example"
  node_to_node_encryption = true

  # HTTPS (ES.8)
  enforce_https       = true
  tls_security_policy = "Policy-Min-TLS-1-2-PFQ-2023-10"

  # VPC (ES.2)
  subnet_ids         = ["subnet-abc", "subnet-def"]
  security_group_ids = ["sg-abc"]

  # Access control (ES.5)
  master_user_name            = "admin"
  secret_name_master_password = "my-project/prod/opensearch/password"

  # Logging (ES.4)
  log_types = ["INDEX_SLOW_LOGS", "SEARCH_SLOW_LOGS", "ES_APPLICATION_LOGS"]
  cloudwatch_log_group_arns = {
    INDEX_SLOW_LOGS     = "arn:aws:logs:..."
    SEARCH_SLOW_LOGS    = "arn:aws:logs:..."
    ES_APPLICATION_LOGS = "arn:aws:logs:..."
  }
}
```

## Terragrunt Usage

Place this module in your Terragrunt folder hierarchy under workload or shared-services accounts:

```
infrastructure-live/
  shared-services/
    us-east-1/
      opensearch/
        terragrunt.hcl
```

```hcl
# shared-services/us-east-1/opensearch/terragrunt.hcl

terraform {
  source = "git::https://github.com/InfiniteParallelStudios/infinite-vault.git//modules/terraform-aws-opensearch?ref=v1.0.0"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    private_subnet_ids = ["subnet-mock1", "subnet-mock2"]
    opensearch_sg_id   = "sg-mock123"
  }
}

dependency "kms" {
  config_path = "../kms"

  mock_outputs = {
    key_arn = "arn:aws:kms:us-east-1:123456789012:key/mock-key-id"
  }
}

inputs = {
  environment = "prod"
  project     = "my-project"

  domain_name    = "my-project-prod"
  engine_version = "OpenSearch_2.11"

  instance_type  = "r6g.large.search"
  instance_count = 2
  zone_awareness = true

  ebs_volume_size = 100
  ebs_volume_type = "gp3"

  kms_key_arn             = dependency.kms.outputs.key_arn
  node_to_node_encryption = true

  # VPC deployment (optional but recommended for ES.2)
  subnet_ids         = dependency.vpc.outputs.private_subnet_ids
  security_group_ids = [dependency.vpc.outputs.opensearch_sg_id]

  master_user_name            = "admin"
  secret_name_master_password = "my-project/prod/opensearch/password"

  log_types = ["INDEX_SLOW_LOGS", "SEARCH_SLOW_LOGS", "ES_APPLICATION_LOGS"]
}
```

### Dependencies

| Dependency | Output Used | Required |
|-----------|-------------|----------|
| vpc | `private_subnet_ids`, security group IDs | Optional (recommended for ES.2) |
| kms | `key_arn` | Yes (for ES.1 compliance) |
| iam | Role ARNs for Cognito/SAML | Optional |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.7 |
| aws | >= 5.40 |

## Resources

| Name | Type |
|------|------|
| aws_opensearch_domain | resource |
| aws_opensearch_domain_policy | resource |
| aws_opensearch_domain_saml_options | resource |
| aws_opensearch_vpc_endpoint | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name | string | - | yes |
| project | Project name | string | - | yes |
| tags | Additional tags | map(string) | {} | no |
| domain_name | OpenSearch domain name | string | - | yes |
| engine_version | Engine version | string | OpenSearch_2.11 | no |
| instance_type | Data node instance type | string | r6g.large.search | no |
| instance_count | Number of data nodes | number | 2 | no |
| zone_awareness | Enable multi-AZ | bool | true | no |
| ebs_volume_size | EBS volume size (GiB) | number | 100 | no |
| ebs_volume_type | EBS volume type | string | gp3 | no |
| kms_key_arn | KMS key ARN for encryption | string | - | yes |
| node_to_node_encryption | Enable node-to-node TLS | bool | true | no |
| enforce_https | Enforce HTTPS endpoint | bool | true | no |
| tls_security_policy | TLS policy (1.2 min) | string | Policy-Min-TLS-1-2-PFQ-2023-10 | no |
| subnet_ids | VPC subnet IDs | list(string) | - | yes |
| security_group_ids | Security group IDs | list(string) | - | yes |
| master_user_name | Master user name | string | - | yes |
| secret_name_master_password | Secrets Manager name | string | - | yes |
| log_types | Log types to publish | list(string) | [3 types] | no |
| cloudwatch_log_group_arns | Log group ARN map | map(string) | {} | no |
| access_policy | Domain access policy JSON | string | null | no |
| cognito_options | Cognito auth config | object | null | no |
| saml_options | SAML auth config | object | null | no |
| auto_tune | Auto-Tune config | object | null | no |
| custom_endpoint | Custom endpoint config | object | null | no |
| create_vpc_endpoint | Create VPC endpoint | bool | false | no |

## Outputs

| Name | Description |
|------|-------------|
| domain_id | Domain unique identifier |
| domain_arn | Domain ARN |
| domain_name | Domain name |
| domain_endpoint | Domain API endpoint |
| domain_dashboard_endpoint | Dashboards endpoint |
| domain_engine_version | Engine version |
| vpc_endpoint_id | VPC endpoint ID (if created) |
