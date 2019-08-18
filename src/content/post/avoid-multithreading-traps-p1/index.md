---
title: "Avoid multithreading traps with Roslyn: Lock object selection"
description: "How to avoid thread synchronization problems caused by improperly chosen lock object"
date: 2019-08-18T00:11:45+02:00
tags : ["roslyn", "multithreading", "C#"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---

Multithreading is one of the most difficult aspects of programming and can cause a lot of headaches. The main source of problems is often improper usage of synchronization mechanisms, which can result in deadlocks or a complete lack of synchronization despite our expectations. The infamous deadlocks can be detected in runtime thanks to tools like [Concurrency Visualizer](https://docs.microsoft.com/en-US/visualstudio/profiling/concurrency-visualizer?view=vs-2019), [Parallel Tasks Window](https://docs.microsoft.com/en-us/visualstudio/debugger/walkthrough-debugging-a-parallel-application?view=vs-2019#using-the-parallel-tasks-window-and-the-tasks-view-of-the-parallel-stacks-window) or with [WinDBG !dlk command](https://blogs.msdn.microsoft.com/mohamedg/2010/01/28/how-to-debug-deadlocks-using-windbg/). However, these tools are often used only after some unexpected behavior is observed, but it would be nice to reduce the feedback loop and detect these issues in design time. I've decided to create a series of blog posts where I will present what I've recently learned about the traps related to the multithreading in `C#`. I will also show you my proposition of Roslyn analyzers that can possibly help to avoid those issues right at the stage of writing the code. This part is about choosing a suitable object for locking.


## DO NOT lock on publicly accessible members
 Using publicly accessible members for locking can result in deadlock because there's no guarantee that any external code won't use them for synchronizing something else, too. If the type encapsulates the access to a resource that requires synchronization, then the synchronization should be also fully encapsulated. As a reminder about that, I created a Roslyn rule called `MT1000: Lock on publicly accessible member` which verifies the accessibility of the member used to acquire lock onto.

## DO NOT lock on this reference
 A particular example of locking on *something that is publicly accessible* is acquiring a lock on the `this` reference, which can also end with a deadlock for the same reason. Even if there is no explicitly written code like `lock(this)`, the lock on current instance could be acquired. There is a less common way for synchronizing every invocation of a given method by decorating it with `[MethodImpl(MethodImplOptions.Synchronized)]`. This causes wrapping the whole method body into the lock on `this` reference for instance methods and lock on `typeof()` for static methods.  If you are not convinced that `lock(this)` is a bad idea, here's the real-life example: [Azure/amqpnetlite#357](https://github.com/Azure/amqpnetlite/issues/357). To protect the codebase from these potentially dangerous statements, I created the following analyzers:

- `MT1001: Lock on this reference`
- `MT1010: Method level synchronization`

## DO NOT lock on objects with weak identity

Another common mistake related to choosing synchronization object is locking on `typeof()` expression. This should be avoided because instances of the `Type` are implicitly shared across the application. After reading [Writing High-Performance .NET Code](https://www.amazon.com/gp/product/0990583457/ref=as_li_tl?ie=UTF8&camp=1789&creative=9325&creativeASIN=0990583457&linkCode=as2&tag=asdqweasd-20&linkId=6332aefaaa81e236135f1822be00ecdd) I learned that not only `Type` but also `strings` and instances of types that inherit from `MarshalByRefObject` should be avoided for locking. I dug a little deeper and I discovered that those types belong to a group called `types with a weak identity` and the complete list of them is much longer:

- `System.String`
-  Arrays of value types
- `System.MarshalByRefObject`
- `System.ExecutionEngineException`
- `System.OutOfMemoryException`
- `System.StackOverflowException`
- `System.Reflection.MemberInfo`
- `System.Reflection.ParameterInfo`
- `System.Threading.Thread`

There is a [FxCop](https://www.nuget.org/packages/Microsoft.CodeAnalysis.FxCopAnalyzers/) rule [CA2002: Do not lock on objects with weak identity](https://github.com/MicrosoftDocs/visualstudio-docs/blob/master/docs/code-quality/ca2002-do-not-lock-on-objects-with-weak-identity.md) that should protect us from this issue. However, current implementations verify only `lock()` statement, so if we are using `Monitor.Enter` or `Monitor.TryEnter` to acquire a lock we are still exposed to the risk of deadlock. I'm planning to create a PR with a fix for that [roslyn-analyzers#2744](https://github.com/dotnet/roslyn-analyzers/issues/2744), but in the meantime, I implemented the whole diagnostic as a separate analyzer: `MT1002: Lock on object with weak identity`. I've also realized that there are types on the list which are not directly inherited from the `System.Object` - all the `exceptions` and `Thread`. This could possibly lead to the situation when the lock is acquired on the reference of base type but it points to the instance of type marked as a weak identity. To increase our confidence, it would be wise to completely ban `System.Exception` and `System.Runtime.ConstrainedExecution.CriticalFinalizerObject` (base class for `Thread`) as a candidate for locking object.


## DO NOT lock on non-readonly fields
The `readonly` keyword is very important because without it, we can't be sure that between invocations of `Monitor.Enter` and `Monitor.Exit` the `lockObject` reference won't be overwritten. This situation is called `abandoned lock` and it ends up with a deadlock because the lock acquired on the object originally referenced by `lockObject` will never be released. To detect this issue in design time, I've created an analyzer called `MT1003: Lock on non-readonly member`

## DO NOT lock on value types

The explanation for this is quite straightforward - value types don't have an `object header` where the information about the acquired lock could be stored. If we write a lock statement over a value object, we get the `CS0185` compiler error. However, if we use `Monitor.Enter` or `Monitor.TryEnter` instead of `lock()` statement, the code will compile but it will also crush in the runtime with `System.Threading.SynchronizationLockException`, when we try to release the lock. This happens because when we pass a value object to `Monitor.Enter` and `Monitor.Exit`, every method gets a different instance because of the `boxing`. The lock statement as well as `Monitor` usages will be monitored with `MT1004: Lock on value type instance` rule.

## Best practice for locking

The best practice to avoid all these problems with selecting suitable object to lock onto, is to create a `private` and `readonly` instance of `object` type dedicated exclusively for locking purpose:

```csharp
private readonly object lockObject = new object();

public void DoSomething()
{
    lock (lockObject)
    {
        //Critical section
    }
}
```

## Summary

All my propositions of Roslyn analyzers are available on Github [MultithreadingAnalyzer](https://github.com/smartanalyzers/MultithreadingAnalyzer) and can be added to your projects with NuGet package [SmartAnalyzers.MultithreadingAnalyzer](https://www.nuget.org/packages/SmartAnalyzers.MultithreadingAnalyzer/). I would appreciate if you could try it out and let me know if it was able to spot real problems in your codebase or all those reported diagnostics were wrong. A lot of stuff presented here I leaned from the following resources:

- [FREE EBOOK] [Patterns for Parallel Programming: Understanding and Applying Parallel Patterns with the .NET Framework 4](https://www.microsoft.com/en-us/download/details.aspx?id=19222) by Stephen Toub
- [Pro .NET 4 Parallel Programming in C# ](https://www.amazon.com/gp/product/1430229675/ref=as_li_tl?ie=UTF8&tag=asdqweasd-20&camp=1789&creative=9325&linkCode=as2&creativeASIN=1430229675&linkId=641bf019467347fd65bc13e232eff4d8) by Adam Freeman 
- [Threading in C#](http://www.albahari.com/threading/) by Joseph Albahari 

For those who want to gain knowledge of parallel programming in C#, I highly recommend reading them.