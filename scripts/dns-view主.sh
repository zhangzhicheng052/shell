#!/bin/bash
######################
#dns-view主辅同步脚本（主）
######################
#主服务器servera,eth0:172.25.17.10,eth1:192.168.1.10,eth2:192.168.1.10
#从服务器serverj,eth0:172.25.17.19,eth1:192.168.1.19,eth2:192.168.1.19
#请先准备好acl列表文件/etc/dx.cfg ;/etc/wt.cfg ;/etc/zhdx.cfg ;/etc/zhlt.cfg ;格式：acl "foosubnet" { 192.168.1/24;192.168.2/24; };

setenforce 0
iptables -F
yum -y install bind bind-chroot &> /dev/null && echo "dns软件安装成功" || echo "请检查yum源配置" 
find -name *.cfg /etc/ && echo "acl列表存在" || echo "请先准备好acl列表文件"
#修改主配置文件，定义view字段
cat > /etc/named.conf <<EOT
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
include "/etc/dx.cfg";
include "/etc/wt.cfg";
include "/etc/zhdx.cfg";
include "/etc/zhlt.cfg";
view  dx {
        match-clients { dx; zhdx; 172.25.17.19; !192.168.0.19; !192.168.1.19; };
	zone "." IN {
		type hint;
		file "named.ca";
	};
	zone "abc.com" IN {
		type master;
		file "abc.com.dx.zone";	
	};
	include "/etc/named.rfc1912.zones";
};
view  wt {
        match-clients { wt; zhlt; !172.25.17.19; 192.168.0.19; !192.168.1.19; };
        zone "." IN {
                type hint;
                file "named.ca";
        };
        zone "abc.com" IN {
                type master;
                file "abc.com.wt.zone";
        };
	include "/etc/named.rfc1912.zones";
};
view  other {
        match-clients { any; !172.25.17.19; !192.168.0.19; 192.168.1.19; };
        zone "." IN {
                type hint;
                file "named.ca";
        };

        zone "abc.com" IN {
                type master;
                file "abc.com.other.zone";
        };
        include "/etc/named.rfc1912.zones";
};
include "/etc/named.root.key";
EOT
#修改A记录文件
cd /var/named
cat > abc.com.dx.zone << EOT
$TTL 1D
@	IN SOA	ns1.abc.com. rname.invalid. (
					10	; serial
					1D	; refresh
					1H	; retry
					1W	; expire
					3H )	; minimum
@	NS	ns1.abc.com.
ns1   	A     	172.25.17.10
www		A		192.168.11.1
EOT
cat > abc.com.wt.zone << EOT
$TTL 1D
@       IN SOA  ns1.abc.com. rname.invalid. (
                                        10      ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
@       NS      ns1.abc.com.
ns1     A       172.25.17.10
www     A       22.21.1.1
EOT
cat > abc.com.other.zone << EOT
$TTL 1D
@       IN SOA  ns1.abc.com. rname.invalid. (
                                        10      ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
@       NS      ns1.abc.com.
ns1     A       172.25.17.10
www     A       1.1.1.1
EOT
#检查配置文件
chgrp named abc.com.*
chgrp named /etc/*.cfg
named-checkconf
named-checkzone abc.com /var/named/abc.com.dx.zone
named-checkzone abc.com /var/named/abc.com.wt.zone
named-checkzone abc.com /var/named/abc.com.other.zone
service named restart
chkconfig named on && echo "dns-view主服务器配置完成"
#打包压缩dns-server配置文件
tar czvf /tmp/dns_config.tar.gz /etc/dx.cfg /etc/wt.cfg /etc/zhdx.cfg /etc/zhlt.cfg  /etc/named.conf



