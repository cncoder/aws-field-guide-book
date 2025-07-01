#!/bin/bash

# Update system
yum update -y

# Install PostgreSQL 14 client
amazon-linux-extras install -y postgresql14

# Create demo directory
mkdir -p /home/ec2-user/${project_name}
chown ec2-user:ec2-user /home/ec2-user/${project_name}

# Create helpful scripts for the demo user
cat > /home/ec2-user/${project_name}/README.txt << 'EOF'
Aurora PostgreSQL FDW Demo Environment

This EC2 instance has been configured with:
- PostgreSQL 14 client
- Access to Aurora clusters via private networking

To get started:
1. Set your environment variables (see demo documentation)
2. Connect to Aurora clusters using psql
3. Follow the demo steps in the documentation

Example connection:
psql -h <aurora-endpoint> -U postgres -d <database-name>
EOF

# Set proper permissions
chown -R ec2-user:ec2-user /home/ec2-user/${project_name}

# Log completion
echo "$(date): Aurora FDW Demo environment setup completed" >> /var/log/user-data.log
