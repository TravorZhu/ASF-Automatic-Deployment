#!/bin/sh

finish()
{
    echo "ArchiFarmSteam已经自动部署完成"
    echo "如果部署过程中有问题请到https://github.com/TravorZhu/ASF-Automatic-Deployment/issues反馈"
    echo "访问http://127.0.0.1:1242 以配置ASF"
    echo "bash run.sh               运行ASF"
    echo "bash run_background.sh    后台运行ASF"
    echo "bash stop.sh              停止ASF"
    echo "tail asf.log              显示后台运行的日志"
}

ubuntu()
{
    echo "Install dotnet and ngnix..."
    apt-get -y install wget screen unzip tar nginx curl
    apt-get -y install liblttng-ust0 libssl1.0.0 libkrb5-3 zlib1g 
    if grep -Eqi "14" /etc/issue || grep -Eq "14" /etc/*-release; then
        apt-get -y install libcurl3 libicu52
    elif grep -Eqi "16" /etc/issue || grep -Eq "16" /etc/*-release; then
        apt-get -y install libcurl3 libicu55
    elif grep -Eqi "17" /etc/issue || grep -Eq "17" /etc/*-release; then
        apt-get -y install libicu57
    elif grep -Eqi "18" /etc/issue || grep -Eq "18" /etc/*-release; then
        apt-get -y install libicu60  libcurl4
    fi
    curl -sSL -o dotnet.tar.gz https://aka.ms/dotnet-sdk-2.0.0-linux-x64
    mkdir -p ~/dotnet && tar zxf dotnet.tar.gz -C ~/dotnet
    cp -rf ~/dotnet /etc/
    export PATH=$PATH:/etc/dotnet
    echo -e "export PATH=\$PATH:/etc/dotnet">> ~/.bashrc
    source ~/.bashrc

    rm -rf dotnet.tar.gz
    rm -rf ~/dotnet

    echo "Install ASF..."
    ASF_version=`curl -s https://api.github.com/repos/JustArchiNET/ArchiSteamFarm/releases/latest  | grep "tag_name" | awk -F "\"" '{print $4}'`
    wget https://github.com/JustArchiNET/ArchiSteamFarm/releases/download/$ASF_version/ASF-linux-x64.zip

    unzip ASF-linux-x64.zip -d ./ASF

    rm -f ASF-linux-x64.zip

    echo "Configuration nginx"
    service nginx stop
    SUBJECT="/C=CN/ST=Mars/L=iTranswarp/O=iTranswarp/OU=iTranswarp/CN=steamcommunity.com"

    echo "Create CA key..."
    openssl genrsa -out ca.key 2048

    echo "Signing CA certificate..."
    
    mkdir demoCA
    mkdir demoCA/newcerts
    touch demoCA/index.txt
    touch demoCA/serial
    echo "01" > demoCA/serial
    chmod -R 777 demoCA/
    
    openssl req -new -subj $SUBJECT -x509 -days 3650 -key ca.key -out ca.crt
    echo "Create server key..."

    openssl genrsa -out server.key 2048 
    
    echo "Create server certificate signing request..."

    openssl req -new -subj $SUBJECT -out server.csr -key server.key

    echo "Sign SSL certificate..."

    openssl ca -in server.csr -out server.crt -cert ca.crt -keyfile ca.key
    echo "Copy server.crt to /etc/nginx/ssl/server.crt"
    mkdir /etc/nginx/ssl/
    cp -f server.crt /etc/nginx/ssl/
    echo "Copy server.key to /etc/nginx/ssl/server.key"
    cp -f server.key /etc/nginx/ssl/
    echo "Copy ca.crt to /etc/nginx/ssl/ca.crt"
    cp -f ca.crt /etc/nginx/ssl/

    echo "Trust CA certificate"
    cp -f ca.crt /usr/local/share/ca-certificates
    update-ca-certificates

    rm -rf demoCA
    rm -rf ca.crt
    rm -rf ca.key
    rm -rf server.csr
    rm -rf server.key
    rm -rf server.crt

    touch /etc/nginx/conf.d/steamcommunity.conf
    echo -e "
        server {
            listen 443 ssl;
            server_name steamcommunity.com www.steamcommunity.com;
            location / {
                proxy_pass https://202.175.5.107/;
                proxy_set_header Host \$http_host;
            }
            ssl_certificate     /etc/nginx/ssl/server.crt;
            ssl_certificate_key /etc/nginx/ssl/server.key;
        }

    " > /etc/nginx/conf.d/steamcommunity.conf

    service nginx restart

    echo "127.0.0.1 steamcommunity.com
    127.0.0.1 www.steamcommunity.com" >> /etc/hosts

    touch ./ASF/config/ASF.json
    
    echo -e "{
  \"CurrentCulture\": \"zh-CN\",
  \"IPC\": true}
  " > ./ASF/config/ASF.json

    touch run.sh
    touch stop.sh
    touch run_back.sh

    echo "dotnet ./ASF/ArchiSteamFarm.dll" > run.sh
    echo -e "sudo kill -9 \$\(ps x | awk '/[A]rchiSteamFarm/{print \$1}'\)" > stop.sh
    echo "nohub dotnet ./ASF/ArchiSteamFarm.dll > asf.log 2>&1 &" > run_background.sh
}

RHEL()
{
    echo "Install ngnix..."
    yum -y install yum-utils
    touch /etc/yum.repos.d/nginx.repo
    echo -e "[nginx-stable]
    name=nginx stable repo
    baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
    gpgcheck=1
    enabled=1
    gpgkey=https://nginx.org/keys/nginx_signing.key

    [nginx-mainline]
    name=nginx mainline repo
    baseurl=http://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
    gpgcheck=1
    enabled=0
    gpgkey=https://nginx.org/keys/nginx_signing.key" >> /etc/yum.repos.d/nginx.repo

    yum-config-manager --enable nginx-mainline
    yum -y install nginx
    echo "Install dotnet..."
    yum -y install libunwind libicu wget screen unzip tar 
    curl -sSL -o dotnet.tar.gz https://aka.ms/dotnet-sdk-2.0.0-linux-x64
    mkdir -p ~/dotnet && tar zxf dotnet.tar.gz -C ~/dotnet
    cp -rf ~/dotnet /etc/
    export PATH=$PATH:/etc/dotnet
    echo -e "export PATH=\$PATH:/etc/dotnet">> ~/.bashrc
    source ~/.bashrc

    rm -rf dotnet.tar.gz
    rm -rf ~/dotnet
    
    echo "Install ASF..."
    ASF_version=`curl -s https://api.github.com/repos/JustArchiNET/ArchiSteamFarm/releases/latest  | grep "tag_name" | awk -F "\"" '{print $4}'`
    wget https://github.com/JustArchiNET/ArchiSteamFarm/releases/download/$ASF_version/ASF-linux-x64.zip

    unzip ASF-linux-x64.zip -d ./ASF

    rm -f ASF-linux-x64.zip

    echo "Configuration nginx"
    service nginx stop
    SUBJECT="/C=CN/ST=Mars/L=iTranswarp/O=iTranswarp/OU=iTranswarp/CN=steamcommunity.com"

    echo "Create CA key..."
    openssl genrsa -out ca.key 2048

    echo "Signing CA certificate..."

    openssl req -new -subj $SUBJECT -x509 -days 3650 -key ca.key -out ca.crt -config /etc/pki/tls/openssl.cnf 
    echo "Create server key..."

    openssl genrsa -out server.key 2048 
    echo "Create server certificate signing request..."

    openssl req -new -subj $SUBJECT -out server.csr -key server.key -config /etc/pki/tls/openssl.cnf 

    echo "Sign SSL certificate..."
    rm -f /etc/pki/CA/index.txt
    rm -f /etc/pki/CA/serial

    touch /etc/pki/CA/index.txt
    touch /etc/pki/CA/serial
    echo "01" >> /etc/pki/CA/serial

    openssl ca -in server.csr -out server.crt -cert ca.crt -keyfile ca.key -config /etc/pki/tls/openssl.cnf
    echo "Copy server.crt to /etc/nginx/ssl/server.crt"
    mkdir /etc/nginx/ssl/
    cp -f server.crt /etc/nginx/ssl/
    echo "Copy server.key to /etc/nginx/ssl/server.key"
    cp -f server.key /etc/nginx/ssl/
    echo "Copy ca.crt to /etc/nginx/ssl/ca.crt"
    cp -f ca.crt /etc/nginx/ssl/

    echo "Trust CA certificate"
    cp -f ca.crt /etc/pki/ca-trust/source/anchors
    /bin/update-ca-trust

    rm -rf ca.crt
    rm -rf ca.key
    rm -rf server.csr
    rm -rf server.key
    rm -rf server.crt

    touch /etc/nginx/conf.d/steamcommunity.conf
    echo -e "
        server {
            listen 443 ssl;
            server_name steamcommunity.com www.steamcommunity.com;
            location / {
                proxy_pass https://202.175.5.107/;
                proxy_set_header Host \$http_host;
            }
            ssl_certificate     /etc/nginx/ssl/server.crt;
            ssl_certificate_key /etc/nginx/ssl/server.key;
        }

    " > /etc/nginx/conf.d/steamcommunity.conf

    service nginx restart

    echo "127.0.0.1 steamcommunity.com
    127.0.0.1 www.steamcommunity.com" >> /etc/hosts

    touch ./ASF/config/ASF.json
    
    echo -e "{
  \"CurrentCulture\": \"zh-CN\",
  \"IPC\": true}
  " > ./ASF/config/ASF.json

    touch run.sh
    touch stop.sh
    touch run_back.sh

    echo "dotnet ./ASF/ArchiSteamFarm.dll" > run.sh
    echo -e "sudo kill -9 \$\(ps x | awk '/[A]rchiSteamFarm/{print \$1}'\)" > stop.sh
    echo "nohub dotnet ./ASF/ArchiSteamFarm.dll > asf.log 2>&1 &" > run_background.sh

}


if grep -Eqii "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        RHEL
    elif grep -Eqi "Red Hat Enterprise Linux Server" /etc/issue || grep -Eq "Red Hat Enterprise Linux Server" /etc/*-release; then
        RHEL
    elif grep -Eqi "Aliyun" /etc/issue || grep -Eq "Aliyun" /etc/*-release; then
        RHEL
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        RHEL
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        ubuntu
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        ubuntu
    elif grep -Eqi "Raspbian" /etc/issue || grep -Eq "Raspbian" /etc/*-release; then
        ubuntu
    else
        echo "Unknown Operate System"
    fi

