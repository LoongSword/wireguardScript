# wireguardScript
wireguard安装卸载脚本

# 使用方法
## 使用前修改参数
修改脚本中的
ipv4ServerAddress
ipv6ServerAddress
publicAddress
UDPListenPort
ClientAllowedIPs
几个字段,
其中publicAddress为必须修改字段 <br>
生成客户端配置文件，需要输入客户端的hostname，自动生成hostname+wg.conf <br>

## 启动脚本
su - <br>
chmod +x  wireguard.sh <br>
./wireguard.sh <br>
<br>
<br>
<br>
![image](https://github.com/nightAsShadow/wireguardScript/blob/main/img/wireguardscript.png) <br>

# 问题
使用过程中碰到问题请联系我，感谢!!!
