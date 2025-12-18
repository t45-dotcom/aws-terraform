output "instance_public_ip" {
  value       = module.ec2.instance_public_ip
  description = "Public IP address of the first EC2 instance (for backward compatibility)"
}

output "instance_public_ips" {
  value       = module.ec2.instance_public_ips
  description = "List of public IP addresses of all EC2 instances"
}

output "instance_public_dns" {
  value       = module.ec2.instance_public_dns
  description = "Public DNS name of the first EC2 instance (for backward compatibility)"
}

output "instance_public_dns_names" {
  value       = module.ec2.instance_public_dns_names
  description = "List of public DNS names of all EC2 instances"
}

output "instance_id" {
  value       = module.ec2.instance_id
  description = "ID of the first EC2 instance (for backward compatibility)"
}

output "instance_ids" {
  value       = module.ec2.instance_ids
  description = "List of all EC2 instance IDs"
}

output "instance_arn" {
  value       = module.ec2.instance_arn
  description = "ARN of the first EC2 instance (for backward compatibility)"
}

output "instance_arns" {
  value       = module.ec2.instance_arns
  description = "List of all EC2 instance ARNs"
}

output "security_group_id" {
  value       = module.security_group.security_group_id
  description = "ID of the security group"
}

output "security_group_name" {
  value       = module.security_group.security_group_name
  description = "Name of the security group"
}

output "instance_url" {
  value       = module.ec2.instance_public_ip != null ? "http://${module.ec2.instance_public_ip}" : null
  description = "URL to access the first web server (for backward compatibility)"
}

output "instance_urls" {
  value       = [for ip in module.ec2.instance_public_ips : "http://${ip}"]
  description = "List of URLs to access all web servers"
}

output "ssh_command" {
  value       = module.ec2.instance_public_ip != null ? "ssh -i <your-key.pem> ubuntu@${module.ec2.instance_public_ip}" : null
  description = "SSH command to connect to the first instance (for backward compatibility)"
}

output "ssh_commands" {
  value       = [for ip in module.ec2.instance_public_ips : "ssh -i <your-key.pem> ubuntu@${ip}"]
  description = "List of SSH commands to connect to all instances"
}

output "ami_id_used" {
  value       = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  description = "AMI ID used for the instance"
}
