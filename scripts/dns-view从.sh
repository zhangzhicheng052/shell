#!/bin/bash
######################
#dns-view主辅同步脚本（从）
######################
#主服务器servera,eth0:172.25.17.10,eth1:192.168.1.10,eth2:192.168.1.10
#从服务器serverj,eth0:172.25.17.19,eth1:192.168.1.19,eth2:192.168.1.19

setenforce 0
iptables -F
yum -y install bind bind-chroot &> /dev/null && echo "dns软件安装成功" || echo "请检查yum源配置" 
#从dns主服务器拷贝配置文件
rsync -a 172.25.17.10:/tmp/dns_config.tar.gz /root/
tar xf /root/dns_config.tar.gz -C /
#修改主配置文件，定义view字段
cat > /etc/named.conf <<EOT
include "/etc/dx.cfg";
include "/etc/wt.cfg";
include "/etc/zhdx.cfg";
include "/etc/zhlt.cfg";
options {
	listen-on port 53 { 127.0.0.1; any; };
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";
	allow-query     { localhost; any; };
	recursion no;
	dnssec-enable no;
	dnssec-validation no;
	dnssec-lookaside auto;
	bindkeys-file "/etc/named.iscdlv.key";
	managed-keys-directory "/var/named/dynamic";
	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";
};
logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};
view  dx {
        match-clients { dx; zhdx; 172.25.17.19; !192.168.0.19; !192.168.1.19; };
	transfer-source 172.25.17.19;
	zone "." IN {
		type hint;
		file "named.ca";
	};
	zone "abc.com" IN {
		type slave;
		masters { 172.25.17.10; };
		file "slaves/abc.com.dx.zone";	
	};
	include "/etc/named.rfc1912.zones";
};
view  wt {
        match-clients { wt; zhlt; !172.25.17.19; 192.168.0.19; !192.168.1.19; };
        transfer-source 192.168.0.19;
        zone "." IN {
                type hint;
                file "named.ca";
        };
        zone "abc.com" IN {
                type slave;
                masters { 192.168.0.10; };
                file "slaves/abc.com.wt.zone";
        };
	include "/etc/named.rfc1912.zones";
};
view  other {
        match-clients { any; !172.25.17.19; !192.168.0.19; 192.168.1.19; };
        transfer-source 192.168.1.19;
        zone "." IN {
                type hint;
                file "named.ca";
        };
        zone "abc.com" IN {
                type slave;
                masters { 192.168.1.10; };
                file "slaves/abc.com.other.zone";
        };
        include "/etc/named.rfc1912.zones";
};
include "/etc/named.root.key";
EOT
named-checkconf
service named restart
chkconfig named on && echo "dns-view从服务器配置完成"


