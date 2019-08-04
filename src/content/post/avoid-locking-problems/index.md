---
title: "Avoid thread synchronization problems with Roslyn"
description: "How to avoid common mocking issues with the help of Roslyn."
date: 2019-08-03T00:20:45+02:00
tags : ["roslyn", "multithreading", "C#"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---

Multithreading is one of the most difficult aspect of the programming and can cause a lot of headache.  The main source of problems is often improper usage of synchronization mechanism which can result with deadlocks or completely lack of synchronization despise our expectations. The famous deadlocks can be detected in runtime thanks to tools like [Concurrency Visualizer](https://docs.microsoft.com/en-US/visualstudio/profiling/concurrency-visualizer?view=vs-2019), [Parallel Tasks Window](https://docs.microsoft.com/en-us/visualstudio/debugger/walkthrough-debugging-a-parallel-application?view=vs-2019#using-the-parallel-tasks-window-and-the-tasks-view-of-the-parallel-stacks-window) or with [WinDBG !dlk command](https://blogs.msdn.microsoft.com/mohamedg/2010/01/28/how-to-debug-deadlocks-using-windbg/). However, these tools are often used only after some unexpected behavior is observed, but it would be nice to reduce that feedback loop and detect these issues in design time. In this blog post I will present what I've recently learnt about traps related to the synchronization in `C#` and I will show you my proposition of Roslyn analyzers that could possibly helps to avoid them right on the stage of writing code.


## Lock on the right object
https://docs.microsoft.com/en-US/visualstudio/code-quality/ca2002-do-not-lock-on-objects-with-weak-identity?view=vs-2015


> The Monitor class takes a synchronization object as its argument. You can pass any reference type object into this method. Reference types are required because, unlike value types, each reference type object contains a sync block as part of ots memory layout.  [...] Care should be taken in selecting which object to use. If you pass in a publicly visible object, there is possibility that another piece of code could also use it as a synchronization object, even if the synchronization is not needed between those two sections of code. If you pass in a complex object, you run the risk of functionality in that class taking a lock on itself. Both od these  situations can lean to poor performance or worse deadlocks. To avoid this, it is almost always wise to allocate a plain private object specifically for your locking purpose.

> There are some classes of objects you should never use as a sync object for Monitor. These include any MarshalByRefObject, string objects (which are interned and shared unpredictably), System.Type, or a value type (which will be boxed every time you lock on it, prohibiting any synchronization from happening  at all)

## Abandoned locks

## SpinLock traps
.NET 4.0 introduce a `SpinLock` which is a new synchronization primitive intended for critical section with low contention. In certain situation, from the performance perspective a `SpinLock` could be a better choice, but before we decide to change `lock/Monitor` to `SpinLock` there is a couple of thing about the `SpinLock` that we should be aware of. The first most important information is that `SpinLock` is a `struct` so all the rules of value types semantic apply to it. The most obvious effect is that creating a method that accept `SpinLock` by a value makes it totally useless - the method always receive a copy of the `SpinLock` instance and there will be no synchronization between the consumers of `SpinLock`. Similar, but less obvious problem is with using `SpinLock` as a `readonly` field because every time we access a `readonly` value type field a copy of it is returned and all invocations of `Enter()` results with acquiring a lock. There is a `Resharper`'s inspection called [Impure method is called for readonly field of value type](https://www.jetbrains.com/help/resharper/ImpureMethodCallOnReadonlyValueField.html) which can save us from this issue but setting the severity of this rule for `Error` could possibly ends with reporting a lot of false positives. To address these both problems with `SpinLock` I've create a Roslyn analyzers that can report those dangerous situations:

- `MT1004` - Passed by value SpinLock is useless
- `MT1005` - Readonly SpinLock is useless

There is one more thing that we should know about `SpinLock`, unlike `Monitor` it doesn't support recursive locking -  so If we call `Enter()` method twice on single thread we end up with a nasty deadlock. Creating ana analyzer that tracks acquiring and releasing lock seems to be a quite complex problem but we could detect these deadlock situation by setting constructor parameter `enableThreadOwnerTracking` to `true`. When the reentrance occurs we get a `System.Threading.LockRecursionException` exception.

## Avoid ReaderWriterLock

## Summary

All my propositions of Roslyn analyzers for detecting synchronization problems are available on github [MultithreadingAnalyzer](https://github.com/smartanalyzers/MultithreadingAnalyzer) and can be added to your projects with nuget package TODO. I would appreciate if you could try it and let me know if it was able to spot real problems in your code base or all those reported diagnostics were wrong. For those who want to gain your knowledge about parallel programming in C# I'm highly recommend reading a free ebook from Microsoft [Patterns for Parallel Programming: Understanding and Applying Parallel Patterns with the .NET Framework 4](https://www.microsoft.com/en-us/download/details.aspx?id=19222) or [Pro .NET 4 Parallel Programming in C# ](https://www.amazon.com/gp/product/1430229675/ref=as_li_tl?ie=UTF8&tag=asdqweasd-20&camp=1789&creative=9325&linkCode=as2&creativeASIN=1430229675&linkId=641bf019467347fd65bc13e232eff4d8)