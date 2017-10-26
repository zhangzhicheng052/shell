#!/bin/bash
read -p "请输入web服务器的IP（例172.25.7.10）：" ip
read -p "请输入web服务器的域名(例baidu.com)：" dn
read -p "请输入发布数据根目录：" dir
# 1、确认软件包是否已经安装
rpm -q httpd &> /dev/null && echo "apache已经安装"

#2、判断用户输入与否
while true
do
	[ -z '$ip' ] && read -p "请输入web服务器的IP（例172.25.7.10）：" ip
	[ -z '$dn' ] && read -p "请输入web服务器的域名(例baidu.com)：" dn
	[ -z '$dir' ] && read -p "请输入发布数据根目录：" dir
	if
        [ -n '$ip' ] && [ -n '$dn' ] && [ -n '$dir' ]
	then break
	fi
done

#3、搭建apache服务
mkdir $dir
cat >> /etc/httpd/conf/httpd.conf <<END
Listen $ip:8080
<VirtualHost $ip:8080>
    ServerAdmin root.$dn
    DocumentRoot "$dir"
    ServerName www.$dn
    ErrorLog "/var/log/httpd/www.$dn-error_log"
    CustomLog "/var/log/httpd/www.$dn-access_log" common
</VirtualHost>
<Directory "$dir">
AllowOverride None
    Options None
require all granted
</Directory>
END

echo "this is test page" > $dir/index.html
systemctl restart httpd
