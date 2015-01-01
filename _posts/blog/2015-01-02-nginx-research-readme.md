---
layout: post
title: Nginx源码研究
description: 
category: blog
tags : [Nginx]
---

nginx-research
==============

本项目是为了研究Nginx源码而建立的。该项目有以下几点比较不错的优点：

- VS2013源码编译和调试
- 将Nginx看做一个优秀的C库使用，已经将其编译为库了，并且有很多例子参考

项目地址：[https://github.com/zieckey/nginx-research](https://github.com/zieckey/nginx-research)

中文介绍页面：[http://blog.codeg.cn/2015/01/02/nginx-research-readme](http://blog.codeg.cn/2015/01/02/nginx-research-readme)

## 1. Windows使用

打开`nginx-win32-src\nginx.sln`文件，可以看到两个工程：

- nginx ： Nginx的Windows版本，可以直接编译运行
- nginxresearch : 将Nginx做为lib库使用的工程

##### Nginx二进制

直接编译运行nginx工程即可。目前包含下列几个示例Nginx扩展模块：

- ngx_http hello world module
- ngx_http merge module
- ngx_http memcached module
- ngx_http upstream sample code


##### 将Nginx做为C库使用

直接编译运行nginxresearch工程即可。自带gtest，方便写样例代码。目前包含下列几个示例程序：

- ngx_encode_base64的使用


## 2. Linux 使用

##### Nginx二进制

进入各个模块的子目录，直接make即可

##### 将Nginx做为C库使用

进入`libnginx`目录，直接make即可