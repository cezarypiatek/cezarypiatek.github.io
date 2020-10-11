---
title: "Async code smells and how to track them down with analyzers - Part I"
description: "Which analyzer package should I use and how to configure it to avoid most common problems related to async/await."
date: 2020-10-10T00:11:45+02:00
tags : ["async", "C#", "roslyn", "analyzers"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---

Roslyn analyzers are great because they do not only detect different issues in our code but they are able also to propose solutions thanks to accompanying code fixes. There's also one less-advertised aspect of analyzers - besides improving the quality of our codebase, they also improve the state of language knowledge in our teams. **This is a real time-saver during the code review because the technical, language-related remarks are reported automatically in design/build time**. There are many existing analyzer packages provided by the community (mostly free and open-sources) with hundreds of different rules. This abundance raises the following question: **Which analyzer packages should I use and which rules should be reported as errors?**. To help answer that question I decided to start a blog post series that describes a different code smells together with analyzers that can detect them. I will start with analyzers related to asynchronous programming. However, this area is full of traps so this article is the first of two episodes devoted to async/await.

## Analyzers for asynchronous programming
If you are looking for the analyzer that can help to you detect different issues with asynchronous code you can find them in the following packages:

- [Microsoft.CodeAnalysis.FxCopAnalyzers](https://www.nuget.org/packages/Microsoft.CodeAnalysis.FxCopAnalyzers/)
- [Microsoft.VisualStudio.Threading.Analyzers](https://www.nuget.org/packages/Microsoft.VisualStudio.Threading.Analyzers/)
- [AsyncFixer](https://www.nuget.org/packages/AsyncFixer)
- [Roslyn.Analyzers](https://www.nuget.org/packages/Roslyn.Analyzers/)
- [Meziantou.Analyzer](https://www.nuget.org/packages/Meziantou.Analyzer/)
- [Roslynator](https://www.nuget.org/packages/Roslynator.Analyzers/)
- [Asyncify](https://www.nuget.org/packages/Asyncify/)

Most of those packages are not strictly devoted to asynchronous programming, so I made an exercise by going through the complete list of offered rules and listed only those related to async code int the following sections:

{{< tabs tabTotal="7" tabID="1" tabName1="FxCopAnalyzers" tabName2="VS-Threading" tabName3="AsyncFixer"  tabName4="Roslyn.Analyzers" tabName5="Meziantou.Analyzer" tabName6="Roslynator" tabName7="Asyncify">}}
{{< tab tabNum="1" >}}

| Id | Description | Default Severity | CodeFix |
| -- | ----------- | ----------- | ---- |
[CA2007](https://docs.microsoft.com/visualstudio/code-quality/ca2007) | Consider calling ConfigureAwait on the awaited task | Warning | Yes |
[CA2008](https://docs.microsoft.com/visualstudio/code-quality/ca2008) | Do not create tasks without passing a TaskScheduler |  Warning | No |
[CA2012](https://docs.microsoft.com/visualstudio/code-quality/ca2012) | Use ValueTasks correctly |  Warning | No |
[CA2247](https://docs.microsoft.com/visualstudio/code-quality/ca2247) | Argument passed to TaskCompletionSource constructor should be TaskCreationOptions enum instead of TaskContinuationOptions enum|Warning | Yes 

👉 [Full list of supported rules](https://github.com/dotnet/roslyn-analyzers/blob/master/src/Microsoft.CodeAnalysis.FxCopAnalyzers/Microsoft.CodeAnalysis.FxCopAnalyzers.md)

👉 [Nuget package](https://www.nuget.org/packages/Microsoft.CodeAnalysis.FxCopAnalyzers/)

👉 [Official website](https://github.com/dotnet/roslyn-analyzers#microsoftcodeanalysisfxcopanalyzers)

{{< /tab >}}
{{< tab tabNum="2" >}}




| Id | Description | Default Severity | CodeFix |
| -- | ----------- | ----------- |---- |
[VSTHRD001](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD001.md) | Avoid legacy thread switching methods |  Warning | Yes |
[VSTHRD002](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD002.md) | Avoid problematic synchronous waits |  Warning | Yes |
[VSTHRD003](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD003.md) | Avoid awaiting foreign Tasks |  Warning | No |
[VSTHRD004](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD004.md) | Await SwitchToMainThreadAsync |  Error | No |
[VSTHRD010](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD010.md) | Invoke single-threaded types on Main thread | Warning | No |
[VSTHRD011](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD011.md) | Use `AsyncLazy<T>` |  Error | No |
[VSTHRD012](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD012.md) | Provide JoinableTaskFactory where allowed |  Warning | No |
[VSTHRD100](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD100.md) | Avoid `async void` methods | Warning | Yes |
[VSTHRD101](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD101.md) | Avoid unsupported async delegates | Warning | No |
[VSTHRD102](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD102.md) | Implement internal logic asynchronously | Info | No |
[VSTHRD103](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD103.md) | Call async methods when in an async method | Warning | Yes |
[VSTHRD104](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD104.md) | Offer async option | Info | No |
[VSTHRD105](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD105.md) | Avoid method overloads that assume `TaskScheduler.Current` |  Warning | No |
[VSTHRD106](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD106.md) | Use `InvokeAsync` to raise async events |  Warning | No |
[VSTHRD107](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD107.md) | Await Task within using expression | Error | Yes |
[VSTHRD108](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD108.md) | Assert thread affinity unconditionally | Warning | No |
[VSTHRD109](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD109.md) | Switch instead of assert in async methods |  Error | Yes |
[VSTHRD110](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD110.md) | Observe result of async calls |Warning | No |
[VSTHRD111](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD111.md) | Use `.ConfigureAwait(bool)` |  Hidden | Yes |
[VSTHRD112](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD112.md) | Implement `System.IAsyncDisposable` |  Info | Yes |
[VSTHRD113](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD113.md) | Check for `System.IAsyncDisposable` | Info | No |
[VSTHRD114](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD114.md) | Avoid returning null from a `Task`-returning method. |Warning | Yes |
[VSTHRD200](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD200.md) | Use `Async` naming convention |  Warning | Yes |

👉 [Full list of supported rules](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/index.md)

👉 [Nuget package](https://www.nuget.org/packages/Microsoft.VisualStudio.Threading.Analyzers/)

👉 [Official website](https://github.com/microsoft/vs-threading)


{{< /tab >}}
{{< tab tabNum="3" >}}


| Id | Description | Default Severity | CodeFix |
| -- | ----------- | ----------- |---- |
| AsyncFixer01 | Unnecessary async/await usage  | Warning  | Yes |
| AsyncFixer02 | Long-running or blocking operations inside an async method |  Warning  | Yes |
| AsyncFixer03 | Fire & forget async void methods |  Warning  | Yes |
| AsyncFixer04 | Fire & forget async call inside a using block | Warning  | No |
| AsyncFixer05 | Downcasting from a nested task to an outer task |  Warning  | No |

👉 [Full list of supported rules](https://www.nuget.org/packages/AsyncFixer)

👉 [Nuget package](https://www.nuget.org/packages/AsyncFixer)

👉 [Official website](http://www.asyncfixer.com/)


{{< /tab >}}
{{< tab tabNum="4" >}}


| Id | Description | Default Severity | CodeFix |
| -- | ----------- | ----------- |---- |
| [ASYNC0001](https://roslyn-analyzers.readthedocs.io/en/latest/analyzers-info/async/async-method-names-should-be-suffixed-with-async.html#async-method-names-should-be-suffixed-with-async) |	Asynchronous method names should end with Async | Warning  | Yes |
| [ASYNC0002](https://roslyn-analyzers.readthedocs.io/en/latest/analyzers-info/async/non-async-method-names-should-not-be-suffixed-with-async.html#non-async-method-names-should-not-be-suffixed-with-async) |	Non asynchronous method names shouldn't end with Async | Warning |Yes |
| [ASYNC0003](https://roslyn-analyzers.readthedocs.io/en/latest/analyzers-info/async/avoid-async-void-methods.html#avoid-async-void-methods) |	Avoid void returning asynchronous method |	Warning | Yes |
| [ASYNC0004](https://roslyn-analyzers.readthedocs.io/en/latest/analyzers-info/async/use-configure-await-false.html#use-configure-await-false) |	Use ConfigureAwait(false) on await expression |	Warning | Yes |

👉 [Full list of supported rules](https://roslyn-analyzers.readthedocs.io/en/latest/repository.html#analyzers-in-the-repository)

👉 [Nuget package](https://www.nuget.org/packages/Roslyn.Analyzers/)

👉 [Official website](https://roslyn-analyzers.readthedocs.io/)


{{< /tab >}}
{{< tab tabNum="5" >}}


| Id | Description | Default Severity | CodeFix |
| -- | ----------- | ----------- |---- |
| [MA0004](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0004.md) | Use .ConfigureAwait(false) | Warning | Yes |
| [MA0022](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0022.md) | Return Task.FromResult instead of returning null | Info | No |
| [MA0032](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0032.md) | Use an overload that have cancellation token | Info | No |
| [MA0040](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0040.md) | Flow the cancellation token when available | Info | No |
| [MA0042](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0042.md) | Do not use blocking cal| Info | No |
| [MA0045](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0045.md) | Do not use blocking call (make method async) | Info | No |
| [MA0079](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0079.md) | Flow a cancellation token using .WithCancellation() | Info | No |
| [MA0080](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0080.md) | Specify a cancellation token using .WithCancellation() | Info | No |

👉 [Full list of supported rules](https://github.com/meziantou/Meziantou.Analyzer/tree/master/docs)

👉 [Nuget package](https://www.nuget.org/packages/Meziantou.Analyzer/)

👉 [Official website](https://www.meziantou.net/enforcing-asynchronous-code-good-practices-using-a-roslyn-analyzer.htm)

{{< /tab >}}
{{< tab tabNum="6" >}}



| Id | Description | Default Severity | CodeFix |
| -- | ----------- | ----------- |---- |
| [RCS1046](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1046.md) | Asynchronous method name should end with 'Async' | None | No |
| [RCS1047](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1047.md) | Non-asynchronous method name should not end with 'Async' | Info | No |
| [RCS1090](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1090.md) | Call 'ConfigureAwait(false)' | Info | Yes |
| [RCS1174](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1174.md) | Remove redundant async/await | None | Yes |
| [RCS1210](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1210.md) | Return Task.FromResult instead of returning null | Warning | Yes |
| [RCS1229](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1229.md) | Use async/await when necessary | Info | Yes |


👉 [Full list of supported rules](https://github.com/JosefPihrt/Roslynator/blob/master/src/Analyzers/README.md)

👉 [Nuget package](https://www.nuget.org/packages/Roslynator.Analyzers/)

👉 [Official website](https://github.com/JosefPihrt/Roslynator)

{{< /tab >}}
{{< tab tabNum="7" >}}

| Id | Description | Default Severity | CodeFix |
| -- | ----------- | ----------- | ---- |
| AsyncifyInvocation | This invocation could benefit from the use of Task async. | Warning | Yes |
| AsyncifyVariable | This variable access could benefit from the use of Task async. | Warning | Yes |


👉 [Nuget package](https://www.nuget.org/packages/Asyncify/)

👉 [Official website](https://github.com/hvanbakel/Asyncify-CSharp)

{{< /tab >}}
{{< /tabs >}}



## Async Code Smells

Here's my list of the first seven most common issues related to asynchronous programming. For every issue, I provide entries for `.editorconfig` that configure analyzers that can detect it.

### 1. Redundant async/await

Using the `async/await` keywords results in implicit memory allocation required for the state machine responsible for orchestrating asynchronous invocations. When the awaited expression is the only one or the last statement in the function it might be skipped. However, there's a couple of concerns around this code optimization of which you should be aware of. Before you start applying it I highly recommend reading an excellent blog post about it from Stephen Cleary [Eliding Async and Await](https://blog.stephencleary.com/2016/12/eliding-async-await.html)

❌ Wrong
```cs
async Task DoSomethingAsync()
{
    await Task.Yield(); //Reported diagnostics: AsyncFixer01, RCS1174
}
```

✔️ Correct
```cs
Task DoSomethingAsync()
{
    return Task.Yield();
}
```


🛠️ Configuration
```
# AsyncFixer01: Unnecessary async/await usage
dotnet_diagnostic.AsyncFixer01.severity = error

# RCS1174: Remove redundant async/await.
dotnet_diagnostic.RCS1174.severity = error
```


### 2. Calling synchronous method inside the async method 

If we are writing asynchronous code then we should always prefer calling asynchronous methods if they exist. Many IO related APIs offer asynchronous counterparts of their well know synchronous methods. They should be our first choice.

❌ Wrong
```cs
async Task DoAsync(Stream file, byte[] buffer)
{
    file.Read(buffer, 0, 10); // VSTHRD103 is reported to use ReadAsync
}
```

✔️ Correct

```cs
async Task DoAsync(Stream file, byte[] buffer)
{
    await file.ReadAsync(buffer, 0, 10); // VSTHRD103 is reported to use ReadAsync
}
```

🛠️ Configuration
```
# AsyncFixer02: Long-running or blocking operations inside an async method
dotnet_diagnostic.AsyncFixer02.severity = error

# NOTE: Not working when method is async
# VSTHRD103: Call async methods when in an async method
dotnet_diagnostic.VSTHRD103.severity = error
```


### 3. Async Void method

There are two reasons why Async Void methods are harmful: 
- A caller of the method is not able to await asynchronous operation.
- There's no way to handle exception throw by the method. **If the exception occurs your process crash!!!**.

You should always use `async Task` instead of `async void` unless it's an event handler, but then you should guarantee yourself that the method can't throw an exception.


❌ Wrong
```cs
async void DoSomethingAsync() // Reported diagnostics: VSTHRD100, AsyncFixer03, ASYNC0003
{
    await Task.Yield();
}
```

✔️ Correct
```cs
async Task DoSomethingAsync()
{
    await Task.Yield();
}
```

🛠️ Configuration
```
# AsyncFixer03: Fire & forget async void methods
dotnet_diagnostic.AsyncFixer03.severity = error

# VSTHRD100: Avoid async void methods
dotnet_diagnostic.VSTHRD100.severity = error

# ASYNC0003: Avoid void returning asynchronous method
dotnet_diagnostic.ASYNC0003.severity = error
```

### 4. Unsupported async delegates

If we pass the asynchronous lambda function the `Action` argument, the compiler generates `async void` method which downsides were described in the previous code smell. There are two solutions for this problem: if it's possible then we should change the parameter type from `Action` to `Func<Task>` otherwise we need to implement that callback delegate synchronously. It's worth mentioning that some APIs already provide counterparts of their methods that accept `Func<Task>` for the callback parameters.

❌ Wrong
```cs
void DoSomething()
{ 
    Callback(async () => // Reported diagnostics: VSTHRD101
    {
        await Task.Yield();
    });
}

void Callback(Action action)
{
}
```

✔️ Correct
```cs
void DoSomething()
{  
    CallbackAsync(async () =>
    {
        await Task.Yield();
    });
}

void CallbackAsync(Func<Task> action)
{
}
```

🛠️ Configuration
```
# VSTHRD101: Avoid unsupported async delegates
dotnet_diagnostic.VSTHRD101.severity = error
```


### 5. Not awaited Task within using expression

`System.Threading.Tasks.Task` implements `IDisposable` interface. Calling a method returning task directly in `using` expressions results in `Task` disposal at the end of `using` block which is never an expected behavior.

❌ Wrong

```cs
using (CreateDisposableAsync()) //Reported diagnostics: VSTHRD107
{
    
}
```

✔️ Correct

```cs
using (await CreateDisposableAsync())
{
    
}
```

🛠️ Configuration
```
# VSTHRD107: Await Task within using expression
dotnet_diagnostic.VSTHRD107.severity = error
```

### 6. Not awaited Task inside the using block

If we skip the `await` keyword for asynchronous operation inside the `using` block then the disposable object could be disposed before the asynchronous invocation finish. This might result in incorrect behavior and very often ends with a runtime exception notifying that we are trying to operate on the object that is already disposed. This issue has two root causes: either is done by accident when somebody simply forgot about adding `async/await` keywords or it's a result of incorrectly applied code optimization described in `Redundant async/await` code smell. 

❌ Wrong

```cs
private Task<int> DoSomething() // Reported diagnostics: RCS1229
{
    using (var service = CreateService())
    {
        return service.GetAsync(); // Reported diagnostics: AsyncFixer04
    }
}
```

✔️ Correct

```cs
private async Task<int> DoSomething()
{
    using (var service = CreateService())
    {
        return await service.GetAsync();
    }
}
```

🛠️ Configuration
```
# AsyncFixer04: Fire & forget async call inside a using block
dotnet_diagnostic.AsyncFixer04.severity = error

# RCS1229: Use async/await when necessary.
dotnet_diagnostic.RCS1229.severity = error
```

There is a small difference between those two analyzers. `RCS1229` is reported on the method level and `AsyncFixer04` is reported in the return statement line which is IMHO more intuitive. I also observed that those diagnostics are not able to report the issue while using a new `using var` syntax:

```cs
private Task<int> DoSomething(CancellationToken cancellationToken)
{
    using var service = CreateService();
    return service.GetAsync(cancellationToken); // THIS SHOULD BE REPORTED!!!
}
```
In `Roslynator` this problem has been recently fixed [issues/726](https://github.com/JosefPihrt/Roslynator/issues/726) (it's not released yet at the moment of publishing this article)

### 7. Unobserved result of asynchronous method

Missing `await` keyword before asynchronous operation will result in function completing before a given async operation finish. The function will behave non-deterministically and the outcome will be different from the expectations. What is worst, if the un-awaited expression throws an exception it goes unnoticed and it doesn't cause the process crash which makes it eve more harder to spot. You should always await asynchronous expression or assign a returned task to a variable and ensure that finally something awaits it.

❌ Wrong

```cs
async Task DoSomethingAsync()
{
    await DoSomethingAsync1(); 
    DoSomethingAsync2(); // Reported diagnostics: CS4014, VSTHRD110
    await DoSomethingAsync3(); 
}
```

✔️ Correct
```cs
async Task DoSomethingAsync()
{
    await DoSomethingAsync1(); 
    await DoSomethingAsync2();
    await DoSomethingAsync3();
}
```


🛠️ Configuration
```
# VSTHRD110: Observe result of async calls
dotnet_diagnostic.VSTHRD110.severity = error

# CS4014: Because this call is not awaited, execution of the current method continues before the call is completed
dotnet_diagnostic.CS4014.severity = error
```

There's also a standard compiler warning `CS4014` for tat issue but it's only able to report un-awaited expressions inside the `async` methods.


## Summary

| #   | Code smell                               | AsyncFixer          | VS-Threading    | Roslyn.Analyzers | Roslynator     |
|----:|------------------------------------------|---------------------|-----------------|------------------|----------------|
| 1.  | Unnecessary async/await usage            | 🔎🛠️  AsyncFixer01 |                 |                  | 🔎🛠️  RCS1174 |
| 2.  | Call sync methods inside async method    | 🔎🛠️  AsyncFixer02 | 🔎🛠️ VSTHRD103 |                  |                |
| 3.  | Async void methods                       | 🔎🛠️ AsyncFixer03  | 🔎🛠️ VSTHRD100 | 🔎🛠️  ASYNC0003 |                |
| 4.  | Unsupported async delegates              |                     | 🔎 VSTHRD101    |                  |                |
| 5.  | Not awaited Task within using expression |                     | 🔎🛠️ VSTHRD107 |                  |                |
| 6.  | Not awaited Task inside the using block  | 🔎 AsyncFixer04     |                 |                  | 🔎🛠️ RCS1229  |
| 7.  | Unobserved result of asynchronous method |                     | 🔎 VSTHRD110    |                  |                |



🔎 - Analyzer

🛠️ - CodeFix
