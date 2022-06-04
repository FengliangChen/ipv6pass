# 用途

将域名解析到ipv6地址， 把ip放到ipset的集合，再把集合放到iptables规则上，使从外部访问到这些ip的设备可以放行。

# 安装
## lua 依赖库luasocket 安装。
小米路由器arm架构，Busybox系统。刚好手头有树莓派3B+，可以在其先安装好依赖库luasocket，再复制到路由器。

[Luasocket project](https://github.com/lunarmodules/luasocket)
把github项目下载到树莓派。执行`make` 然后`make install`安装。
依赖文件安装在：`/usr/local/lib/lua/5.1` 和 `/usr/local/share/lua/`
把这些树莓生成的文件拷到路由。
下面用scp拷贝例子。
```bash
scp -r socket root@192.168.1.1:/usr/local/lib/lua/5.1/
scp -r 5.1 root@192.168.1.1:/usr/local/share/lua/
```
## 安装配置文件。

在路由器路径`/etc/config`下新建文件名ipv6pass，加以下内容

```

config domain 'ipv6'    
         option chain 'forwarding_wan_rule'
	     option sleep '600'
         list address 'example.com' 
         list address 'example.com'
	     list address 'example.com'
```

chain 是把规则放到iptables哪条chain上。
sleep 是多少秒进行一次解析。
address 是将要进行解析的域名。

# openwrt 服务开机脚本启动设定

启动脚本位置：`/etc/init.d/ipv6pass`

启动命令：` /etc/init.d/ipv6pass enable`
启动后会在  `/etc/rc.d/ `生成相应的服务脚本。

## 例子
```bash
#!/bin/sh /etc/rc.common

USE_PROCD=1

START=99

start_service(){
        procd_open_instance
        procd_set_param command /usr/bin/lua "/usr/bin/ipv6pass.lua"
        procd_set_param stdout 1
        procd_set_param stderr 1
        procd_set_param respawn
        procd_close_instance
}
stop_service(){
        # kill your pid
        kill -9 `ps | grep 'ipv6pass.lua' | grep -v 'grep' | awk '{print $1}'`
}
restart(){
        kill -9 `ps | grep 'ipv6pass.lua' | grep -v 'grep' | awk '{print $1}'`
        start
}
```


# 参考
[luasocket](https://aiq0.github.io/luasocket/introduction.html)

