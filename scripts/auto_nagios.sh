#!/bin/bash
read -p "请输入被监控端的IP地址:" IP1
ssh-copy-id root@$IP1
 
 
 # 1) 新建用户
ssh root@$IP1  "id nagios || useradd nagios && echo "123" | passwd --stdin nagios &> /dev/null"
 # 2）安装软件 
ssh root@$IP1  "yum -y install xinetd &> /dev/null"
 # 3) 同步文件
rsync -avzR /usr/local/nagios/ /etc/xinetd.d/nrpe  /etc/services  root@$IP1:/
 # 4) 启动服务
ssh root@$IP1 "service xinetd restart &> /dev/null && chkconfig xinetd on" 
 # 5) 测试
/usr/local/nagios/libexec/check_nrpe -H localhost &> /dev/null
 if [ $? -eq 0 ];then
  echo "$IP1,配置成功"
 fi



 



