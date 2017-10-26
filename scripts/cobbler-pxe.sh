#!/bin/bash
###########################
#Cobbler-pxe网络无人值守安装脚本
###########################

#将servera服务器当成路由器（构造局域网)
#设置serverb服务器关闭eth0 设置eth1的网关
#生成密钥对ssh-keygen (默认回车)，分别推送公钥到servera和serverb

#设置servera
ssh root@172.25.17.10
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
setenforce 0 &> /dev/null
iptables -F
sed -i '$a net.ipv4.ip_forward = 1' /etc/sysctl.conf
sysctl -p
iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -j SNAT --to-source 172.25.17.10
exit

#设置serverb
ssh root@192.168.0.16
hostnamectl set-hostname cobbler
bash
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
setenforce 0 &> /dev/null
iptables -F
sed -i 's/ONBOOT=yes/ONBOOT=no/' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i '$a GATEWAY=192.168.0.10' /etc/sysconfig/network-scripts/ifcfg-eth1
systemctl restart network

#下载并安装cobbler，启动服务
wget -r ftp://172.25.254.250/notes/project/software/cobbler_rhel7/
mv 172.25.254.250/notes/project/software/cobbler_rhel7/ cobbler
cd cobbler/
rpm -ivh python2-simplejson-3.10.0-1.el7.x86_64.rpm &>/dev/null
rpm -ivh python-django-1.6.11.6-1.el7.noarch.rpm python-django-bash-completion-1.6.11.6-1.el7.noarch.rpm &>/dev/null
yum localinstall cobbler-2.8.1-2.el7.x86_64.rpm cobbler-web-2.8.1-2.el7.noarch.rpm &>/dev/null
yum list |grep python >&/dev/null && echo "cobbler安装成功"
systemctl restart cobblerd
systemctl restart httpd
systemctl enable httpd
systemctl enable cobblerd

#cobbler check检测环境
cobbler check &>/dev/null
sed -i 's/^server:.*/server: 192.168.0.11/' /etc/cobbler/settings
sed -i 's/^next_server:.*/next_server: 192.168.0.11/' /etc/cobbler/settings
sed -i 's/disable.*/disable=no/' /etc/xinetd.d/tftp
yum -y install syslinux &>/dev/null
systemctl start rsyncd
systemctl enable rsyncd
netstat -tnpl |grep :873 >&/dev/null && echo "rsync安装成功"
yum -y install pykickstart &>/dev/null

sed -i 's/^default_password_crypted:.*/default_password_crypted: "$1$random-p$MvGDzDfse5HkTwXB2OLNb."/' /etc/cobbler/settings
yum -y install fence-agents &>/dev/null

#导入镜像
mkdir /yum
ping -c 3 172.25.254.250 &> /dev/null && echo "网络OK"
mount -t nfs 172.25.254.250:/content /mnt/
mount -o loop /mnt/rhel7.2/x86_64/isos/rhel-server-7.2-x86_64-dvd.iso /yum/
cobbler import --path=/yum --name=rhel-server-7.2-base --arch=x86_64 &> /dev/null

#修改dhcp，让cobbler来管理dhcp，并进行cobbler配置同步
yum -y install dhcp &>/dev/null && echo "dhcp安装成功"
sed -i 's/192.168.1/192.168.0/g' /etc/cobbler/dhcp.template
sed -i 's/option routers.*/option routers             192.168.0.10;/' /etc/cobbler/dhcp.template
sed -i 's/option domain-name-servers 192.168.0.1;/option domain-name-servers 172.25.254.254;/' /etc/cobbler/dhcp.template

#重启cobbler
sed -i 's/^manage_dhcp:.*/manage_dhcp: 1/' /etc/cobbler/settings
systemctl restart cobblerd && echo "cobbler重启成功,进入数据通步cobbler sync"

#同步cobbler配置，并初始化
cobbler sync
systemctl restart xinetd
systemctl enable xinetd
exit