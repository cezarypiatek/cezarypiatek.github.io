---
title: "Avoid thread synchronization problems with Roslyn: other traps"
description: "How to avoid common mocking issues with the help of Roslyn."
date: 2019-08-03T00:20:45+02:00
tags : ["roslyn", "multithreading", "C#"]
highlight: true
image: "splashscreen.jpg"
draft: true
isBlogpost: true
---

Multithreading is one of the most difficult aspects of programming and can cause a lot of headaches. The main source of problems is often improper usage of synchronization mechanisms which can result with the deadlocks or a complete lack of synchronization despise our expectations. The famous deadlocks can be detected in runtime thanks to tools like [Concurrency Visualizer](https://docs.microsoft.com/en-US/visualstudio/profiling/concurrency-visualizer?view=vs-2019), [Parallel Tasks Window](https://docs.microsoft.com/en-us/visualstudio/debugger/walkthrough-debugging-a-parallel-application?view=vs-2019#using-the-parallel-tasks-window-and-the-tasks-view-of-the-parallel-stacks-window) or with [WinDBG !dlk command](https://blogs.msdn.microsoft.com/mohamedg/2010/01/28/how-to-debug-deadlocks-using-windbg/). However, these tools are often used only after some unexpected behavior is observed, but it would be nice to reduce that feedback loop and detect these issues in design time. I decided to create a series of blog posts where I will present what I've recently learned about traps related to the synchronization in `C#` and I will show you my proposition of Roslyn analyzers that possibly helps to avoid them right on the stage of writing code. This part is about choosing a suitable object for locking.


## Abandoned locks

The `lock()` statement allows to acquire a lock on the given object with a guarantee of releasing it at the end of the scope. However, sometimes you have to manually manage the scope of locking by directly calling methods responsible for acquiring and releasing and the burden of ensuring that the release is always executed is on you. The most common trap is the assumption that there is no code between lock acquire and release that could throw an exception. Even if it looks like at first, this could be misleading because our current thread can be aborted by the external code and the `ThreadAbortException` can be throw from the place where we don't expect it. If you don't have 100% confidence that the code responsible for the release will be always invoked you can end up with the `abandoned lock` which simply causes a deadlock. To avoid that you should always apply a pattern like that:

```csharp
//Acquired the lock
try{
    //Critical section logic
}
finally{
    //Release the lock
}
```

In order to bring attention to this problem I've created a simple analyzer ruler `MT1003: Releasing lock without guarantee of execution` which verify if the following methods responsible for lock releasing are always wrapped in `finally` block:

-  `System.Threading.Monitor.Exit`
-  `System.Threading.SpinLock.Exit`
-  `System.Threading.Mutex.ReleaseMutex`
-  `System.Threading.ReaderWriterLockSlim.ExitWriteLock`
-  `System.Threading.ReaderWriterLockSlim.ExitReadLock`
-  `System.Threading.ReaderWriterLockSlim.ExitUpgradeableReadLock`
-  `System.Threading.ReaderWriterLock.ReleaseReaderLock`
-  `System.Threading.ReaderWriterLock.ReleaseWriterLock`


## SpinLock traps
.NET 4.0 introduced a `SpinLock` which is a new synchronization primitive intended for the critical section with low contention. In certain situation, from the performance perspective, a `SpinLock` could be a better choice, but before we decide to change `lock/Monitor` to `SpinLock` there is a couple of thing about the `SpinLock` that we should be aware of. The first most important information is that `SpinLock` is a `struct` so all the rules of value types semantic apply to it. The most obvious effect is that creating a method that accepts `SpinLock` by value makes it useless - the method always receives a copy of the `SpinLock` instance and there will be no synchronization between the consumers of `SpinLock`. The similar, but less obvious problem is with using `SpinLock` as a `readonly` field because every time we access a `readonly` value type field a copy of it is returned and all invocations of `Enter()` results with acquiring a lock. There is a `Resharper`'s inspection called [Impure method is called for readonly field of value type](https://www.jetbrains.com/help/resharper/ImpureMethodCallOnReadonlyValueField.html) which can save us from this issue but setting the severity of this rule for `Error` could end with reporting a lot of false positives. To address these both problems with `SpinLock` I've created  Roslyn analyzers that can report those dangerous situations:

- `MT1004: Passed by value SpinLock is useless`
- `MT1005: Readonly SpinLock is useless`

There is one more thing that we should know about `SpinLock`, unlike `Monitor` it doesn't support recursive locking - so If we call `Enter()` method twice on the single thread we end up with a nasty deadlock. Creating an analyzer that tracks acquiring and releasing lock seems to be a quite complex problem but we could detect these deadlock situation by setting constructor parameter `enableThreadOwnerTracking` to `true`. When the reentrance occurs we get a `System.Threading.LockRecursionException` exception.

## Avoid ReaderWriterLock
Since .Net 4.0 there are two synchronization primitives that implement a reader-writer lock pattern: `ReaderWriterLock` and `ReaderWriterLockSlim`. The first one, according to [MSDN documentation](https://docs.microsoft.com/en-US/dotnet/api/system.threading.readerwriterlock?view=netframework-4.8#remarks) is discouraged in the flavor of the slim-version. `ReaderWriterLockSlim` is characterized by better performance ([check the benchmark](https://blogs.msdn.microsoft.com/pedram/2007/10/07/a-performance-comparison-of-readerwriterlockslim-with-readerwriterlock/)) and by default has disabled recursion locking which tends to complicated code and cause potential deadlocks. I was able to cause a deadlock situation when called `AcquireWriterLock(Timeout.Infinite)` on the thread that already was holding a read lock. This same scenario applied to the ReaderWriterLockSlim ends with `System.Threading.LockRecursionException` exception. To build awareness about the existence of `ReaderWriterLockSlim` I've created a Roslyn analyzer that can detect usage of the `ReaderWriterLock` and recommend replacement with his successor.


## Summary

All my propositions of Roslyn analyzers for detecting synchronization problems are available on Github [MultithreadingAnalyzer](https://github.com/smartanalyzers/MultithreadingAnalyzer) and can be added to your projects with NuGet package TODO. I would appreciate it if you could try it and let me know if it was able to spot real problems in your codebase or all those reported diagnostics were wrong. For those who want to gain your knowledge about parallel programming in C# I highly recommend reading a free ebook from Microsoft [Patterns for Parallel Programming: Understanding and Applying Parallel Patterns with the .NET Framework 4](https://www.microsoft.com/en-us/download/details.aspx?id=19222) or [Pro .NET 4 Parallel Programming in C# ](https://www.amazon.com/gp/product/1430229675/ref=as_li_tl?ie=UTF8&tag=asdqweasd-20&camp=1789&creative=9325&linkCode=as2&creativeASIN=1430229675&linkId=641bf019467347fd65bc13e232eff4d8)