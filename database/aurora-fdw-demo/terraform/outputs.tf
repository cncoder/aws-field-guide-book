output "database_a_writer_endpoint" {
  description = "Database A writer endpoint"
  value       = aws_rds_cluster.database_a.endpoint
}

output "database_a_reader_endpoint" {
  description = "Database A reader endpoint"
  value       = aws_rds_cluster.database_a.reader_endpoint
}

output "database_b_writer_endpoint" {
  description = "Database B writer endpoint"
  value       = aws_rds_cluster.database_b.endpoint
}

output "database_username" {
  description = "Database master username"
  value       = var.db_master_username
}

output "database_password" {
  description = "Database master password"
  value       = var.db_master_password
  sensitive   = true
}

output "connection_info" {
  description = "Database connection information"
  value = {
    users_db = {
      writer_host = aws_rds_cluster.database_a.endpoint
      reader_host = aws_rds_cluster.database_a.reader_endpoint
      database    = aws_rds_cluster.database_a.database_name
      port        = aws_rds_cluster.database_a.port
    }
    orders_db = {
      writer_host = aws_rds_cluster.database_b.endpoint
      database    = aws_rds_cluster.database_b.database_name
      port        = aws_rds_cluster.database_b.port
    }
  }
}

output "ec2_instance_id" {
  description = "EC2 bastion instance ID for SSM connection"
  value       = aws_instance.bastion.id
}

output "ssm_connect_command" {
  description = "AWS CLI command to connect via SSM"
  value       = "aws ssm start-session --target ${aws_instance.bastion.id} --region ${var.aws_region}"
}

output "environment_setup_commands" {
  description = "Commands to set up environment variables"
  value = {
    bash_commands = [
      "export PGPASSWORD='${var.db_master_password}'",
      "export USERS_WRITER='${aws_rds_cluster.database_a.endpoint}'",
      "export USERS_READER='${aws_rds_cluster.database_a.reader_endpoint}'",
      "export ORDERS_WRITER='${aws_rds_cluster.database_b.endpoint}'"
    ]
  }
  sensitive = true
}
