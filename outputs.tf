output "my_terraform_environmnet_public_ip" {
  description = "The only IP allowed to make connect SSH connections to EC2."
  value       = chomp(data.http.icanhazip.response_body)
}

output "api_ec2_ssh_key_file" {
  description = "SSH key to connect to EC2 instance for troubleshooting."
  value       = local_file.api_ec2_ssh_key_file.filename
}

output "api_service_url" {
  description = "Where search a result."
  value       = "http://${aws_lb.api_load_balancer.dns_name}:3000/api-docs"
}
