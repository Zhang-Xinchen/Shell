#！/bin/bash
#version 1.0
#2024/7/23
#mysql安装

#变量
remote_ip=192.168.20.168 #远程主机IP
remote_user=root #远程用户
host_user=root #本地用户
host_root_passwd="Mysql@123456"
host_ip=192.168.20.141 #本机IP
file_dir=/my/ #远程文件夹
file_dirs=/my/my/ #本地压缩包文件夹
mysql_file=/my/mysql.tar.gz #远程主机上的mysql压缩包文件夹
flagfile=mysql.flag #mysql安装包校验文件
host_dir=/ #本机存放路径
remote_mycnf=/etc/my.cnf #远程mysql配置
mycnf_flag=mycnf.flag #远程mysql配置校验文件
mycnf_dir=/mycnf #mysql配置和校验文件包
host_mycnf=/etc/my.cnf #本地默认my.cnf配置
mycnf_bak=/etc/my.cnf.bak #本地配置备份
mycnf_folder=/etc #本地配置的文件夹
x=11
shell_dir=/root/test.sh #脚本运行路径
#mysql安装包名称
mysql_common=mysql-community-common-5.7.38-1.el7.x86_64.rpm
mysql_libs=mysql-community-libs-5.7.38-1.el7.x86_64.rpm
mysql_devel=mysql-community-devel-5.7.38-1.el7.x86_64.rpm
mysql_client=mysql-community-client-5.7.38-1.el7.x86_64.rpm
mysql_server=mysql-community-server-5.7.38-1.el7.x86_64.rpm

#环境安装
#expect未安装需要判断一下
if [ ${x} -eq 0 ] ;then
    if [ ! -f /usr/bin/expect ]
    then
            yum install expect -y &>/dev/null 
            if [ $? -ne 0 ]
                then
                    sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
                    echo "expect install failed"
            fi
    fi
    echo "安装环境已就绪"
    x=1
fi
#函数
#ssh连接发送公钥
ssh_copy_id()
{
expect << eof
spawn ssh-copy-id -i /root/.ssh/id_rsa.pub root@192.168.20.168
   expect {
     #"(yes/no)?"第一次与远程主机进行建立连接
     "(yes/no)?" {
         send "yes\r"
         expect "password"
         send "123456\r"
         expect eof
     }
     #"password"是与远程主机建立过联系，但是没进行过密匙连接
     "password" {
         send "123456\r"
         expect eof
     }
     #"WARNING"是发现远程主机有了自己的公匙文件，不需要传输了
     "WARNING" {
        expect eof
     }
      #"ERROR"是对于对面远程主机未开和端口改变的情况判断
     "ERROR" {
        send_user "Remote host not turned on or port changed\n"
        exit 1
     }
                #timeout是对于远程主机开了防火墙的操作的判断
     timeout {
        send_user "Firewall Reject\n"
        exit 2
    }
  }
eof
}
#主机发送密钥给安装机
ssh_copy_id2()
{
expect << eof
spawn ssh-copy-id -i /root/.ssh/id_rsa.pub root@192.168.20.141
   expect {
     #"(yes/no)?"第一次与远程主机进行建立连接
     "(yes/no)?" {
         send "yes\r"
         expect "password"
         send "123456\r"
         expect eof
     }
     #"password"是与远程主机建立过联系，但是没进行过密匙连接
     "password" {
         send "123456\r"
         expect eof
     }
     #"WARNING"是发现远程主机有了自己的公匙文件，不需要传输了
     "WARNING" {
        expect eof
     }
      #"ERROR"是对于对面远程主机未开和端口改变的情况判断
     "ERROR" {
        send_user "Remote host not turned on or port changed\n"
        exit 1
     }
                #timeout是对于远程主机开了防火墙的操作的判断
     timeout {
        send_user "Firewall Reject\n"
        exit 2
    }
  }
eof
}
#生成密钥
sshkey()
{
expect << eof
spawn ssh-keygen
expect "id_rsa):"
send "\r"
expect "passphrase):"
send "\r"
expect "again:"
send "\r"
expect eof
eof
}

