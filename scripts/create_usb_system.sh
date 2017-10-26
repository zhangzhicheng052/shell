#!/bin/bash

# 1、先判断U盘是否被挂载，如果被挂载则卸载，如果没挂就分区格式化
# 2、解压原来安装好的U盘系统文件至当前U盘，修改相关的配置文件(fstab grub.conf)中的UUID
# 3、安装GRUB




# 1、先判断U盘是否被挂载，如果被挂载则卸载，如果没挂就分区格式化
read -p "请输入你的U盘的名字，如：/dev/sdb :" name
newname=$(basename $name)
mname=$(/bin/mount|awk "/$newname/ {print \$1}")

if [ -n "$mname" ]
then
	for i in $mname
	do
		umount -f $i
	done
fi

dd if=/dev/zero of=$name count=1 bs=10M &> /dev/null
fdisk $name <<EOF &> /dev/null
n
p
1


a
1
w
EOF

mkfsname=$name'1'
mkfs.ext4 $mkfsname &> /dev/null
mkdir -p /mnt/usb
mount $mkfsname /mnt/usb

# 2、解压原来安装好的U盘系统文件至当前U盘，修改相关的配置文件(fstab grub.conf)中的UUID
sname=myusb-2.6.32-279.el6.x86_64.tar.bz2
tar xf ./$sname -C /mnt/usb
uuid=$(blkid $mkfsname | grep -Eo '(.){8}-((.){4}-){3}(.){12}')
sed -i -r "s/(.){8}-((.){4}-){3}(.){12}/$uuid/g" /mnt/usb/etc/fstab  /mnt/usb/boot/grub/grub.conf

# 3、安装GRUB
grub-install --root-directory=/mnt/usb --recheck $name &> /dev/null
[ $? -eq 0 ] && umount /mnt/usb && echo "U盘系统制作成功"

