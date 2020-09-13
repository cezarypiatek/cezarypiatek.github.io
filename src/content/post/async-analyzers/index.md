---
title: "Most common async code smells and how to track them down with analyzers"
description: "How to configure dotnet core solutions to automatically generate client packages for WebAPI projects"
date: 2020-09-13T00:11:45+02:00
tags : ["NSwag", "AspCore", "C#", "WebAPI", "Rest"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---


## Microsoft.VisualStudio.Threading.Analyzers 

https://github.com/DotNetAnalyzers/AsyncUsageAnalyzers - Now superseded by Microsoft/vs-threading


https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/index.md


| Id | Description | Default Severity |
| -- | ----------- | ----------- |
[VSTHRD001](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD001.md) | Avoid legacy thread switching methods |  Warning
[VSTHRD002](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD002.md) | Avoid problematic synchronous waits |  Warning
[VSTHRD003](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD003.md) | Avoid awaiting foreign Tasks |  Warning
[VSTHRD004](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD004.md) | Await SwitchToMainThreadAsync |  Error
[VSTHRD010](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD010.md) | Invoke single-threaded types on Main thread | Warning
[VSTHRD011](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD011.md) | Use `AsyncLazy<T>` |  Error
[VSTHRD012](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD012.md) | Provide JoinableTaskFactory where allowed |  Warning
[VSTHRD100](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD100.md) | Avoid `async void` methods | Warning
[VSTHRD101](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD101.md) | Avoid unsupported async delegates | Warning
[VSTHRD102](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD102.md) | Implement internal logic asynchronously | Info
[VSTHRD103](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD103.md) | Call async methods when in an async method | Warning
[VSTHRD104](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD104.md) | Offer async option | Info
[VSTHRD105](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD105.md) | Avoid method overloads that assume `TaskScheduler.Current` |  Warning
[VSTHRD106](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD106.md) | Use `InvokeAsync` to raise async events |  Warning
[VSTHRD107](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD107.md) | Await Task within using expression | Error
[VSTHRD108](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD108.md) | Assert thread affinity unconditionally | Warning
[VSTHRD109](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD109.md) | Switch instead of assert in async methods |  Error
[VSTHRD110](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD110.md) | Observe result of async calls |Warning
[VSTHRD111](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD111.md) | Use `.ConfigureAwait(bool)` |  Hidden
[VSTHRD112](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD112.md) | Implement `System.IAsyncDisposable` |  Info
[VSTHRD113](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD113.md) | Check for `System.IAsyncDisposable` | Info
[VSTHRD114](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD114.md) | Avoid returning null from a `Task`-returning method. |Warning
[VSTHRD200](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD200.md) | Use `Async` naming convention |  Warning



## AsyncFixer

http://www.asyncfixer.com/
https://www.nuget.org/packages/AsyncFixer#

| Id | Description | Default Severity |
| -- | ----------- | ----------- |
| AsyncFixer01 | Unnecessary async/await usage  | Warning  | 
| AsyncFixer02 | Long-running or blocking operations inside an async method |  Warning  | 
| AsyncFixer03 | Fire & forget async void methods |  Warning  | 
| AsyncFixer04 | Fire & forget async call inside a using block | Warning  | 
| AsyncFixer05 | Downcasting from a nested task to an outer task |  Warning  | 


https://stackoverflow.com/questions/54139584/code-analyzer-which-warn-dev-to-use-async-methods

## Roslyn.Analyzers

https://roslyn-analyzers.readthedocs.io/en/latest/repository.html#analyzers-in-the-repository

| Id | Description | Default Severity |
| -- | ----------- | ----------- |
| [ASYNC0001](https://roslyn-analyzers.readthedocs.io/en/latest/analyzers-info/async/async-method-names-should-be-suffixed-with-async.html#async-method-names-should-be-suffixed-with-async) |	Asynchronous method names should end with Async | Warning  | 
| [ASYNC0002](https://roslyn-analyzers.readthedocs.io/en/latest/analyzers-info/async/non-async-method-names-should-not-be-suffixed-with-async.html#non-async-method-names-should-not-be-suffixed-with-async) |	Non asynchronous method names should end with Async | Warning |
| [ASYNC0003](https://roslyn-analyzers.readthedocs.io/en/latest/analyzers-info/async/avoid-async-void-methods.html#avoid-async-void-methods) |	Avoid void returning asynchronous method |	Warning |
| [ASYNC0004](https://roslyn-analyzers.readthedocs.io/en/latest/analyzers-info/async/use-configure-await-false.html#use-configure-await-false) |	Use ConfigureAwait(false) on await expression |	Warning |


## Meziantou.Analyzer

https://www.meziantou.net/enforcing-asynchronous-code-good-practices-using-a-roslyn-analyzer.htm
https://github.com/meziantou/Meziantou.Analyzer/tree/master/docs

| Id | Description | Default Severity |
| -- | ----------- | ----------- |
| [MA0032](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0032.md) | Use a cancellation token | Info |
| [MA0040](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0040.md) | Use a cancellation token | Info |
| [MA0042](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0042.md) | 	Do not use blocking call | Info |
| [MA0045](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0045.md) | 	Do not use blocking call (make method async) | Info |
| [MA0079](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0079.md) | 	Use a cancellation token using .WithCancellation() | Info |
| [MA0080](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0080.md) | 	Use a cancellation token using .WithCancellation() | Info |

## Roslynator

https://github.com/JosefPihrt/Roslynator/blob/master/src/Analyzers/README.md

| Id | Description | Default Severity |
| -- | ----------- | ----------- |
| [RCS1046](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1046.md) |	Asynchronous method name should end with 'Async' |	None |
| [RCS1047](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1047.md) |	Non-asynchronous method name should not end with 'Async' |	Info |
| [RCS1090](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1090.md) |	Call 'ConfigureAwait(false)' |	Info |
| [RCS1174](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1174.md) |	Remove redundant async/await |	None |
| [RCS1210](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1210.md) |	Return Task.FromResult instead of returning null |	Warning |
| [RCS1229](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1229.md) |	Use async/await when necessary |	Info |



https://github.com/hvanbakel/Asyncify-CSharp
https://www.nuget.org/packages/Asyncify/


## Async Code Smells

### Redundant async/await

In some cases `async/await` keyword might be redundant. 

❌ Wrong
```cs
async Task DoSomethingElseAsync()
{
    await DoSomethingAsync();
}
```

✔ Correct
```cs
Task DoSomethingElseAsync()
{
    return DoSomethingAsync();
}
```



```
# ASYNC0004: Use ConfigureAwait(false) on await expression
dotnet_diagnostic.AsyncFixer01.severity = error

# RCS1174: Remove redundant async/await.
dotnet_diagnostic.RCS1174.severity = error
```

There's a couple of concerns around this rule and event Stephen Cleary wrote and excellent blog post about it   [Eliding Async and Await](https://blog.stephencleary.com/2016/12/eliding-async-await.html)


### Calling synchronous method inside the async method 


```
# AsyncFixer02: Long-running or blocking operations inside an async method
dotnet_diagnostic.AsyncFixer02.severity = error

# NOTE: Not working when method is async
# VSTHRD103: Call async methods when in an async method
dotnet_diagnostic.VSTHRD103.severity = error
```


### Async Void method

```
# AsyncFixer03: Fire & forget async void methods
dotnet_diagnostic.AsyncFixer03.severity = error

# VSTHRD100: Avoid async void methods
dotnet_diagnostic.VSTHRD100.severity = error

# ASYNC0003: Avoid void returning asynchronous method
dotnet_diagnostic.ASYNC0003.severity = error
```

### Not awaited Task within using expression

`System.Threading.Tasks.Task` implements `IDisposable` interface. Calling a method returning task directly in `using` expressions results in `Task` disposal at the end of `using` block which is never a expected behavior.

❌ Wrong

```cs
using (CreateDisposableAsync())
{
    
}
```

✔ Correct

```cs
using (await CreateDisposableAsync())
{
    
}
```


```
# VSTHRD107: Await Task within using expression
dotnet_diagnostic.VSTHRD107.severity = error
```

### Not awaited Task inside the using block

❌ Wrong

```cs
private Task<int> DoSomething()
{
    using (var service = CreateService())
    {
        return service.GetAsync();
    }
}
```

✔ Correct

```cs
private async Task<int> DoSomething()
{
    using (var service = CreateService())
    {
        return await service.GetAsync();
    }
}
```

```
# AsyncFixer04: Fire & forget async call inside a using block
dotnet_diagnostic.AsyncFixer04.severity = error

# RCS1229: Use async/await when necessary.
dotnet_diagnostic.RCS1229.severity = error
```

There is a small difference between those two analyzers.  `RCS1229` is reported on the method level and `AsyncFixer04` is reported in the return statement which is IMHO more intuitive.


### Unobserved result of asynchronous method

❌ Wrong

```cs
void DoSomethingElse()
{
    DoSomethingAsync();
}
```

✔ Correct
```cs
async Task DoSomethingElse()
{
    await DoSomethingAsync();
}
```



```
# VSTHRD110: Observe result of async calls
dotnet_diagnostic.VSTHRD110.severity = error
```

### Synchronous waits


## Summary

| Code smell | AsyncFixer | Microsoft.VisualStudio.Threading.Analyzers | Roslyn.Analyzers | Meziantou.Analyzer | Roslynator |
| -- | ----------- | ----------- |----------- |----------- |----------- |
| Unnecessary async/await usage  | AsyncFixer01  | | | | RCS1174 |
| Call sync methods when in an async method |   AsyncFixer02  | VSTHRD103 | | |
| Async void methods | AsyncFixer03  | VSTHRD100 | ASYNC0003 | | |
| Await Task within using expression | | VSTHRD107 | | ||
| Fire & forget async call inside a using block | AsyncFixer04   |  | | | RCS1229
| Observe result of async calls | | VSTHRD110 | | |
| Downcasting from a nested task to an outer task |  AsyncFixer05  | | | | |
| Synchronous waits | | VSTHRD002 | | MA0042, MA0045 | |
| Awaiting foreign Tasks | | VSTHRD003 | | |
| Unsupported async delegates | | VSTHRD101	| | |
| Missing `ConfigureAwait(bool)` | | VSTHRD111 | ASYNC0004 | | RCS1090	|
| Returning null from a Task-returning method | | VSTHRD114 | | | RCS1210 |
| Use Async naming convention |  | VSTHRD200 | ASYNC0001 | | RCS1046 |
| Non asynchronous method names should end with Async | | | ASYNC0002 | | RCS1047|
| Pass cancellation token | | | | MA0040, MA0032 | |
| Using cancellation token with IAsyncEnumeration | | | | MA0079,MA0080 | |
