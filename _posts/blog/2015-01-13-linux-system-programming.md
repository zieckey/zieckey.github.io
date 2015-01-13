---
layout: post
title: 多进程编程
description: 
category: blog
tags : [Golang]
---

### wait 和 waitpid

当一个进程正常或异常退出时，内核就向其父进程发送`SIGCHLD`信号。因为子进程退出是一个异步事件，所以该信号也是内核向父进程发送的异步信号。

wait的函数原型是：

```C
#include <sys/types.h>
#include <sys/wait.h>

pid_t wait(int *status);
pid_t waitpid(pid_t pid, int *status, int options);
```
参数status用来保存被收集进程退出时的一些状态信息，它是一个指向int类型的指针。进程一旦调用了wait或waitpid，则可能发生：

- 如果其所有子进程都还在运行，则阻塞
- 如果某个子进程已经退出， wait/waitpid就会收集这个子进程的信息，并把它彻底销毁后返回
- 如果没有任何子进程，则会立即出错返回　　　　

这两个函数的区别在于：

- 在子进程结束之前，wait使其
 


To be continue ...
 