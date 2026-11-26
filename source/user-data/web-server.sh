#!/bin/bash
dnf update -y
dnf install -y nginx
systemctl enable --now nginx

# Simple health endpoint for the ALB
mkdir -p /usr/share/nginx/html
echo "ok" > /usr/share/nginx/html/health

# Show which instance and AZ served the request
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)
ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)
echo "<h1>Hello from $ID in $AZ</h1>" > /usr/share/nginx/html/index.html
