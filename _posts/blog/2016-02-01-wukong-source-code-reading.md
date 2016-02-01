---
layout: post
title: 源码阅读-悟空搜索引擎
description: 悟空开源项目是用Go语言编写的全文搜索引擎。它不是一个完整的搜索引擎，是一个容易被修改的、能融入你的业务需求的基础代码，这些代码只实现基本功能，同时也足够精简，让你能了然于心，可以快速修改实现你想要的功能。
category: blog
tags : [Golang]
---

## 一个最简单的例子

我们还是从一个最简单的示例代码开始：

```go
package main

import (
	"github.com/huichen/wukong/engine"
	"github.com/huichen/wukong/types"
	"log"
)

var (
// searcher是协程安全的
	searcher = engine.Engine{}
)

func main() {
	// 初始化
	searcher.Init(types.EngineInitOptions{
		SegmenterDictionaries: "./data/dictionary.txt"})
	defer searcher.Close()

	// 将文档加入索引
	searcher.IndexDocument(0, types.DocumentIndexData{Content: "此次百度收购将成中国互联网最大并购"})
	searcher.IndexDocument(1, types.DocumentIndexData{Content: "百度宣布拟全资收购91无线业务"})
	searcher.IndexDocument(2, types.DocumentIndexData{Content: "百度是中国最大的搜索引擎"})

	// 等待索引刷新完毕
	searcher.FlushIndex()

	// 搜索输出格式见types.SearchResponse结构体
	res := searcher.Search(types.SearchRequest{Text:"百度中国"})
	log.Printf("num=%d ", res.NumDocs)
	for _, d := range res.Docs {
		log.Printf("docId=%d", d.DocId)
		log.Print("\tscore:", d.Scores)
		log.Print("\tTokenLocations:", d.TokenLocations)
		log.Print("\tTokenSnippetLocations:", d.TokenSnippetLocations)
	}
}
```

悟空搜索引擎不是一个完整的搜索引擎，我们可以把它当做一个搜索引擎基础库来使用。上面的示例代码是一个最简单的例子，展示了如何使用这个库，非常简单，三步即可完成：

1. 初始化引擎： `searcher.Init`
2. 将文档加入索引列表中： `searcher.IndexDocument`
3. 执行搜索任务：`searcher.Search`

## 悟空搜索引擎内部整体框架图

引擎中处理用户请求、分词、索引和排序分别由不同的协程（goroutines）完成。

1. 主协程，用于收发用户请求
2. 分词器（segmenter）协程，负责分词
3. 索引器（indexer）协程，负责建立和查找索引表
4. 排序器（ranker）协程，负责对文档评分排序

![](/images/githubpages/wukong-framework.png)

## 引擎初始化过程

从上面最简单的那个例子可以看出，我们所有的操作都是基于`searcher`对象（engine.Engine类型），初始化引擎、将文档加入索引列表中、Flush索引列表、执行搜索任务。下面我们详细分析一下初始化过程：

#### 加载分词词典

有一个参数`NotUsingSegmenter`可以控制是否加载分词词典。小小吐槽一下：这里没有使用正语义，导致我脑袋需要非非转换，(⊙o⊙)… ，我相信如果使用`UsingSegmenter`参数的话，应该更好理解一点。

```go
	if !options.NotUsingSegmenter {
		// 载入分词器词典
		engine.segmenter.LoadDictionary(options.SegmenterDictionaries)

		// 初始化停用词
		engine.stopTokens.Init(options.StopTokenFile)
	}
```

分词词典的内部加载过程，可以详细参考 `https://github.com/huichen/sego` 这个项目，这个可以单独来分析，在这里就不在展开说了。

#### 初始化索引器和排序器

```go
	for shard := 0; shard < options.NumShards; shard++ {
		engine.indexers = append(engine.indexers, core.Indexer{})
		engine.indexers[shard].Init(*options.IndexerInitOptions)

		engine.rankers = append(engine.rankers, core.Ranker{})
		engine.rankers[shard].Init()
	}
```

`options.NumShards` 参数可以设置`shard`(分片，项目作者称之为裂分)个数，根据`shard`个数来初始化索引器(Indexer)、排序器(Rander)的个数。这里是为了方便并行处理，每一个`shard`都有一个索引器(Indexer)和排序器(Rander)，并提前初始化好。

#### 初始化分词器通道

```go
	engine.segmenterChannel = make(
		chan segmenterRequest, options.NumSegmenterThreads)
```

#### 初始化索引器通道

```go
	engine.indexerAddDocumentChannels = make(
		[]chan indexerAddDocumentRequest, options.NumShards)
	engine.indexerRemoveDocChannels = make(
		[]chan indexerRemoveDocRequest, options.NumShards)
	engine.indexerLookupChannels = make(
		[]chan indexerLookupRequest, options.NumShards)
	for shard := 0; shard < options.NumShards; shard++ {
		engine.indexerAddDocumentChannels[shard] = make(
			chan indexerAddDocumentRequest,
			options.IndexerBufferLength)
		engine.indexerRemoveDocChannels[shard] = make(
			chan indexerRemoveDocRequest,
			options.IndexerBufferLength)
		engine.indexerLookupChannels[shard] = make(
			chan indexerLookupRequest,
			options.IndexerBufferLength)
	}
```

