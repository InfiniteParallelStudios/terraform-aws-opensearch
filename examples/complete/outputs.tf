# -----------------------------------------------------------------------------
# Example Outputs
# -----------------------------------------------------------------------------

output "domain_id" {
  description = "The unique identifier for the OpenSearch domain"
  value       = module.opensearch.domain_id
}

output "domain_arn" {
  description = "The ARN of the OpenSearch domain"
  value       = module.opensearch.domain_arn
}

output "domain_endpoint" {
  description = "The domain-specific endpoint for OpenSearch APIs"
  value       = module.opensearch.domain_endpoint
}

output "domain_dashboard_endpoint" {
  description = "The domain-specific endpoint for OpenSearch Dashboards"
  value       = module.opensearch.domain_dashboard_endpoint
}

output "vpc_id" {
  description = "The VPC ID used for the OpenSearch domain"
  value       = aws_vpc.this.id
}

output "security_group_id" {
  description = "The security group ID for the OpenSearch domain"
  value       = aws_security_group.opensearch.id
}