#推送连接函数
ssh_connect()
{
#是否已经ssh-keygen
    if [ -f "/root/.ssh/id_rsa" ] && [ -f "/root/.ssh/id_rsa.pub" ] 
        then 
        #主机是否在线
        ping -c 1 -w 1 $host_ip | grep -w "ttl" &>/dev/null
        if [ $? -eq 0 ]
            then 
            ssh_copy_id2 &>/dev/null
            # 如果expect执行失败，处理错误
            if [ $? -ne 0 ]; then
                echo "Expect ssh_copy_id command failed."
                exit 1
            fi
        else
            echo "主机没开"
        fi
    else
        sshkey &>/dev/null
        # 如果expect执行失败，处理错误
        if [ $? -ne 0 ]; then
            echo "Expect sshkey command failed."
            exit 1
        fi
        ping -c 1 -w 1 $remote_ip | grep -w "ttl"
        if [ $? -eq 0 ]
            then 
            ssh_copy_id2
            # 如果expect执行失败，处理错误
            if [ $? -ne 0 ]; then
                echo "Expect ssh_copy_id command failed."
                exit 1
            fi
        else
            echo "主机没开"
        fi
    fi
    echo -n "SSH连接已经建立"
}

#进度条函数
bar(){
total_steps=100
current_step=$1

percent=$(($current_step * 4 * 100 / $total_steps))
bar_length=$(($percent * 50 / 100))
bar=$(printf "%-${bar_length}s" ' ' | tr ' ' '#')
echo -ne ": [${bar}]$percent%%\r"
sleep 0.1

echo
}

if [ ${x} -eq 1 ];then
    #是否已经ssh-keygen
    if [ -f "/root/.ssh/id_rsa" ] && [ -f "/root/.ssh/id_rsa.pub" ] 
        then 
        #主机是否在线
        ping -c 1 -w 1 $remote_ip | grep -w "ttl" &>/dev/null
        if [ $? -eq 0 ]
            then 
            ssh_copy_id &>/dev/null
            # 如果expect执行失败，处理错误
            if [ $? -ne 0 ]; then
                sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
                echo "Expect ssh_copy_id command failed."
                exit 1
            fi
        else
            echo "主机没开"
        fi
    else
        sshkey &>/dev/null
        # 如果expect执行失败，处理错误
        if [ $? -ne 0 ]; then
            echo "Expect sshkey command failed."
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 1
        fi
        ping -c 1 -w 1 $remote_ip | grep -w "ttl"
        if [ $? -eq 0 ]
            then 
            ssh_copy_id
            # 如果expect执行失败，处理错误
            if [ $? -ne 0 ]; then
                echo "Expect ssh_copy_id command failed."
                sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
                exit 1
            fi
        else
            echo "主机没开"
        fi
    fi
    echo -n "SSH连接已经建立"
    bar ${x}
    x=2
fi
#检验远程主机文件夹my
if [ ${x} -eq 2 ];then
    ssh ${remote_user}@${remote_ip} 'cd /my'
    if [ $? -ne 0 ]
        then
            echo "远程主机上没有安装文件"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 1
    fi
    echo -n "远程主机文件夹已经建立"
    bar ${x}
    x=3
fi
#检验远程主机文件mysql.flag
if [ ${x} -eq 3 ];then
    ssh ${remote_user}@${remote_ip} 'ls /my/mysql.flag' &> /dev/null 
    if [ $? -ne 0 ]
        then
            #创建远程主机文件
            ssh ${remote_user}@${remote_ip} 'touch /my/mysql.flag'
            if [ $? -ne 0 ]
                then
                    echo  "touch flagfile fail"
                    sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
                    exit 1
            fi
    fi
    echo -n "压缩包校验文件无误"
    bar ${x}
    x=4
fi
#生成md5校验
if [ ${x} -eq 4 ];then
    ssh ${remote_user}@${remote_ip} 'cd /my;md5sum mysql.tar.gz > mysql.flag' &>/dev/null
    if [ $? -ne 0 ]
        then
            echo  "md5 mysql fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 1
    fi
    echo -n "Mysql文件校验成功生成"
    bar ${x}
    x=5
fi
#拉取文件
if [ ${x} -eq 5 ];then
    rsync -av ${remote_user}@${remote_ip}:/my ${host_dir} &>/dev/null
    if [ $? -ne 0 ]
        then
            echo  "Pull my.cnf command failed"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 1
    fi
    echo -n "文件拉取安装包成功"
    bar ${x}
    x=6
fi
#文件校验
if [ ${x} -eq 6 ];then
    cd ${host_dir}${file_dir} && md5sum -c ${flagfile}|grep 'OK' &>/dev/null
    #md5sum -c ${flagfile}|grep 'OK' #注意这里的OK要大写
    if [ $? -ne 0 ]
        then
            echo  "mysql.tar.gz:no folder or md5 error"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 2
    fi
    echo -n "mysql校验成功"
    bar ${x}
    x=7
