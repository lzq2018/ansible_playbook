#### 双主节点的Kubernetes部署

#### 0.注意事项
+ 1）最好了解或者熟悉Ansible Roles配置部署
+ 2）环境要干净！！ 
+ 3）所有二进制文件和配置模板都是放在role的files、template两个文件夹
+ 4）YUM和Docker、Docker Image镜像源都用的是阿里，init/files/有华为镜像，请按照网络情况修改主机组变量文件引用

#### 1. 环境介绍说明:

主机数量: 5
操作系统: CentOS Linux release 7.7.1908 (Core)
Kubernetes: v1.18.5,其它版本请自行尝试
ETCD: v3.3.13
Flannel: v0.11.0
Ansible: 2.9 (在Ubuntu 20.04 LTS 版本部署)
LB: openresty/1.17.8.1



| 工作角色 | IP              | 部署角色                          |
| -------- | --------------- | --------------------------------- |
| LB       | 192.168.144.110 | openresty/1.17.8.1                |
| Master01 | 192.168.144.100 | master节点、etcd节点、flannel节点 |
| Master02 | 192.168.144.99  | master节点、flannel节点           |
| Node01         | 192.168.144.101 | node节点、etcd节点、flannel节点   |
| Node02   | 192.168.144.102 | node节点、etcd节点、flannel节点   |


#### 2. 目录说明

```bash
.
├── cfssl #证书制作工具和生成目录
│   ├── cfssl
│   ├── cfssl-certinfo
│   ├── cfssljson
│   ├── etcd_ssl #etcd证书目录
│   │   ├── ca-config.json
│   │   ├── ca.csr
│   │   ├── ca-csr.json
│   │   ├── ca-key.pem
│   │   ├── ca.pem
│   │   ├── server.csr
│   │   ├── server-csr.json
│   │   ├── server-csr.json.template
│   │   ├── server-key.pem
│   │   └── server.pem
│   └── k8s_ssl #k8s证书目录
│       ├── ca-config.json
│       ├── ca.csr
│       ├── ca-csr.json
│       ├── kube-proxy.csr
│       ├── kube-proxy-csr.json
│       ├── server.csr
│       ├── server-csr.json
│       └── server-csr.json.template
├── group_vars #主机变量
│   ├── k8s-hosts
│   ├── k8s-hosts.template
│   └── k8s-nginx
├── hosts #主机清单配置
├── k8s-cluster.yaml #执行入口
└── roles #Playbook执行模块
    ├── etcd 
    │   ├── files #存放二进制文件和其他配置参数文件,etcd二进制文件已有
    │   ├── README.md
    │   ├── tasks
    │   └── templates
    ├── flannel 
    │   ├── files #存放二进制文件和其他配置参数文件,flannel二进制文件已有
    │   ├── tasks
    │   └── templates
    ├── init
    │   ├── files
    │   ├── README.md
    │   └── tasks
    ├── k8s-master
    │   ├── files #存放二进制文件和其他配置参数文件,需要上传kube-scheduler、kube-controller-manager、kube-apiserver、kubectl二进制文件到这个目录
    │   ├── README.md
    │   ├── tasks
    │   └── templates
    ├── k8s-node
    │   ├── files #存放二进制文件和其他配置参数文件,需要上传kubelet、kube-proxy二进制文件到这个目录
    │   ├── README.md
    │   ├── tasks
    │   └── templates
    └── nginx
        ├── README.md
        ├── tasks
        └── templates
```
#### 3. 使用说明
##### 1). 修改etcd证书申请配置文件,配置etcd集群的IP
```bash
$ cat cfssl/etcd_ssl/server-csr.json
{
    "CN": "etcd",
    "hosts": [
    "192.168.144.100",
    "192.168.144.101",
    "192.168.144.102"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "BeiJing",
            "ST": "BeiJing"
        }
    ]
}
```
##### 2). 修改k8s证书申请配置文件,配置k8s master集群的IP
```bash
$ cat cfssl/k8s_ssl/server-csr.json
{
    "CN": "kubernetes",
    "hosts": [
      "10.0.0.1",
      "127.0.0.1",
      "192.168.144.100",
      "192.168.144.99",
      "192.168.144.110",
      "kubernetes",
      "kubernetes.default",
      "kubernetes.default.svc",
      "kubernetes.default.svc.cluster",
      "kubernetes.default.svc.cluster.local"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "BeiJing",
            "ST": "BeiJing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
```
##### 3).修改主机清单配置，按实际情况修改
```bash
$ cat hosts 

[k8s-master]
master01 ansible_ssh_host=192.168.144.100 etcdname=etcd01 etcdhost=192.168.144.100 master-host01=192.168.144.100 role=master etcdnode=yes
master02 ansible_ssh_host=192.168.144.99  role=master master-host02=192.168.144.99 etcdnode=no
[k8s-node]
node01 ansible_ssh_host=192.168.144.101 etcdname=etcd02 etcdhost=192.168.144.101 nodehost=192.168.144.101 role=node etcdnode=yes
node02 ansible_ssh_host=192.168.144.102 etcdname=etcd03 etcdhost=192.168.144.102 nodehost=192.168.144.102 role=node etcdnode=yes
[k8s-nginx]
nginx ansible_ssh_host=192.168.144.110 role=nginx etcdnode=no

[k8s-hosts:children]
k8s-master
k8s-node
k8s-nginx
```
##### 4).修改主机变量配置

```bash
#k8s-hosts 主机组变量配置
$ cat group_vars/k8s-hosts
#指定安装的版本
DOCKER_NAME: docker-ce-18.06.1.ce-3.el7
#工作目录，必须指定,因为有些任务是在本地执行完成之后推送到远程服务器，一定要按实际机器路径修改
LOCAL_WORKSPACE: /home/ubuntu/ansible_playbook/k8s-cluster-many-master
#ETCD 客户端连接地址
ETCD_CLIENT_CLUSTER: https://192.168.144.100:2379,https://192.168.144.101:2379,https://192.168.144.102:2379
#集群初始化地址
ETCD_INITIAL_CLUSTER: etcd01=https://192.168.144.100:2380,etcd02=https://192.168.144.101:2380,etcd03=https://192.168.144.102:2380
#指定全局使用的Master API地址,如果后续做高可用的话，这个地址也必须唯一,这里因为用Nginx做代理，Nginx地址作为Master API地址
KUBE_APISERVER: https://192.168.144.110:6443
#指定YUM源文件
#YUM_SOURCE: hw_CentOS-Base.repo
YUM_SOURCE: hw_CentOS-Base.repo
DOCKER_YUM_SOURCE: hw_docker-ce.repo
#k8s-nginx 主机变量配置，必须配置，要配置代理模板的时候会用到
$ cat group_vars/k8s-nginx 
master-host01: 192.168.144.100
master-host02: 192.168.144.99
```
##### 5).执行

Ansible部署在CentOS7, root用户下执行
```bash
$ ansible-playbook -i hosts k8s-cluster.yaml --check #执行前检查
$ ansible-playbook -i hosts k8s-cluster.yaml
```

Ansible部署在Ubuntu20.04LTS或者16.04LTS, ubuntu用户下执行
```bash
$ ansible-playbook -i hosts k8s-cluster.yaml --check #执行前检查
$ ansible-playbook -i hosts k8s-cluster.yaml -uroot
```




