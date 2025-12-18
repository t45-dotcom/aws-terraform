output "instance_id" {
  value       = length(aws_instance.web_server) > 0 ? aws_instance.web_server[0].id : null
  description = "ID of the first EC2 instance (for backward compatibility)"
}

output "instance_ids" {
  value       = aws_instance.web_server[*].id
  description = "List of EC2 instance IDs"
}

output "instance_arn" {
  value       = length(aws_instance.web_server) > 0 ? aws_instance.web_server[0].arn : null
  description = "ARN of the first EC2 instance (for backward compatibility)"
}

output "instance_arns" {
  value       = aws_instance.web_server[*].arn
  description = "List of EC2 instance ARNs"
}

output "instance_public_ip" {
  value       = length(aws_instance.web_server) > 0 ? aws_instance.web_server[0].public_ip : null
  description = "Public IP address of the first EC2 instance (for backward compatibility)"
}

output "instance_public_ips" {
  value       = aws_instance.web_server[*].public_ip
  description = "List of public IP addresses of EC2 instances"
}

output "instance_public_dns" {
  value       = length(aws_instance.web_server) > 0 ? aws_instance.web_server[0].public_dns : null
  description = "Public DNS name of the first EC2 instance (for backward compatibility)"
}

output "instance_public_dns_names" {
  value       = aws_instance.web_server[*].public_dns
  description = "List of public DNS names of EC2 instances"
}

