# 使用方式


## 依赖
此脚本只依赖如下命令。一般来说，即使是Openwrt都会自带这些命令：

`curl echo openssl awk shuf sed`

## 登录
`./zju-web-auth.sh 账号 密码`

若登录成功，脚本将打印`[Login Successful]`；若已经登录，脚本将打印`[Already Online]`；若登录失败，脚本将打印请求结果。
## 退出
`./zju-web-auth.sh logout`

若退出成功，脚本将打印`logout_ok`
## 交互式操作
`./zju-web-auth.sh`

然后根据提示输入指令、账号和密码。