从这里可以看出索引器(Indexer)有三个功能：将一个文档添加到索引中、将一个文档从索引中移除、从索引中查找一个文档。每一个`shard`都有独立的`channel`，互不冲突。

#### 初始化排序器通道

```go
	engine.rankerAddDocChannels = make(
		[]chan rankerAddDocRequest, options.NumShards)
	engine.rankerRankChannels = make(
		[]chan rankerRankRequest, options.NumShards)
	engine.rankerRemoveDocChannels = make(
		[]chan rankerRemoveDocRequest, options.NumShards)
	for shard := 0; shard < options.NumShards; shard++ {
		engine.rankerAddDocChannels[shard] = make(
			chan rankerAddDocRequest,
			options.RankerBufferLength)
		engine.rankerRankChannels[shard] = make(
			chan rankerRankRequest,
			options.RankerBufferLength)
		engine.rankerRemoveDocChannels[shard] = make(
			chan rankerRemoveDocRequest,
			options.RankerBufferLength)
	}
```go

与上面类似，从这里可以看出排序器(Rander)有三个功能：将一个文档添加到排序器中、在排序器中进行排序、将一个文档从排序器中移除。每一个`shard`都有独立的`channel`，互不冲突。

#### 初始化持久化存储通道

```go
	if engine.initOptions.UsePersistentStorage {
		engine.persistentStorageIndexDocumentChannels =
			make([]chan persistentStorageIndexDocumentRequest,
				engine.initOptions.PersistentStorageShards)
		for shard := 0; shard < engine.initOptions.PersistentStorageShards; shard++ {
			engine.persistentStorageIndexDocumentChannels[shard] = make(
				chan persistentStorageIndexDocumentRequest)
		}
		engine.persistentStorageInitChannel = make(
			chan bool, engine.initOptions.PersistentStorageShards)
	}
```

注意：`PersistentStorageShards`持久化存储的分片数目是独立参数控制的。

#### 启动各个功能协程goroutine

1. 启动分词器协程
2. 启动索引器和排序器协程
3. 启动持久化存储工作协程

至此，所有初始化工作完毕。

## 索引过程分析

下面我们来分析索引过程。

```go
// 将文档加入索引
//
// 输入参数：
// 	docId	标识文档编号，必须唯一
//	data	见DocumentIndexData注释
//
// 注意：
//      1. 这个函数是线程安全的，请尽可能并发调用以提高索引速度
// 	2. 这个函数调用是非同步的，也就是说在函数返回时有可能文档还没有加入索引中，因此
//         如果立刻调用Search可能无法查询到这个文档。强制刷新索引请调用FlushIndex函数。
func (engine *Engine) IndexDocument(docId uint64, data types.DocumentIndexData) {
	engine.internalIndexDocument(docId, data)

	hash := murmur.Murmur3([]byte(fmt.Sprint("%d", docId))) % uint32(engine.initOptions.PersistentStorageShards)
	if engine.initOptions.UsePersistentStorage {
		engine.persistentStorageIndexDocumentChannels[hash] <- persistentStorageIndexDocumentRequest{docId: docId, data: data}
	}
}

func (engine *Engine) internalIndexDocument(docId uint64, data types.DocumentIndexData) {
	if !engine.initialized {
		log.Fatal("必须先初始化引擎")
	}

	atomic.AddUint64(&engine.numIndexingRequests, 1)
	hash := murmur.Murmur3([]byte(fmt.Sprint("%d%s", docId, data.Content)))
	engine.segmenterChannel <- segmenterRequest{
		docId: docId, hash: hash, data: data}
}
```

这里需要注意的是，docId参数需要调用者从外部传入，而不是在内部自己创建，这给搜索引擎的实现者更大的自由。
将文档交给分词器处理，然后根据murmur3计算的hash值模`PersistentStorageShards`，选择合适的`shard`写入持久化存储中。

### 分词协程处理过程

分词器协程的逻辑代码在这里：`segmenter_worker.go:func (engine *Engine) segmenterWorker()`

分词器协程的逻辑是一个死循环，不停的从`channel engine.segmenterChannel`中读取数据，针对每一次读取的数据：

1. 计算`shard`号
2. 将文档分词
3. 根据分词结果，构造`indexerAddDocumentRequest` 和 `rankerAddDocRequest`
4. 将`indexerAddDocumentRequest`投递到`channel engine.indexerAddDocumentChannels[shard]`中
5. 将`rankerAddDocRequest`投递到`channel engine.rankerAddDocChannels[shard]`中

补充一句：这里`shard`号的计算过程如下：

```go
// 从文本hash得到要分配到的shard
func (engine *Engine) getShard(hash uint32) int {
	return int(hash - hash/uint32(engine.initOptions.NumShards)*uint32(engine.initOptions.NumShards))
}
```

为什么不是直接取模呢？

### 索引器协程处理过程



## 参考文献

1. [悟空搜索引擎项目源码：https://github.com/huichen/wukong](https://github.com/huichen/wukong)
2. [悟空引擎入门教程](https://github.com/huichen/wukong/blob/master/docs/codelab.md)
3. [Code reading: Wukong full-text search engine](https://ayende.com/blog/171745/code-reading-wukong-full-text-search-engine)





