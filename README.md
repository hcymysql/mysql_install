# mysql_install
MySQL8.0 自动安装脚本 

mysql8_install.sh（执行前修改一下脚本里的配置参数，改成你自己的）

my_test.cnf（这个是模板文件，基本上不用改，mysql8_install.sh脚本执行的时候会自动替换里面的port，server_id，innodb_buffer_pool_size等）

mysql-8.0.28-linux-glibc2.12-x86_64.tar.xz

shell> wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.28-linux-glibc2.12-x86_64.tar.xz

三个文件放在同一个目录下，例如/root/soft/

------------------------------------------------------------------------------------
# Centos8 注意事项

## shell> yum install jemalloc -y

内存管理器jemalloc库文件名字已经变更，需要建立一个软连接

## shell> ln  -s  /usr/lib64/libjemalloc.so.2   /usr/lib64/libjemalloc.so

------------------------------------------------------------------------------------

1）安装并启动mysql进程（主和从库都执行）

```#/bin/bash  mysql8_install.sh```

注：my.cnf配置文件默认在/etc/目录下，文件名是以你的数据库名命名，例my_test.cnf，mysql.sock在/tmp目录下。

    数据存放在/data/mysql/目录下。

2）配置主从复制（从库执行）

```#/bin/bash  mysql8_install.sh  repl```

3）配置组复制（先在Primary节点上执行，再到Secondary节点上执行）

注：先把3个节点MySQL实例启动后再开始搭建mgr，同时修改脚本里的ip地址和端口和hosts对应的主机名和地址

```#/bin/bash  mysql8_install.sh  mgr```

![image](https://raw.githubusercontent.com/hcymysql/mysql_install/master/mgr.png)

注：配置成功后，会在data数据目录下生成mysqld-auto.cnf配置文件。

