#!/bin/bash
####################
#PXE网络无人值守安装脚本
####################

#将servera服务器当成路由器（构造局域网)
#设置serverg服务器关闭eth0 设置eth1的网关
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
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
echo "/sbin/setenforce 0" >> /etc/rc.local
chmod +x /etc/rc.local
source  /etc/rc.local
iptables -F
sed -i 's/ONBOOT=yes/ONBOOT=no/' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i '$a GATEWAY=192.168.0.10' /etc/sysconfig/network-scripts/ifcfg-eth1
systemctl restart network

#下载iso ，发布iso，配置yum源
ping -c 3 172.25.254.250 &> /dev/null && echo "网络OK"
mount -t nfs 172.25.254.250:/content /mnt/
mkdir /yum
mount -o loop /mnt/rhel7.1/x86_64/isos/rhel-server-7.1-x86_64-dvd.iso  /yum/
cd /etc/yum.repos.d/
find . -regex '.*\.repo$' -exec mv {} {}.back \;

cat > /etc/yum.repos.d/local.repo << EOT
[local]
baseurl=file:///yum
gpgcheck=0
EOT
yum clean all

#搭建DHCP服务
yum -y install dhcp &> /dev/null
\cp /usr/share/doc/dhcp-4.2.5/dhcpd.conf.example  /etc/dhcp/dhcpd.conf
cat > /etc/dhcp/dhcpd.conf << EOT
allow booting;
allow bootp;
option domain-name "pod1.example.com";
option domain-name-servers 172.25.254.254;
default-lease-time 600;
max-lease-time 7200;
log-facility local7;
subnet 192.168.0.0 netmask 255.255.255.0 {
  range 192.168.0.50 192.168.0.60;
  option domain-name-servers 172.25.254.254;
  option domain-name "pod0.example.com";
  option routers 192.168.0.10;
  option broadcast-address 192.168.0.255;
  default-lease-time 600;
  max-lease-time 7200;
  next-server 192.168.0.16;
  filename "pxelinux.0";
}
EOT

dhcpd -t
systemctl start dhcpd

#安装TFTP服务
yum -y install tftp-server &> /dev/null
yum -y install syslinux &> /dev/null
cp /usr/share/syslinux/pxelinux.0  /var/lib/tftpboot/ 
mkdir -p /var/lib/tftpboot/pxelinux.cfg
cat > /var/lib/tftpboot/pxelinux.cfg/default << EOT
default vesamenu.c32
timeout 60
display boot.msg
menu background splash.jpg
menu title Welcome to Global Learning Services Setup!
label local
        menu label Boot from ^local drive
        menu default
        localhost 0xffff
label install
        menu label Install rhel7
        kernel vmlinuz
        append initrd=initrd.img ks=http://192.168.0.16/myks.cfg
EOT
\cp /yum/isolinux/splash.png vesamenu.c32 vmlinuz initrd.img /var/lib/tftpboot/
sed -i 's/disable.*/disable=no/' /etc/xinetd.d/tftp
systemctl start xinetd

#生成ks.cfg文件
yum -y install httpd &> /dev/null
cat > /var/www/html/myks.cfg << EOT
#version=RHEL7
# System authorization information
auth --enableshadow --passalgo=sha512
# Reboot after installation 
reboot
# Use network installation
url --url="http://192.168.0.16/rhel7u1/"
# Use graphical install
# graphical 
text
# Firewall configuration
firewall --enabled --service=ssh
firstboot --disable 
ignoredisk --only-use=vda
# Keyboard layouts
# old format: keyboard us
# new format:
keyboard --vckeymap=us --xlayouts='us'
# System language 
lang en_US.UTF-8
# Network information
network  --bootproto=dhcp
network  --hostname=localhost.localdomain
#repo --name="Server-ResilientStorage" --baseurl=http://download.eng.bos.redhat.com/rel-eng/latest-RHEL-7/compose/Server/x86_64/os//addons/ResilientStorage
# Root password
rootpw --iscrypted nope 
# SELinux configuration
selinux --disabled
# System services
services --disabled="kdump,rhsmcertd" --enabled="network,sshd,rsyslog,ovirt-guest-agent,chronyd"
# System timezone
timezone Asia/Shanghai --isUtc
# System bootloader configuration
bootloader --append="console=tty0 crashkernel=auto" --location=mbr --timeout=1 --boot-drive=vda 
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part / --fstype="xfs" --ondisk=vda --size=6144
%post
echo "redhat" | passwd --stdin root
useradd carol
echo "redhat" | passwd --stdin carol
# workaround anaconda requirements
%end
%packages
@core
%end
EOT

#发布ks与iso镜像
mkdir -p /var/www/html/rhel7u1
ln -s /yum/* /var/www/html/rhel7u1
systemctl start httpd
systemctl enable httpd
systemctl enable xinetd
systemctl enable dhcpd
exit
