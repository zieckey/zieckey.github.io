---
layout: post
title: Golang源码阅读
description: 对Golang源码中的`src/cmd/dist/buf.c`文件进行阅读和整理。
category: blog
tags : [Golang]
---

# 总览



1. 对Golang源码中的`src/cmd/dist/buf.c`文件进行阅读和整理。该文件提供两个数据结构：Buf、Vec，分别用来取代`char *`和`char **`的相关操作。Buf和Vec这两个数据结构非常简单易懂，其他C语言项目如有需要，可以比较方便的拿过去使用，因此记录在此。
2. 新增`src/lib9/cleanname.c`的阅读

## 1. src/cmd/dist/buf.c

### Buf定义

```c
// A Buf is a byte buffer, like Go's []byte.
typedef struct Buf Buf;
struct Buf
{
	char *p;
	int len;
	int cap;
};
```

#### 对Buf结构相关的一些操作

- void binit(Buf *b) 初始化一个Buf
- void breset(Buf *b) 重置Buf，使之长度为0。类似于C++中的`std::string::clear()`，其数据内存不释放，但数据长度字段设为0
- void bfree(Buf *b) 释放掉Buf内部的内存，并调用`binit`初始化这个Buf
- void bgrow(Buf *b, int n) 增长Buf内部的内存，确保至少还能容纳`n`字节数据
- void bwrite(Buf *b, void *v, int n) 将从`v`地址开始的`n`字节数据追加写入Buf中。类似于C++中的`std::string::append(v,n)`
- void bwritestr(Buf *b, char *p) 将字符串`p`追加写入Buf中，会自动调用`strlen(p)`计算`p`的长度。类似于C++中的`std::string::append(p)`
- char* bstr(Buf *b) 返回一个`NUL`结束的字符串指针，该指针指向Buf内部，外部调用者**不能释放**该指针。类似于C++中的`std::string::c_str()`
- char* btake(Buf *b) 返回一个`NUL`结束的字符串指针，外部调用者**需要自己释放**该指针。
- void bwriteb(Buf *dst, Buf *src) 将Buf`src`追加到`dst`中，`src`保持不变。类似于C++中的`std::string::append(s)`
- bool bequal(Buf *s, Buf *t) 判断两个Buf是否相等。类似于C++中的`std::string::compare(s) == 0`
- void bsubst(Buf *b, char *x, char *y) 使用子串`y`替换掉Buf中所有的`x`

### Vec定义

```c
// A Vec is a string vector, like Go's []string.
typedef struct Vec Vec;
struct Vec
{
	char **p;
	int len;
	int cap;
};
```

#### 对Vec结构相关的一些操作

- void vinit(Vec *b) 初始化一个Vec
- void vreset(Vec *b) 重置Vec，使之长度为0。其数据内存全部释放
- void vfree(Vec *b) 释放掉Vec内部的内存，并调用`vinit`初始化这个Vec
- void vgrow(Vec *b, int n) 增长Vec内部的内存，确保至少还能容纳`n`字节数据。内部实现时为了效率考虑，第一次内存分配时确保至少分配64字节。
- void vcopy(Vec *dst, char **src, int srclen) 将长度为`srclen`的字符串数组挨个复制添加到Vec中。
- void vadd(Vec *v, char *p) 将字符串`p`拷贝一份添加到Vec中。
- void vaddn(Vec *b, char *p, int n) 将长度为`n`的字符串`p`拷贝一份并添加到Vec中。
- void vuniq(Vec *v) 对Vec排序，然后去掉重复的元素
- void splitlines(Vec *v, char *p) 将字符串`p`按照`\n`(如果前面有`\r`会自动trim掉)分割为多段添加到Vec中。
- void splitfields(Vec *v, char *p) 将字符串`p`按照空格（`'\n'、'\t'、'\r'、' '`)分割为多段添加到Vec中。


## 2. src/lib9/cleanname.c

`char* cleanname(char *name)` 该函数实现了Unix下的原地路径压缩功能，能够处理多个 `/` `.` `..`等等组合路径问题。