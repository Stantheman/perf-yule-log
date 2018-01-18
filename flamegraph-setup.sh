#!/usr/bin/bash
#
# GCP startup script to  install the things I want a VM to 
# have when working on the yule-log creation
#

# exit early because GCP startup scripts run on every boot
set -eu

if [ -d /usr/local/flamegraph ]; then
  exit
fi

sudo su

# disable selinux
setenforce 0

# set up for elasticsearch
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
cat > /etc/yum.repos.d/logstash.repo <<END
[logstash-6.x]
name=Elastic repository for 6.x packages
baseurl=https://artifacts.elastic.co/packages/6.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
END

yum update -y
yum install --assumeyes htop screen strace perf git wget httpd ShellCheck ncdu bc ltrace gifsicle jq golang lsof bind-utils GraphicsMagick psmisc man-pages ImageMagick cmake gcc-c++ java-1.8.0-openjdk-devel
yum install --assumeyes --enablerepo=base-debuginfo glibc-debuginfo kernel-debuginfo-$(uname -r) java-1.8.0-openjdk-debuginfo.x86_64
yum install -y logstash

export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.151-5.b12.el7_4.x86_64/
/usr/share/logstash/bin/logstash-plugin install logstash-filter-json_encode

# get burn
curl -L "https://dl.bintray.com/mspier/binaries/burn/1.0.1/linux/amd64/burn" -o /usr/local/burn
chmod +x /usr/local/burn

git clone stan-git:~/git/flamegraph-workspace /root/flamegraph-workspace
git clone stan-git:~/git/flamegraph /usr/local/flamegraph

# get my checkout
cd /usr/local/flamegraph
git checkout png-test-changes
cd -

echo 'PATH=$PATH:/usr/local/flamegraph:/root/go/bin' >> ~/.bash_profile
echo 'export PATH' >> ~/.bash_profile

# dont use privatetmp in httpd
mkdir -p /etc/systemd/system/httpd.service.d/
cat > /etc/systemd/system/httpd.service.d/override.conf <<END
[Service]
PrivateTmp=false
END

mkdir -p /var/tmp/perf-tests
ln -s /var/tmp/perf-tests /var/www/html/perf-tests
ln -s /root/flamegraph-workspace/d3 /var/www/html/d3
wget https://i.ytimg.com/vi/rpnBVISuMbg/maxresdefault.jpg -O /root/flamegraph-workspace/maxresdefault.jpg
rm -f /etc/httpd/conf.d/welcome.conf

service httpd restart

git clone --depth=1 https://github.com/jrudolph/perf-map-agent /usr/local/perf-map-agent
cd /usr/local/perf-map-agent
cmake .
make
