#### 1.redis版本: redis-5.0.8

#### 2.部署形式: 源码编译安装

#### 3.其他: 已在CentOS7.x 和 Ubuntu 16.04 LTS验证过

#### 4.ansible 运行命令说明:

> ansible - 控制机部署在Ubuntu 16.04 LTS上面,且在ubuntu用户下执行

`ansible-playbook -i hosts redis-cluster.yaml -uroot`
