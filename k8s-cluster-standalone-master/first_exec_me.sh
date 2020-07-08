#!/bin/env bash

#####################1.准备工作
#当前工作目录
CURRENT_DIR="$(pwd)"
cd ${CURRENT_DIR}
#导入公共函数库
if [ -f "${CURRENT_DIR}/shell_pkg/functions.sh" ]; then
  source "${CURRENT_DIR}/shell_pkg/functions.sh" || exit 1
else
  exit 1
fi

#检查官网k8s二进制安装包是否存在

K8S_INSTALL_FILE="kubernetes-server-linux-amd64.tar.gz"
if [ ! -f "${K8S_INSTALL_FILE}" ]
then
	run_failed "官网k8s二进制包不存在，请到网站下载之后，然后放到当前工作目录下面!"
	run_failed "下载地址: https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.18.md#server-binaries"
	exit 1
else
	tar -xf ${K8S_INSTALL_FILE} -C .
	mv kubernetes/server/bin/{kube-apiserver,kube-controller-manager,kubectl,kube-scheduler} \
	${CURRENT_DIR}/roles/k8s-master/files/
	mv kubernetes/server/bin/{kubelet,kube-proxy} \
	${CURRENT_DIR}/roles/k8s-node/files/
fi

#检查系统环境是否符合安装要求
if [ -f "/etc/redhat-release" ]
then
   OS_VERSION_NUMBER=$(cat /etc/redhat-release  | grep "CentOS Linux release 7" | cut -f 4,5 -d " " | cut -d . -f 2)
   if [ ${OS_VERSION_NUMBER} -gt "5" ]
   then
     run_ok "您的当前OS环境为 $(cat /etc/redhat-release) 符合安装要求!"
   else
     run_failed "$(cat /etc/redhat-release) 不符合安装要求,请使用更高版本的CentOS7!"
   fi
else
     run_failed "请在CentOS7下面安装!"
fi
#检查是否安装了Ansible
which ansible > /dev/null 2>&1
if [ "$?" != "0" ]
then
   run_failed "当前环境没有安装Ansible，正在为您安装Ansible"
   yum -y install epel-release
   yum -y install ansible
fi
#输入集群主机信息
read -p "输入k8s master节点主机IP:" MASTER_HOST01
read -p "输入k8s node01节点主机IP:" NODE_HOST01
read -p "输入k8s node02节点主机IP:" NODE_HOST02

if [ -z "${MASTER_HOST01}" ] || [ -z "${NODE_HOST02}" ] || [ -z "${NODE_HOST01}" ]
then
   run_failed "集群主机IP不完整!"
   exit 1
else
   run_ok "master节点: ${MASTER_HOST01}, node01节点: ${NODE_HOST01} , node01节点: ${NODE_HOST02}"
   yum -y install epel-release
   yum -y install fping
   PIN_RESULT=$(fping ${MASTER_HOST01} ${NODE_HOST01} ${NODE_HOST02}) 
   IS_OK=$(echo "${PIN_RESULT}" | grep unreachable)
   if [ -n "${IS_OK}" ]
   then
     run_failed "要保证所有主机可达!" 
   fi
fi
#选择YUM源
read -p "选择主机yum源(1.华为 2.阿里，默认: 华为源):" CHOOSE_NUM

if [ -z "${CHOOSE_NUM}" ] || [ "${CHOOSE_NUM}" == "1" ]
then
   YUM_SOURCE_FILE=hw_CentOS-Base.repo
   DOCKER_YUM_SOURCE=hw_docker-ce.repo
else
   YUM_SOURCE_FILE=hw_CentOS-Base.repo
   DOCKER_YUM_SOURCE=hw_docker-ce.repo
fi
######################################2.修改配置
#ETCD主机,这里设置和集群主机一致
ETCD_HOST01=${MASTER_HOST01}
ETCD_HOST02=${NODE_HOST01}
ETCD_HOST03=${NODE_HOST02}

cp cfssl/etcd_ssl/server-csr.json.template cfssl/etcd_ssl/server-csr.json
cp cfssl/k8s_ssl/server-csr.json.template cfssl/k8s_ssl/server-csr.json
cp hosts.template hosts
cp group_vars/k8s-hosts.template group_vars/k8s-hosts

sed -i "s#<MASTER_HOST01>#${MASTER_HOST01}#g" cfssl/etcd_ssl/server-csr.json
sed -i "s#<NODE_HOST01>#${NODE_HOST01}#g" cfssl/etcd_ssl/server-csr.json
sed -i "s#<NODE_HOST02>#${NODE_HOST02}#g" cfssl/etcd_ssl/server-csr.json


sed -i "s#<MASTER_HOST01>#${MASTER_HOST01}#g" cfssl/k8s_ssl/server-csr.json
sed -i "s#<NODE_HOST01>#${NODE_HOST01}#g"  cfssl/k8s_ssl/server-csr.json
sed -i "s#<NODE_HOST02>#${NODE_HOST02}#g"  cfssl/k8s_ssl/server-csr.json

sed -i "s#<MASTER_HOST01>#${MASTER_HOST01}#g" hosts
sed -i "s#<NODE_HOST01>#${NODE_HOST01}#g" hosts
sed -i "s#<NODE_HOST02>#${NODE_HOST02}#g" hosts

sed -i "s#<ETCD_HOST01>#${ETCD_HOST01}#g" hosts
sed -i "s#<ETCD_HOST02>#${ETCD_HOST02}#g" hosts
sed -i "s#<ETCD_HOST03>#${ETCD_HOST03}#g" hosts

sed -i "s#<MASTER_HOST01>#${MASTER_HOST01}#g" group_vars/k8s-hosts
sed -i "s#<NODE_HOST01>#${NODE_HOST01}#g" group_vars/k8s-hosts
sed -i "s#<NODE_HOST02>#${NODE_HOST02}#g" group_vars/k8s-hosts
sed -i "s#<YUM_SOURCE_FILE>#${YUM_SOURCE_FILE}#g" group_vars/k8s-hosts
sed -i "s#<DOCKER_YUM_SOURCE>#${DOCKER_YUM_SOURCE}#g" group_vars/k8s-hosts
sed -i "s#<ETCD_HOST01>#${ETCD_HOST01}#g" group_vars/k8s-hosts
sed -i "s#<ETCD_HOST02>#${ETCD_HOST02}#g" group_vars/k8s-hosts
sed -i "s#<ETCD_HOST03>#${ETCD_HOST03}#g" group_vars/k8s-hosts
sed -i "s#<LOCAL_WORKSPACE_DIR>#${CURRENT_DIR}#" group_vars/k8s-hosts
