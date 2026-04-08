#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
# Get the instance ID to show on the page (Requirement)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "<h1>TechCorp Web Server</h1><p>Instance ID: $INSTANCE_ID</p>" > /var/www/html/index.html