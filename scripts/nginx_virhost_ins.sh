#!/bin/bash
############################
#nginx虚拟主机www.test.com脚本
############################
setenforce 0
iptables -F
rpm -ivh ftp://172.25.254.250/notes/project/UP200/UP200_nginx-master/pkg/nginx-1.8.0-1.el7.ngx.x86_64.rpm &> /dev/null && echo "nginx软件安装成功" || echo "未安装，请检查网络！"
systemctl start nginx

sed -i 's/^worker_processes.*/worker_processes 4/' /etc/nginx/nginx.conf
sed -i 's/^worker_connections.*/worker_connections 2048/' /etc/nginx/nginx.conf
cat > /etc/nginx/conf.d/default.conf << EOT
server {
    listen       80;
    server_name  www.test.com;
    charset utf-8;
    access_log  /var/log/nginx/www.test.com.access.log  main;

    location / {
        root   /usr/share/nginx/test.com;
        index  index.html index.htm;
    }
 }
EOT
mkdir -p /usr/share/nginx/test.com
echo welcome to www.test.com > /usr/share/nginx/test.com/index.html
ulimit -HSn 65535
nginx  -t
ps -aux |grep nginx
systemctl reload nginx


