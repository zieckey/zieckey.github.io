---
layout: post
title: QUIC（Quick UDP Internet Connections）源代码阅读
description: 
category: blog
tags : [quic, 网络编程]
---


## 类

### 基础类

#### base

1. Pickle：针对二进制数据进行`pack`和`unpack`操作
2. MessagePump：消息泵基类，也就是做消息循环用的
3. TimeDelta：一个`int64`整型的封装，单位：微妙


#### net

1. IOVector : 对 `struct iovec` 的封装。提供了 `struct iovec` 相关的读写操作。
2. IPEndPoint：代表一个 `IP:Port` 对
3. QuicConfig：Quic相关的配置信息类(与加解密不相关)
2. QuicDataReader：对一段内存数据的读取做了封装，比较方便的读取整数、浮点数、字符串等等。
3. QuicDataWriter：与`QuicDataReader`相对，能够比较方便的将整数、浮点数、字符串、IOVector等数据写入到一段内存`buffer`中。
4. QuicRandom：随机数产生器。
5. QuicFramerVisitorInterface：关于收到的数据包的处理的函数接口类。
6. QuicDispatcher::QuicFramerVisitor：从`QuicFramerVisitorInterface`继承，用于处理QUIC数据包
6. QuicData：对 `<char*,size_t>` 这中内存数据的封装。
7. QuicEncryptedPacket：继承自`QuicData`，并没有新的接口，只是更明确的表明这是一个Quic加密的报文。
8. QuicDispatcher：数据包处理类
	1. 收到一个数据包会调用 `QuicDispatcher::ProcessPacket`
	2. 进而会调用 `QuicFramer::ProcessPacket`
9. QuicTime::Delta：是对 `base::TimeDelta` 的封装
10. QuicTime：一个相对的时间点
11. TimeTicks：滴答时间。
	1. TimeTicks::Now()：返回系统启动到当前时间点的
	2. TimeTicks::UnixEpoch()：返回Unix时间戳
12. QuicAlarm：定时器的抽象类。
13. DeleteSessionsAlarm：删除过期session的定时器。
14. QuicFramer：用于对QUIC数据包的解析和组装。


### 相关源文件

1. quic_flags.h ： 整个项目相关的全局配置信息，是全局变量。
2. 
