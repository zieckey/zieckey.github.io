---
layout: post
title: 应用双缓冲技术完美解决资源数据优雅无损的热加载问题
description: 在一个网络服务器不间断运行过程中，有一些资源数据需要实时更新，例如需要及时更新一份白名单列表，怎么做才能做到优雅无损的更新到服务的进程空间内？这里我们提出一种叫“双缓冲”的技术来解决这种问题。
category: blog
tags : [多线程, Golang, C++]
---

## 简介

在一个网络服务器不间断运行过程中，有一些资源数据需要实时更新，例如需要及时更新一份白名单列表，怎么做才能做到优雅无损的更新到服务的进程空间内？这里我们提出一种叫“双缓冲”的技术来解决这种问题。

这里的双缓冲技术是借鉴了计算机屏幕绘图领域的概念。双缓冲技术绘图即在内存中创建一个与屏幕绘图区域一致的对象，先将图形绘制到内存中的这个对象上，再一次性将这个对象上的图形拷贝到屏幕上，这样能大大加快绘图的速度。

### 问题抽象

假设我们有一个查询服务，为了方便描述，我们将数据加密传输等一些不必要的细节都省去后，请求报文可以抽象成两个参数：一个是id，用来唯一标识一台设备（例如手机或电脑）；另一个查询主体query。服务端业务逻辑是通过query查询数据库/NoSQL等数据引擎然后返回相应的数据，同时记录一条请求日志。

用Golang来实现这个逻辑如下：

```go
package main

import (
	"net/http"
	"log"
	"os"
	"fmt"
)

func Query(r *http.Request) string {
	id := r.FormValue("id")
	query := r.FormValue("query")

	//参数合法性检查

	//具体的业务逻辑，查询数据库/NoSQL等数据引擎，然后做逻辑计算，然后合并结果
	//这里简单抽象，直接返回欢迎语
	result := fmt.Sprintf("hello, %v", id)

	// 记录一条查询日志，用于离线统计和分析
	log.Printf("<id=%v><query=%v><result=%v><ip=%v>", id, query, result, r.RemoteAddr)

	return result
}

func Handler(w http.ResponseWriter, r *http.Request) {
	r.ParseForm()
	result := Query(r)
	w.Write([]byte(result))
}

func main() {
	http.HandleFunc("/q", Handler)
	hostname, _ := os.Hostname()
	log.Printf("start http://%s:8091/q", hostname)
	log.Fatal(http.ListenAndServe(":8091", nil))
}
```

服务上线一段时间后，通过日志分析发现有一些id发起的请求异常，每天的请求量远远高于其他id，我们有理由怀疑这些请求是竞争对手在抓我们的数据。这个时候就开始进入攻防阶段了。

有几种攻防策略可供选择：

1. 直接封IP，这种策略有可能会误杀一些正常用户。
2. 将id加入黑名单

假设我们将策略1放到前端接入服务处(例如Nginx)进行拦截，策略2在我们自己的业务逻辑中实现，即在Query函数中加入对id的判断即可。现在的完整代码如下：

```go
package main

import (
	"net/http"
	"log"
	"os"
	"fmt"
	"io/ioutil"
	"bytes"
	"strings"
	"io"
)

var blackIDs map[string]int
func LoadBlackIDs(filepath string) error {
	// 加载黑名单列表文件，每行一个
	b, err := ioutil.ReadFile(filepath)
	if err != nil {
		return err
	}
	r := bytes.NewBuffer(b)
	for {
		id, err := r.ReadString('\n')
		if err == io.EOF || err == nil {
			id = strings.TrimSpace(id)
			if len(id) > 0 {
				blackIDs[id] = 1
			}
		}

		if err != nil {
			break
		}
	}

	return nil
}

func IsBlackID(id string) bool {
	_, exist := blackIDs[id]
	return exist
}

func Query(r *http.Request) (string, error) {
	id := r.FormValue("id")
	query := r.FormValue("query")

	//参数合法性检查

	if IsBlackID(id) {
		return "ERROR", fmt.Errorf("ERROR id")
	}

	//具体的业务逻辑，查询数据库/NoSQL等数据引擎，然后做逻辑计算，然后合并结果
	//这里简单抽象，直接返回欢迎语
	result := fmt.Sprintf("hello, %v", id)

	// 记录一条查询日志，用于离线统计和分析
	log.Printf("<id=%v><query=%v><result=%v><ip=%v>", id, query, result, r.RemoteAddr)

	return result, nil
}

func Handler(w http.ResponseWriter, r *http.Request) {
	r.ParseForm()
	result, err := Query(r)
	if err == nil {
		w.Write([]byte(result))
	} else {
		w.WriteHeader(403)
		w.Write([]byte(result))
	}
}

func main() {
	blackIDs = make(map[string]int)
	if len(os.Args) == 2 {
		err := LoadBlackIDs(os.Args[1])
		panic(err)
	}

	http.HandleFunc("/q", Handler)
	hostname, _ := os.Hostname()
	log.Printf("start http://%s:8091/q", hostname)
	log.Fatal(http.ListenAndServe(":8091", nil))
}
```

经过上述努力，终于将一些异常请求屏蔽掉了，一看时间都凌晨了，恩，好好回家碎个叫，累死哥了。

### 解决思路

又过了一些日子，产品妹子还是找过来了，说我们的最新数据又被竞争对手抓走了，肿么回事？
我们只能做一个离线流程将恶意id实时过滤出来，然后及时反馈到在线程序中，
一开始想到可以通过重启进程的方式来加载这份black_id.txt，这就要求我们的程序对reload要做到足够优雅，
例如不能丢请求、reload过程中要足够平滑，短时间做到这一点还有些困难。然后我们就想到了本文所提到的双缓冲技术。

这里的双缓冲技术是指对black_id.txt文件的加载过程是在后台独立加载，等加载完毕之后，再与当前正在使用的对象直接交换一下，即可完成新文件的加载。
这里有几个细节需要讨论一下：

1. black_id.txt在内存中是一个map结构，有人说，等有更新时，直接将增量更新进map即可，这就需要对该map结构上锁，且所有用到的地方都加锁，锁粒度有点粗
2. 最好的办法是对black_id.txt整体重新生成一个新的map结构，使用的时候直接拿到这个map的指针替换掉原来的指针即可
3. 新老替换后，老的资源什么释放？在Golang中，一般情况下可以通过其自身的GC来释放即可。但有时候，有一些资源是需要我们自己主动释放的，GC这一点做不到。这里我们通过引用计数技术来解决。

### 双缓冲技术Golang实现



## 参考文献

1. [双缓冲技术介绍](http://baike.haosou.com/doc/302938-320692.html)




