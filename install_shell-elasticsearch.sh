#!/bin/bash

HOME=$(cd $(dirname $0) && pwd)

## Check file

yum -y update
yum -y install vim wget tcpdump openssh-clients unzip ntp

echo "check MakeDependency Checking"

[[ `yum list | grep openjdk | wc -l` -ne  22 ]] && echo "Installing OpenJDK. Please wait..." && yum -y install java-1.8.0-openjdk-headless

# Create repository

function create_repo(){
	# dir
	local YUM_DIR=/etc/yum.repos.d
	local ES_REPO=${YUM_DIR}/elasticsearch.repo
	local KB_REPO=${YUM_DIR}/kibana.repo
	local LS_REPO=${YUM_DIR}/logstash.repo
	local FB_REPO=${YUM_DIR}/filebeat.repo
	
	# data
	local ES_DATA="[elasticsearch-2.x]\nname=Elasticsearch repository for 2.x packages\nbaseurl=http://packages.elastic.co/elasticsearch/2.x/centos \ngpgcheck=1 \ngpgkey=http://packages.elastic.co/GPG-KEY-elasticsearch \nenabled=1"
	local KB_DATA="[kibana-4.4]\nname=Kibana repository for 4.6 packages\nbaseurl=http://packages.elastic.co/kibana/4.6/centos\ngpgcheck=1\ngpgkey=http://packages.elastic.co/GPG-KEY-elasticsearch\nenabled=1"
	local LS_DATA="[logstash-2.x]\nname=Logstash repository for 2.4 packages\nbaseurl=http://packages.elastic.co/logstash/2.4/centos\ngpgcheck=1\ngpgkey=http://packages.elastic.co/GPG-KEY-elasticsearch"
	local FB_DATA="[beats]\nname=Elastic Beats Repository\nbaseurl=https://packages.elastic.co/beats/yum/el/\$basearch\nenabled=1\ngpgkey=https://packages.elastic.co/GPG-KEY-elasticsearch\ngpgcheck=1"
	rpm --import https://packages.elastic.co/GPG-KEY-elasticsearch
	if [ `echo $1` == "ES" ];then
		if [ ! -e $ES_REPO ];then
			echo -e $ES_DATA >> $ES_REPO
		fi
	elif [ `echo $1` = "KB" ];then
		if [ ! -e $KB_REPO ];then
			echo -e $KB_DATA >> $KB_REPO
		fi
	elif [ `echo $1` == "LS" ];then
		if [ ! -e $LS_REPO ];then
			echo -e  $LS_DATA >> $LS_REPO
		fi
	elif [ `echo $1` == "FB" ];then
		if [ ! -e $FB_REPO ];then
			echo -e $FB_DATA >> $FB_REPO
		fi
	fi
}

# Running function object
create_repo "ES"
create_repo "KB"
create_repo "LS"
create_repo "FB"


# Package Install Object

function install(){
	local Arg=$1
	local ES=elasticsearch
	local KB=kibana
	local LS=logstash
	local FB=filebeat
	local GO=golang
	
	if [ `echo $Arg` == "ES" ];then
		if [ `yum list installed | grep $ES | wc -l` != "1" ];then
			echo "Install $ES"
			yum -y install $ES
		fi
	elif [ `echo $Arg` == "KB" ];then
		if [ `yum list installed | grep $KB | wc -l` != "1" ];then
			echo "Install $KB"
			yum -y install $KB
		fi
	elif [ `echo $Arg` == "LS" ];then
		if [ `yum list installed | grep $LS | wc -l` != "1" ];then
			echo "Install $LS"
			yum -y install $LS
		fi
	elif [ `echo $Arg` == "FB" ];then
		if [ `yum list installed | grep $FB | wc -l` != "1" ];then
			echo "Install $FB"
			yum -y install $FB
		fi
	elif [ `echo $Arg` == "GO" ];then
		if [ `yum list installed | grep $GO | wc -l` != "1" ];then
			echo "Install $GO"
			yum -y install $GO
			mkdir -p /usr/local/gocode/{src,bin,pkg}
			echo 'export GOROOT=/usr/lib/golang' >> ~/.bash_profile
			echo 'export GOPATH=/usr/local/gocode' >> ~/.bash_profile
			echo 'export PATH=$PATH:$GOROOT/bin:$GOPATH/bin' >> ~/.bash_profile
			source ~/.bash_profile
		fi
	fi
}

## Package Install Object
install "ES"
install "KB"
install "LS"
install "FB"
install "GO"

#cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.backup

# Service add

chkconfig --add elasticsearch
chkconfig --add kibana
chkconfig --add logstash
chkconfig --add filebeat

chkconfig elasticsearch on
chkconfig kibana on
chkconfig logstash on
chkconfig filebeat on

# Start for ELK
/etc/init.d/elasticsearch restart
/etc/init.d/kibana restart
/etc/init.d/logstash stop
/etc/init.d/logstash start
/etc/init.d/filebeat restart

# Plugin install
if [ ! -e /usr/share/elasticsearch/plugins/kopf ];then
	/usr/share/elasticsearch/bin/plugin install lmenezes/elasticsearch-kopf
fi

if [ `yum list installed | grep libpcap | wc -l` != "1" ];then
	sudo yum -y install libpcap
fi

if [ `rpm -qa | grep packetbeat | wc -l` != "1" ];then
	mkdir ${HOME}/temp
	cd ${HOME}/temp
	curl -L -O https://download.elastic.co/beats/packetbeat/packetbeat-1.3.1-x86_64.rpm
	sudo rpm -vi packetbeat-1.3.1-x86_64.rpm
	curl -XPUT 'http://$elastic:9200/_template/packetbeat' -d @/etc/packetbeat/packetbeat.template.json
	yum -y install git
	git clone https://github.com/elastic/beats-dashboards.git
	cd beats-dashboards/
	bash ./load.sh -url '$elastic.com:9200'
	chkconfig filebeat on
	/etc/init.d/packetbeat stop
	/etc/init.d/packetbeat start
fi

rm -rf ${HOME}/temp

if [ `rpm -qa | grep topbeat | wc -l` != "1" ];then
	mkdir ${HOME}/temp
	cd ${HOME}/temp
	curl -L -O https://download.elastic.co/beats/topbeat/topbeat-1.3.1-x86_64.rpm
	rpm -vi topbeat-1.3.1-x86_64.rpm
	curl -XPUT 'http://$elastic:9200/_template/topbeat' -d@/etc/topbeat/topbeat.template.json
	/etc/init.d/topbeat stop
	/etc/init.d/topbeat start
	chkconfig topbeat on
	/etc/init.d/topbeat stop
	/etc/init.d/topbeat start
fi

rm -rf ${HOME}/temp

/etc/init.d/ntpd restart

exit 0
