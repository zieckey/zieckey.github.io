---
layout: post
title: Golang写的HTTP服务与Nginx对比
description: 想对Golang的网络性能做一个了解，因此用Golang写了一个HTTP Echo服务，与Nginx的Echo模块做基准测试。
category: blog
tags : [golang, nginx]
---

Golang写网络程序的确很简单，一个HTTP Echo服务，几行源码就可以搞定。[Golang源码](https://github.com/zieckey/gohello/blob/master/benchmark/httpecho/main.go "")如下：

```go
package main

import (
	"log"
	"net/http"
	"io/ioutil"
)

func handler(w http.ResponseWriter, r *http.Request) {
	buf, err := ioutil.ReadAll(r.Body) //Read the http body
	if err != nil {
		w.Write(buf)
		return
	}

	w.WriteHeader(403)
}

func main() {
	http.HandleFunc("/echo", handler)
	log.Fatal(http.ListenAndServe(":8091", nil))
}
```

Nginx直接使用[echo module](https://github.com/openresty/echo-nginx-module),配置文件如下：

```go
worker_processes  24;
#daemon off;

events {
    worker_connections  4096;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       8090;
        server_name  localhost;

        location /echo {
            echo_read_request_body;
            echo_request_body;
        }


        location / {
            root   html;
            index  index.html index.htm;
        }

    }
}
```

为了让大家方便搭建nginx的HTTP echo服务，我写了个build脚本，[请见](https://github.com/zieckey/gohello/blob/master/benchmark/httpecho/nginx/buildnginx.sh)：

```shell
#!/usr/bin/env bash

WORKDIR=`pwd`
NGINXINSTALL=$WORKDIR/nginx

#get echo-nginx-module
git clone https://github.com/openresty/echo-nginx-module

#get nginx
wget 'http://nginx.org/download/nginx-1.7.4.tar.gz'
tar -xzvf nginx-1.7.4.tar.gz
cd nginx-1.7.4/

# Here we assume you would install you nginx under /opt/nginx/.
./configure --prefix=$NGINXINSTALL --add-module=$WORKDIR/echo-nginx-module

make -j2
make install

cd -
cp nginx.conf $NGINXINSTALL/conf/
```

下面是对比测试的服务器基础信息：

To be continue ...

[CodeG]:    http://codeg.cn  "CodeG"
