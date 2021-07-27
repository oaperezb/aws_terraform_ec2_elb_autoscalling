#!/bin/bash
sudo yum update -y
sudo amazon-linux-extras install nginx1 -y
echo "my private ip is $(hostname -f)" > /usr/share/nginx/html/index.html
service nginx start
sudo chown -R www-data:www-data /usr/share/nginx/html/index.html
sudo chmod -R 755 /usr/share/nginx/html/index.html