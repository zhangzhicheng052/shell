#!/bin/bash
############################
#nginx_rewrite地址重写脚本
############################
#用户访问www.joy.com网站news目录时，实现用户访问该目录下任何一个文件，返回的都是首页文件，并给用户以提示
#用户访问tom.joy.com网站时访问的实际位置为/usr/share/nginx/joy.com/tom 目录下的文件
setenforce 0
iptables -F
rpm -ivh ftp://172.25.254.250/notes/project/UP200/UP200_nginx-master/pkg/nginx-1.8.0-1.el7.ngx.x86_64.rpm &> /dev/null && echo "nginx软件安装成功" || echo "未安装，请检查网络！"
systemctl start nginx

sed -i 's/^worker_processes.*/worker_processes 4/' /etc/nginx/nginx.conf
sed -i 's/^worker_connections.*/worker_connections 2048/' /etc/nginx/nginx.conf
cat > /etc/nginx/conf.d/joy.com.conf << EOT
server {
	listen 80;
	server_name www.joy.com;
	charset utf-8;
	access_log  /var/log/nginx/www.joy.com.access.log  main;
	root /usr/share/nginx/joy.com;
	index index.html index.htm;
	
	location ~* /news/ {
		rewrite ^/news/.* /news/index.html break;
 	}

	if ( $http_host ~* ^www\.joy\.com$ ) {    
 		break;
 		}
 	if ( $http_host ~* ^(.*)\.joy\.com$ ) {    
 		set $domain $1;	
 		rewrite /.* /$domain/index.html break;
 	}
}
EOT
mkdir /usr/share/nginx/joy.com
mkdir /usr/share/nginx/joy.com/news
mkdir /usr/share/nginx/joy.com/tom
echo www.joy.com > /usr/share/nginx/joy.com/index.html
echo sorry,building now > /usr/share/nginx/joy.com/news/index.html
echo tom.joy.com > /usr/share/nginx/joy.com/tom/index.html
cd /usr/share/nginx/joy.com/news/
touch new1.html
touch new2.html
ulimit -HSn 65535
nginx  -t
systemctl restart nginx
