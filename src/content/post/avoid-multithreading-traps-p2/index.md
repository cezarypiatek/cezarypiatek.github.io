---
title: "Avoid thread synchronization problems with Roslyn: Synchronization primitives traps"
description: "How to avoid thread synchronization problems caused by improperly used synchronization primitives"
date: 2019-09-15T00:10:00+02:00
tags : ["roslyn", "multithreading", "C#"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---

Multithreading is one of the most difficult aspects of programming and can cause a lot of headaches. The main source of problems is often the improper usage of synchronization mechanisms, which can result in deadlocks or a complete lack of synchronization despite our expectations. The effect of the broken synchronization can be analyzed with various runtime tools, but it would be nice to have an asset that is able to report all those issues in the design time right on the stage of writing code. This blog post continues the series `Avoid thread synchronization problems with Roslyn` and this part is about the traps related to the usage of synchronization primitives.

## Abandoned locks

The `lock()` statement allows acquiring a lock on the given object with a guarantee of releasing it at the end of the scope. However, sometimes you have to manually manage the scope of locking by directly calling methods responsible for acquiring and releasing, and the burden of ensuring that the release is always executed is on you. The most common trap is the assumption that there is no code between lock acquire and release that could throw an exception. Even if it looks like this at first, it can be misleading. There is a class of exceptions called `out-of-band-exceptions` which can be thrown from random places. One of those situations we can meet in multithreading applications is when the current thread is aborted by the external code and the `ThreadAbortException` can be thrown from a place where we don't expect it. You can read more about `Out-of-band-exceptions` in [.NET Internals Cookbook](https://www.amazon.com/gp/product/B07RQ4ZCJR/ref=as_li_tl?ie=UTF8&camp=1789&creative=9325&creativeASIN=B07RQ4ZCJR&linkCode=as2&tag=asdqweasd-20&linkId=8f918c80678565ef8e1dbb78ae167ac3). 
If you don't have a 100% confidence that the code responsible for the release will be always invoked, you can end up with the `abandoned lock` which simply causes a deadlock. To avoid that, you should always apply a pattern like that:

```csharp
try{
    //Acquire the lock
    //Critical section logic
}
finally{
    //Release the lock
}
```

In order to bring attention to this problem I've created the following analyzers:

- `MT1012: Acquiring lock without guarantee of releasing`
- `MT1013: Releasing lock without guarantee of execution`

`MT1012` verifies if lock acquiring statement is inside the `try` clause and `MT1013` checks if lock releasing statement is in `finally` clause. These two analyzers work against the following synchronization primitives:

-  `System.Threading.Monitor`
-  `System.Threading.SpinLock`
-  `System.Threading.Mutex`
-  `System.Threading.ReaderWriterLockSlim`
-  `System.Threading.ReaderWriterLock`


## SpinLock traps
.NET 4.0 introduced a `SpinLock` which is a new synchronization primitive intended for the critical section with low contention. In certain situation, from the performance perspective, a `SpinLock` could be a better choice, but before we decide to change `lock/Monitor` to `SpinLock` there is a couple of things about the `SpinLock` that we should be aware of. The first most important information is that  **SpinLock is a struct** so all the rules of value types semantics apply to it. The most obvious effect is that creating a method that accepts `SpinLock` by value (without the `ref` modifier) makes it useless - the method always receives a copy of the `SpinLock` instance and there will be no synchronization between the consumers of `SpinLock`. We can face a similar but less obvious problem with using `SpinLock` as a `readonly` field, because every time we invoke an instance method from a `readonly` value type field, a copy of it is returned and all invocations of `Enter()` result with acquiring a lock. There is a `Resharper`'s inspection called [Impure method is called for readonly field of value type](https://www.jetbrains.com/help/resharper/ImpureMethodCallOnReadonlyValueField.html) which can save us from this issue but setting the severity of this rule for `Error` could end up with reporting a lot of false positives. In order to address both problems with `SpinLock`, I've created  Roslyn analyzers that can report those dangerous situations:

- `MT1014: Passed by value SpinLock is useless`
- `MT1015: Readonly SpinLock is useless`

There is one more thing that we should know about `SpinLock`: unlike `Monitor`, it doesn't support recursive locking - so If we call `Enter()` method twice on a single thread, we end up with a nasty deadlock. Creating an analyzer that tracks acquiring and releasing lock seems to be quite a complex problem, but we could detect those deadlock situations by setting constructor parameter `enableThreadOwnerTracking` to `true`. When the reentrance occurs, we get a `System.Threading.LockRecursionException` exception.

## Avoid ReaderWriterLock
Since .NET 3.5 there are two synchronization primitives that implement a reader-writer lock pattern: `ReaderWriterLock` and `ReaderWriterLockSlim`. The first one, according to [MSDN documentation](https://docs.microsoft.com/en-US/dotnet/api/system.threading.readerwriterlock?view=netframework-4.8#remarks) is discouraged in favor of the slim-version. `ReaderWriterLockSlim` is characterized by better performance ([check the benchmark](https://blogs.msdn.microsoft.com/pedram/2007/10/07/a-performance-comparison-of-readerwriterlockslim-with-readerwriterlock/)) and by default has disabled recursion locking which tends to complicate the code and cause potential deadlocks. I was able to cause a deadlock situation with `ReaderWriterLock` when called `AcquireWriterLock(Timeout.Infinite)` on the thread that already was holding a read lock. The same scenario applied to the ReaderWriterLockSlim ending with `System.Threading.LockRecursionException` exception. To build awareness about the existence of `ReaderWriterLockSlim`, I've created a Roslyn analyzer that can detect usage of the `ReaderWriterLock` and recommend replacement with his successor.

-`MT1016: Replace ReaderWriterLock with ReaderWriterLockSlim`

## Summary

All my propositions of Roslyn analyzers are available on Github [MultithreadingAnalyzer](https://github.com/smartanalyzers/MultithreadingAnalyzer) and can be added to your projects with NuGet package [SmartAnalyzers.MultithreadingAnalyzer](https://www.nuget.org/packages/SmartAnalyzers.MultithreadingAnalyzer/). I would appreciate if you could try it out and let me know if it was able to spot real problems in your codebase or all those reported diagnostics were wrong. A lot of stuff presented here I leaned from the following resources:

- [FREE EBOOK] [Patterns for Parallel Programming: Understanding and Applying Parallel Patterns with the .NET Framework 4](https://www.microsoft.com/en-us/download/details.aspx?id=19222) by Stephen Toub
- [Pro .NET 4 Parallel Programming in C# ](https://www.amazon.com/gp/product/1430229675/ref=as_li_tl?ie=UTF8&tag=asdqweasd-20&camp=1789&creative=9325&linkCode=as2&creativeASIN=1430229675&linkId=641bf019467347fd65bc13e232eff4d8) by Adam Freeman 
- [Threading in C#](http://www.albahari.com/threading/) by Joseph Albahari 

For those who want to gain knowledge of parallel programming in C#, I highly recommend reading them.