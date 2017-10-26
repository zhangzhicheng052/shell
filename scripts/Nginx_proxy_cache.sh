#!/bin/bash
##################################
#Nginx_proxy反向代理+缓存服务器安装脚本
##################################
#前端serverb作为一台nginx反向代理服务器,serverc和serverd都是由serverb机器代理的web服务器
setenforce 0
iptables -F
rpm -ivh ftp://172.25.254.250/notes/project/UP200/UP200_nginx-master/pkg/nginx-1.8.0-1.el7.ngx.x86_64.rpm &> /dev/null && echo "nginx软件安装成功" || echo "未安装，请检查网络！"
systemctl start nginx

#HTTP负载均衡模块+Nginx缓存
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
	
	proxy_redirect off;
	client_max_body_size 10m;
	client_body_buffer_size 128k;
	proxy_connect_timeout 90;
	proxy_send_timeout 90;
	proxy_read_timeout 90;
	proxy_cache cache_web;
	proxy_cache_valid 200 302 12h;
	proxy_cache_valid 301 1d;
	proxy_cache_valid any 1h;
	proxy_buffer_size 4k;
	proxy_buffers 4 32k;
	proxy_busy_buffers_size 64k;
	proxy_temp_file_write_size 64k;	
	}
}
EOT
#修改主配置文件，定义Nginx缓存,HTTP负载均衡方式按权重分配
cat >> /etc/nginx/nginx.conf << EOT
	proxy_temp_path /usr/share/nginx/proxy_temp_dir 1 2;
	proxy_cache_path /usr/share/nginx/proxy_cache_dir levels=1:2 keys_zone=cache_web:50m inactive=1d max_size=30g;	
	
	upstream apache-servers {
        	server 172.25.17.12:80 weight=1;
        	server 172.25.17.13:80 weight=2;
	}
EOT
#修改主配置文件，HTTP负载均衡方式按ip_hash分配,每个访客固定访问一个后端服务器
#cat >> /etc/nginx/nginx.conf << EOT
#	proxy_temp_path /usr/share/nginx/proxy_temp_dir 1 2;
#	proxy_cache_path /usr/share/nginx/proxy_cache_dir levels=1:2 keys_zone=cache_web:50m inactive=1d max_size=30g;
#	upstream apache-servers {
#        	ip_hash;
#        	server 172.25.17.12:80 weight=1;
#        	server 172.25.17.13:80 weight=1;
#    	}
#EOT
#修改主配置文件，HTTP负载均衡方式按轮询(默认)
#cat >> /etc/nginx/nginx.conf << EOT	
#	proxy_temp_path /usr/share/nginx/proxy_temp_dir 1 2;
#	proxy_cache_path /usr/share/nginx/proxy_cache_dir levels=1:2 keys_zone=cache_web:50m inactive=1d max_size=30g;
#	upstream apache-servers {
#        	server 172.25.17.12:80 ;
#        	server 172.25.17.13:80 ;
#    	}
#EOT
mkdir -p /usr/share/nginx/proxy_temp_dir /usr/share/nginx/proxy_cache_dir
chown nginx /usr/share/nginx/proxy_temp_dir/ /usr/share/nginx/proxy_cache_dir/
mkdir /usr/share/nginx/proxy.com
nginx  -t
systemctl restart nginx
