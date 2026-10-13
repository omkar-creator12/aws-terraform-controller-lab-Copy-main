output "controller_public_ip" {
  description = "Public IP of the Terraform controller"
  value       = aws_instance.terraform_runner.public_ip
}

output "ssh_command" {
  description = "SSH connection command"
  value       = "ssh -i ${local_file.private_key_pem.filename} ubuntu@${aws_instance.terraform_runner.public_ip}"
}
