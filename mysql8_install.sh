#!/bin/bash

echo "正在安装MySQL软件......."

useradd mysql
useradd nagios

sleep 2
mysql8_version=mysql-8.0.18-linux-glibc2.12-x86_64.tar.xz
mysql8_version_dir=mysql-8.0.18-linux-glibc2.12-x86_64

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

/usr/local/mysql/bin/mysql -h127.0.0.1 -u'admin' -p'hechunyang' -P"$master_port" --connect-expired-password -e "CHANGE MASTER TO MASTER_HOST='$master_ip',MASTER_USER='repl',MASTER_PASSWORD='sysrepl',MASTER_PORT=$master_port,MASTER_AUTO_POSITION = 1,MASTER_CONNECT_RETRY=10; START SLAVE;"

	echo "MySQL主从复制同步已经初始化完毕。"
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
/usr/local/mysql/bin/mysql -S /tmp/mysql_$dbname.sock -p"$random_passwd" --connect-expired-password -e "set sql_log_bin=0;alter user root@'localhost' identified by '123456';" 

echo "root账号随机密码更改完毕。"

###创建同步账号和管理员账号
/usr/local/mysql/bin/mysql -S /tmp/mysql_$dbname.sock --connect-expired-password -p'123456' -e "set sql_log_bin=0;create user 'repl'@'%' IDENTIFIED BY 'sysrepl'; GRANT REPLICATION SLAVE,REPLICATION CLIENT ON *.* TO 'repl'@'%'; create user 'admin'@'%' IDENTIFIED BY 'hechunyang'; GRANT ALL on *.* to 'admin'@'%' WITH GRANT OPTION;"

sed -i -r "s/(PATH=)/\1\/usr\/local\/mysql\/bin:/" /root/.bash_profile
source /root/.bash_profile

echo "MySQL账号初始化完毕。"