fi
#解压Mysql安装包
if [ ${x} -eq 7 ];then
    tar -zxvf ${mysql_file} -C . &>/dev/null
    if [ $? -ne 0 ]
        then
            echo  "tar fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 1
    fi
    echo -n "解压成功"
    bar ${x}
    x=8
fi
#mysql安装
#卸载系统自动安装的mariadb，以免冲突
rpm -e --nodeps mariadb-libs &>/dev/null
#安装依赖包
if [ ${x} -eq 8 ];then
    yum install ncurses-devel libaio-devel -y &>/dev/null
    if [ $? -ne 0 ]
        then
            echo  "yum fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 1
    fi
    echo -n "依赖包安装成功"
    bar ${x}
    x=9
fi
#安装
if [ ${x} -eq 9 ];then
    rpm -ivh ${file_dirs}${mysql_common} &>/dev/null && rpm -ivh ${file_dirs}${mysql_libs} &>/dev/null && rpm -ivh ${file_dirs}${mysql_devel} &>/dev/null &&
    rpm -ivh ${file_dirs}${mysql_client} &>/dev/null && rpm -ivh ${file_dirs}${mysql_server} &>/dev/null
    if [ $? -ne 0 ]
        then
            echo  "rpm fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 1
    fi
    echo -n "rpm Mysql 成功"
    bar ${x}
    x=10
fi
#mycnf校验
if [ ${x} -eq 10 ];then
    #检测mycnf_idr校验文件夹是否存在，没有则生成
    ssh ${remote_user}@${remote_ip} 'ls /mycnf || mkdir /mycnf' &>/dev/null
    #检测mycnf校验文件是否存在，没有则生成
    ssh ${remote_user}@${remote_ip} 'ls /mycnf/mycnf.flag || touch /mycnf/mycnf.flag' &>/dev/null
    #主机发送公钥给安装机
    ssh ${remote_user}@${remote_ip} '"ssh_connect"'
    #mycnf上锁后修改 复制配置文件进校验文件夹 生成远程配置文件校验
    ssh ${remote_user}@${remote_ip} "echo 'sed -i -e "/server-id/s#=.*#=$(($(cat /etc/my.cnf|grep 'server-id'|awk -F "=" '{print $NF+1}')))#g" /etc/my.cnf' > /tmp/test.sh " && ssh ${remote_user}@${remote_ip} "echo -e 'cp -a /etc/my.cnf /mycnf \ncd /mycnf;md5sum my.cnf>mycnf.flag &>/dev/null \nrsync -av /mycnf root@192.168.20.141:/'>>/tmp/test.sh"
    if [ $? -ne 0 ]
        then
            echo  "/tmp/test fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 1
    fi
    echo -n "远程配置文件创建校验成功,/tmp/test配置文件写入成功"
    bar ${x}
    x=11
fi
#flock拉取配置文件和校验
if [ ${x} -eq 11 ];then
    ssh ${remote_user}@${remote_ip} "flock -w 5 /etc/my.cnf -c 'sh /tmp/test.sh'"
   
    if [ $? -ne 0 ]
        then
            echo  "flock error"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 2
    fi
    echo -n "配置文件和校验拉取成功"
    bar ${x}
    x=12
fi
#本地配置文件和校验
if [ ${x} -eq 12 ];then
    cd ${host_dir}${mycnf_dir} && md5sum -c ${mycnf_flag}|grep 'OK' &>/dev/null
    if [ $? -ne 0 ]
        then
            echo  "my.cnf:no folder or md5 error"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 2
    fi
    echo -n "远程配置文件校验无误"
    bar ${x}
    x=13
fi
#本机配置文件备份
if [ ${x} -eq 13 ];then
    ls ${mycnf_bak} &>/dev/null #检验是否已经备份
    if [ $? -ne 0 ]
        then 
            #生成本机配置文件备份
            mv ${host_mycnf} ${mycnf_bak}
            if [ $? -ne 0 ]
                then
                    echo  "my.cnf.bak:no folder or md5 error"
                    sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
                    exit 2
            fi
    fi
    echo -n "本机配置文件备份成功"
    bar ${x}
    x=14
fi
#配置文件覆盖
if [ ${x} -eq 14 ];then
    mv ${host_dir}${mycnf_dir}/my.cnf ${host_mycnf}
    if [ $? -ne 0 ]
        then
            echo  "mv my_cnf:no folder or md5 error"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 2
    fi 
    echo -n "配置文件覆盖成功"
    bar ${x}
    x=15
