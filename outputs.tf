################################################################################
# Domain Outputs
################################################################################

output "domain_id" {
  description = "Unique identifier for the OpenSearch domain."
  value       = aws_opensearch_domain.this.domain_id
}

output "domain_arn" {
  description = "ARN of the OpenSearch domain."
  value       = aws_opensearch_domain.this.arn
}

output "domain_name" {
  description = "Name of the OpenSearch domain."
  value       = aws_opensearch_domain.this.domain_name
}

output "domain_endpoint" {
  description = "Domain-specific endpoint used for requests to the OpenSearch APIs."
  value       = aws_opensearch_domain.this.endpoint
}

output "domain_dashboard_endpoint" {
  description = "Domain-specific endpoint for the OpenSearch Dashboards application."
  value       = aws_opensearch_domain.this.dashboard_endpoint
}

output "kibana_endpoint" {
  description = "OpenSearch Dashboards endpoint (alias for domain_dashboard_endpoint)."
  value       = aws_opensearch_domain.this.dashboard_endpoint
}

output "domain_engine_version" {
  description = "OpenSearch engine version running on the domain."
  value       = aws_opensearch_domain.this.engine_version
}

################################################################################
# VPC Endpoint Outputs
################################################################################

output "vpc_endpoint_id" {
  description = "ID of the OpenSearch VPC endpoint. Null if VPC endpoint is not created."
  value       = var.create_vpc_endpoint ? aws_opensearch_vpc_endpoint.this[0].id : null
}
