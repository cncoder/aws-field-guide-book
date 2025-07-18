output "msk_cluster_arn" {
  description = "ARN of the MSK cluster"
  value       = aws_msk_cluster.msk_cluster.arn
}

output "msk_cluster_name" {
  description = "Name of the MSK cluster"
  value       = aws_msk_cluster.msk_cluster.cluster_name
}

output "msk_bootstrap_brokers_tls" {
  description = "TLS connection host:port pairs"
  value       = aws_msk_cluster.msk_cluster.bootstrap_brokers_tls
}

output "msk_bootstrap_brokers_sasl_scram" {
  description = "SASL/SCRAM connection host:port pairs"
  value       = aws_msk_cluster.msk_cluster.bootstrap_brokers_sasl_scram
}

output "msk_bootstrap_brokers_sasl_iam" {
  description = "SASL/IAM connection host:port pairs"
  value       = aws_msk_cluster.msk_cluster.bootstrap_brokers_sasl_iam
}

output "msk_zookeeper_connect_string" {
  description = "Zookeeper connection string"
  value       = aws_msk_cluster.msk_cluster.zookeeper_connect_string
}

output "ec2_instance_id" {
  description = "ID of the EC2 client instance"
  value       = aws_instance.kafka_client.id
}

output "ec2_private_ip" {
  description = "Private IP of the EC2 client instance"
  value       = aws_instance.kafka_client.private_ip
}

output "scram_secret_arn" {
  description = "ARN of the SCRAM secret"
  value       = aws_secretsmanager_secret.msk_scram.arn
}

output "scram_secret_name" {
  description = "Name of the SCRAM secret"
  value       = "AmazonMSK_${var.project_name}-msk-scram-credentials"
}

output "iam_role_arn" {
  description = "ARN of the IAM role for EC2 instance"
  value       = aws_iam_role.ec2_msk_role.arn
}

output "security_group_msk_id" {
  description = "ID of the MSK security group"
  value       = aws_security_group.msk_cluster.id
}

output "security_group_ec2_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2_client.id
}