fi
#修改权限
if [ ${x} -eq 15 ];then
    chown -R mysql:mysql ${host_mycnf}
    if [ $? -ne 0 ]
        then
            echo  "chown fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 2
    fi 
    echo -n "权限修改成功"
    bar ${x}
    x=16
fi
#获取配置文件中的目录
if [ ${x} -eq 16 ];then
    datadir=$(cat /etc/my.cnf|grep 'datadir'|awk -F "=" '{print $NF}')
    if [ $? -ne 0 ]
        then
            echo  "datadir fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 2
    fi 
    echo -n "获取datadir"
    bar ${x}
    x=17
fi
if [ ${x} -eq 17 ];then
    slowquerylogfile=$(cat /etc/my.cnf|grep 'slow-query-log-file'|awk -F "=" '{print $NF}')
    if [ $? -ne 0 ]
        then
            echo  "slowquerylogfile fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 2
    fi
    echo -n "获取slow-query-file成功"
    bar ${x}
    x=18
fi 
if [ ${x} -eq 18 ];then
    log_bin=$(cat /etc/my.cnf|grep 'log-bin'|awk -F "=" '{print $NF}')
    if [ $? -ne 0 ]
        then
            echo  "log-bin fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 2
    fi 
    echo -n "获取log-bin成功"
    bar ${x}
    x=19
fi
#创建配置文件中的目录
if [ ${x} -eq 19 ];then
    mkdir -p ${datadir} ${slowquerylogfile} ${log_bin}
    if [ $? -ne 0 ]
        then
            echo  "mkdir datadir fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 1
    fi    
    echo -n "创建目录成功"
    bar ${x}
    x=20
fi
#给予配置文件中的目录权限
if [ ${x} -eq 20 ];then
    chown -R mysql:mysql /data
    if [ $? -ne 0 ]
        then
            echo  "chown fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 1
    fi   
    echo -n "Mysql初始文件创建和权限赋予成功"
    bar ${x}
    x=21
fi
#开启Mysql生成初始密码
systemctl start mysqld.service
#chmod给socket加权限 
#获取原始密码
if [ ${x} -eq 21 ];then
    orign_passwd=$(cat /var/log/mysqld.log | grep -w root@localhost: | awk '{print $NF}')
    if [ $? -ne 0 ]
        then
            echo  "orign_passwd fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 1
    fi
    echo -n "获取原始密码成功" 
    bar ${x}
    x=22
fi
#修改密码
if [ ${x} -eq 22 ];then
    #mysql -u"${host_user}" -p"${orign_passwd}" --connect-expired-password -e"set global validate_password_policy=LOW;"
    mysql -u"${host_user}" -p"${orign_passwd}" --connect-expired-password -e"alter user 'root'@'localhost' identified by 'Mysql@123456';" &>/dev/null
    if [ $? -ne 0 ]
        then
            echo  "mysql alter passwd fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 1
    fi 
    echo -n "修改密码成功"
    bar ${x}
    x=23
fi
#赋权限
if [ ${x} -eq 23 ];then
    mysql -u"${host_user}" -p"${host_root_passwd}" -e"GRANT ALL ON *.* TO '${host_user}'@'localhost' WITH GRANT OPTION;" &>/dev/null
    if [ $? -ne 0 ]
        then
            echo  "grant fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 1
    fi 
    echo -n "授权成功"
    bar ${x}
    x=24
fi
if [ ${x} -eq 24 ];then
    mysql -u"${host_user}" -p"${host_root_passwd}" -e"flush privileges;" &>/dev/null
    if [ $? -ne 0 ]
        then
            echo  "flush privileges fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 1
    fi 
    echo -n "权限刷新成功"
    bar ${x}
    x=25
fi
#重启数据库
systemctl restart mysqld
#检验是否安装成功
if [ ${x} -eq 25 ];then
    mysql -u"${host_user}" -p"${host_root_passwd}" -e"SHOW DATABASES;" &> /dev/null
    if [ $? -ne 0 ]
        then
            echo  "mysql install fail"
            sed -i -e"23s/x=.*$/x=${x}/g" ${shell_dir} #这里的替换智能使用/不能使用#
            exit 1
    else 
        echo -n "mysql install success"
        bar ${x}
    fi
fi 
#初始化失败定位值
sed -i -e"23s/x=.*$/x=0/g" ${shell_dir} #这里的替换智能使用/不能使用#