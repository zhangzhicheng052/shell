#!/bin/bash
#zabbix基本组件：server服务端、agent数据收集端、web配置管理端、数据库端
#生成密钥对ssh-keygen(默认回车)，分别推送公钥到servera,serverb,serverc,serverd

# Server端的安装
ssh root@172.25.17.11
timedatectl set-timezone Asia/Shanghai
setenforce 0
tar -xf zabbix-2.4.6.tar.gz -C /tmp
yum -y install gcc gcc-c++ mariadb-devel libxml2-devel net-snmp-devel libcurl-devel
cd /tmp/zabbix-2.4.6
./configure --prefix=/usr/local/zabbix --enable-server --with-mysql --with-net-snmp --with-libcurl --with-libxml2 --enable-agent --enable-ipv6
make&&makeinstall
useradd zabbix

sed -i 's/^DBHost=.*/DBHost=172.25.17.13/' /usr/local/zabbix/etc/zabbix_server.conf
sed -i 's/^DBName=.*/DBName=zabbix/' /usr/local/zabbix/etc/zabbix_server.conf
sed -i 's/^DBUser=.*/DBUser=zabbix/' /usr/local/zabbix/etc/zabbix_server.conf
sed -i 's/^DBPassword=.*/DBPassword=uplooking/' /usr/local/zabbix/etc/zabbix_server.conf
cd /tmp/zabbix-2.4.6/database/mysql/
scp * 172.25.17.13:/tmp
exit

# Database端的安装
ssh root@172.25.17.13
setenforce 0
yum -y install mariadb-server
systemctl start mariadb
mysql
create database zabbix;
exit
mysql zabbix < /tmp/schema.sql
mysql zabbix < /tmp/images.sql
mysql zabbix < /tmp/data.sql
mysql
grant all on zabbix.* to zabbix@'172.25.17.11' identified by '123456';
grant all on zabbix.* to zabbix@'172.25.17.12' identified by '123456';
flush privileges;
Bye
exit

# Web端的安装
ssh root@172.25.17.12
setenforce 0
yum -y install httpd php php-mysql &> /dev/null
yum -y localinstall zabbix-web-2.4.6-1.el7.noarch.rpm zabbix-web-mysql-2.4.6-1.el7.noarch.rpm php-mbstring-5.4.16-23.el7_0.3.x86_64.rpm php-bcmath-5.4.16-23.el7_0.3.x86_64.rpm &> /dev/null
sed -i 's/^php_value date.timezone.*/php_value date.timezone Asia/Shanghai/' /etc/httpd/conf.d/zabbix.conf
systemctl restart httpd
exit

# Agent端的安装
ssh root@172.25.17.10
rpm -ivh zabbix-2.4.6-1.el7.x86_64.rpm zabbix-agent-2.4.6-1.el7.x86_64.rpm
yum -y install net-snmp net-snmp-utils &> /dev/null
sed -i 's/^Server=.*/Server=172.25.17.11/' /etc/zabbix/zabbix_agentd.conf
sed -i 's/^ServerActive=.*/ServerActive=172.25.17.11/' /etc/zabbix/zabbix_agentd.conf
sed -i 's/^Hostname=.*/Hostname=servera.pod17.example.com/' /etc/zabbix/zabbix_agentd.conf
sed -i 's/^UnsafeUserParameters=.*/UnsafeUserParameters=1/' /etc/zabbix/zabbix_agentd.conf
systemctl restart zabbix-agent
exit

ssh root@172.25.17.11
cd /usr/local/zabbix/sbin/
./zabbix_server
exit

firefox http://172.25.17.12/zabbix
