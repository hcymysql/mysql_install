#!/bin/bash

echo "正在安装MySQL软件......."

useradd mysql
useradd nagios
useradd zabbix

sleep 2

######配置参数######
mysql8_version=mysql-8.0.18-linux-glibc2.12-x86_64.tar.xz
mysql8_version_dir=mysql-8.0.18-linux-glibc2.12-x86_64

######同步复制用户######
repl_user=repl
repl_passwd=sysrepl
#######################

######root密码######
root_passwd=123456
#######################

######DBA管理用户######
dba_user=admin
dba_passwd=hechunyang
#######################

######8.0克隆用户######
clone_user=clone_user
clone_passwd=123456
#######################


######修改hosts文件######
cat << EOF >> /etc/hosts

192.168.137.11		mgr1
192.168.137.12		mgr2
192.168.137.13		mgr3

EOF
#######################

######mgr配置######
mysql_port=3306
primary_ip=192.168.137.11
secondary1_ip=192.168.137.12
secondary2_ip=192.168.137.13

primary_port=33061
secondary1_port=33062
secondary2_port=33063

local_ip=192.168.137.11
local_port=33061

###############################################
if [ "$1" = "repl" ]
then
while true
do
	read -t 30 -p "输入你的主库IP:  " master_ip
	read -t 30 -p "输入你的主库端口号:  " master_port
	if [[ -z $master_ip || -z $master_port ]]
	then
		continue
	else
		echo ""
		echo "主库IP是： $master_ip"
		echo "主库端口号是： $master_port"
		break 
	fi
done

/usr/local/mysql/bin/mysql -h127.0.0.1 -u'$dba_user' -p'$dba_passwd' -P"$master_port" --connect-expired-password -e "CHANGE MASTER TO MASTER_HOST='$master_ip',MASTER_USER='repl',MASTER_PASSWORD='sysrepl',MASTER_PORT=$master_port,MASTER_AUTO_POSITION = 1,MASTER_CONNECT_RETRY=10; START SLAVE;"

	echo "MySQL主从复制同步已经初始化完毕。"
	exit 0
fi

################################################
if [ "$1" = "mgr" ]
then

while true
do
	read -t 30 -p "是Primary吗？是请输入yes，否输入no:  " is_primary
	if [[ -z $is_primary ]]
	then
		continue
	else
		if [ $is_primary == "yes" ] || [ $is_primary == "no" ]
		then
			break 
		else
			 echo "你输入一个错误的字符$is_primary，请重新输入..."
			 continue
		fi
	fi
done

if [ $is_primary == "yes" ]
then
	/usr/local/mysql/bin/mysql -h127.0.0.1 -u"$dba_user" -p"$dba_passwd" -P"$mysql_port" --connect-expired-password -e "INSTALL PLUGIN group_replication SONAME  'group_replication.so'; set persist group_replication_group_name = '3b12b5bd-f0c6-11e9-9778-000c2900afc6';set persist group_replication_local_address =  '${local_ip}:${local_port}'; set persist group_replication_group_seeds = '${primary_ip}:${primary_port},${secondary1_ip}:${secondary1_port},${secondary2_ip}:${secondary2_port}';SET GLOBAL group_replication_bootstrap_group=ON; CHANGE MASTER TO MASTER_USER='$repl_user',MASTER_PASSWORD='$repl_passwd' FOR CHANNEL 'group_replication_recovery';START GROUP_REPLICATION;select sleep(5);select * from performance_schema.replication_group_members;SET GLOBAL group_replication_bootstrap_group=OFF;"

else
	/usr/local/mysql/bin/mysql -h127.0.0.1 -u"$dba_user" -p"$dba_passwd" -P"$mysql_port" --connect-expired-password -e "INSTALL PLUGIN group_replication SONAME  'group_replication.so'; set persist group_replication_group_name = '3b12b5bd-f0c6-11e9-9778-000c2900afc6';set persist group_replication_local_address =  '${local_ip}:${local_port}'; set persist group_replication_group_seeds = '${primary_ip}:${primary_port},${secondary1_ip}:${secondary1_port},${secondary2_ip}:${secondary2_port}'; SET GLOBAL group_replication_bootstrap_group=OFF; CHANGE MASTER TO MASTER_USER='$repl_user',MASTER_PASSWORD='$repl_passwd' FOR CHANNEL 'group_replication_recovery';START GROUP_REPLICATION;select sleep(5);select * from performance_schema.replication_group_members;"

fi
	
echo "MySQL Mgr组复制已经初始化完毕。"
exit 0

fi

################################################

