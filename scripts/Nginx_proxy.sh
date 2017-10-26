#!/bin/bash
##############################
#Nginx_proxy反向代理服务器安装脚本
##############################
#前端serverb作为一台nginx反向代理服务器,serverc和serverd都是由serverb机器代理的web服务器
setenforce 0
iptables -F
rpm -ivh ftp://172.25.254.250/notes/project/UP200/UP200_nginx-master/pkg/nginx-1.8.0-1.el7.ngx.x86_64.rpm &> /dev/null && echo "nginx软件安装成功" || echo "未安装，请检查网络！"
systemctl start nginx
#配置反向代理服务器，HTTP负载均衡方式按权重分配
cat >> /etc/nginx/nginx.conf << EOT
	upstream apache-servers {
        server 172.25.1.12:80 weight=1;
        server 172.25.1.13:80 weight=2;
	}
EOT
cat > /etc/nginx/conf.d/proxy.com.conf << EOT
server {
	listen 80;
	server_name www.proxy.com;
	charset utf-8;
	access_log  /var/log/nginx/www.proxy.com.access.log  main;
	root /usr/share/nginx/proxy.com;
	index index.html index.htm;
	location / {
      proxy_pass http://apache-servers;
      proxy_set_header Host $host;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504 http_404;
      proxy_set_header X-Real-IP $remote_addr;
	}
}
EOT
mkdir /usr/share/nginx/proxy.com
nginx  -t
systemctl restart nginx
