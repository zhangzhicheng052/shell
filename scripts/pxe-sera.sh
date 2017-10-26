#!/bin/bash

sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
setenforce 0 &> /dev/null
iptables -F
sed -i '$a net.ipv4.ip_forward = 1' /etc/sysctl.conf
sysctl -p
iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -j SNAT --to-source 172.25.17.10