ps aux | grep 'mysql' | grep -v 'grep' | grep -v 'bash'
if [ $? -eq 0 ]
then
	echo "MySQL进程已经启动，无需二次安装。"
	exit 0
fi

if [ ! -d /usr/local/${mysql8_version_dir} ]
then
        yum install xz -y
	tar -Jxvf ${mysql8_version} -C /usr/local/
	ln -s /usr/local/${mysql8_version_dir} /usr/local/mysql
	chown -R mysql.mysql /usr/local/mysql/
	chown -R mysql.mysql /usr/local/mysql
else
	ln -s /usr/local/${mysql8_version_dir} /usr/local/mysql
	chown -R mysql.mysql /usr/local/mysql/
	chown -R mysql.mysql /usr/local/mysql
fi 

while true
do
	read -t 30 -p "输入你的数据库名:  " dbname
	read -t 30 -p "输入你的数据库端口号:  " dbport
	read -t 30 -p "输入MySQL serverId:  " serverId
	read -t 30 -p "输入innodb_buffer_pool_size大小，单位G:  " innodb_bp_size
	if [[ -z $dbname || -z $dbport || -z $serverId || -z $innodb_bp_size ]]
	then
		continue
	else
		echo "数据库名字是： $dbname"
		echo "数据库端口是： $dbport"
		echo "MySQL serverId： $serverId"
		echo "BP大小是： $innodb_bp_size GB"
		break 
	fi
done

sed "s/test/$dbname/g;s/3306/$dbport/;s/413306/$serverId/;/innodb_buffer_pool_size/s/1/$innodb_bp_size/" my_test.cnf > /etc/my_$dbname.cnf

DATA_DIR=/data/mysql/$dbname
[ ! -d $DATA_DIR ] && mkdir -p $DATA_DIR/{data,binlog,relaylog,tmp,slowlog,log}; touch $DATA_DIR/log/error.log; chown -R mysql.mysql /data/mysql/


if [ `ls -A $DATA_DIR/data/ | wc -w` -eq 0 ]
then
	cd /usr/local/mysql
	echo ""
	echo "初始化MySQL数据目录......"
	echo ""
	bin/mysqld --defaults-file=/etc/my_$dbname.cnf --initialize --user=mysql --basedir=/usr/local/mysql --datadir=/data/mysql/$dbname/data
	sleep 2
	bin/mysqld_safe --defaults-file=/etc/my_$dbname.cnf --user=mysql &
fi

while true
do
	 netstat -ntlp | grep $dbport
	 if [ $? -eq 1 ]
	 then
		echo "MySQL启动中，稍等......"
		sleep 5
		continue
	 else
		break
	 fi
done

ps aux | grep 'mysql' | grep -v 'grep' | grep -v 'bash'
if [ $? -eq 0 ]
then
        echo "MySQL安装完毕。"
else
	echo "MySQL安装失败。"
fi

###更改root账号随机密码
random_passwd=`grep 'temporary password' $DATA_DIR/log/error.log | awk -F 'root@localhost: ' '{print $2}'`
/usr/local/mysql/bin/mysql -S /tmp/mysql_$dbname.sock -p"$random_passwd" --connect-expired-password -e "set sql_log_bin=0;alter user root@'localhost' identified by '$root_passwd';" 

echo "root账号随机密码更改完毕。"

###创建同步账号和管理员账号
/usr/local/mysql/bin/mysql -S /tmp/mysql_$dbname.sock --connect-expired-password -p"$root_passwd" -e "set sql_log_bin=0;create user '$repl_user'@'%' IDENTIFIED BY '$repl_passwd'; GRANT REPLICATION SLAVE,REPLICATION CLIENT ON *.* TO '$repl_user'@'%'; create user '$dba_user'@'%' IDENTIFIED BY '$dba_passwd'; GRANT ALL on *.* to '$dba_user'@'%' WITH GRANT OPTION;"

sed -i -r "s/(PATH=)/\1\/usr\/local\/mysql\/bin:/" /root/.bash_profile
source /root/.bash_profile

echo "MySQL账号初始化完毕。"

###安装clone插件
/usr/local/mysql/bin/mysql -S /tmp/mysql_$dbname.sock --connect-expired-password -p"$root_passwd" -e "set sql_log_bin=0;INSTALL PLUGIN CLONE SONAME 'mysql_clone.so'; CREATE USER '$clone_user'@'%' IDENTIFIED BY '$clone_passwd';GRANT BACKUP_ADMIN,CLONE_ADMIN ON *.* TO '$clone_user'@'%';"

echo ""
echo "clone克隆插件安装完毕。"

