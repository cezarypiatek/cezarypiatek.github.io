---
title: "Most common async code smells and how to track them down with analyzers"
description: "How to configure dotnet core solutions to automatically generate client packages for WebAPI projects"
date: 2020-09-13T00:11:45+02:00
tags : ["NSwag", "AspCore", "C#", "WebAPI", "Rest"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
draft: true
---

##  Microsoft.CodeAnalysis.FxCopAnalyzers
https://github.com/dotnet/roslyn-analyzers/blob/master/src/Microsoft.CodeAnalysis.FxCopAnalyzers/Microsoft.CodeAnalysis.FxCopAnalyzers.md

| Id | Description | Default Severity | CodeFix |
| -- | ----------- | ----------- | ---- |
[CA2007](https://docs.microsoft.com/visualstudio/code-quality/ca2007) | Consider calling ConfigureAwait on the awaited task | Warning | Yes |
[CA2008](https://docs.microsoft.com/visualstudio/code-quality/ca2008) | Do not create tasks without passing a TaskScheduler |  Warning | No |
[CA2012](https://docs.microsoft.com/visualstudio/code-quality/ca2012) | Use ValueTasks correctly |  Warning | No |
[CA2247](https://docs.microsoft.com/visualstudio/code-quality/ca2247) | Argument passed to TaskCompletionSource constructor should be TaskCreationOptions enum instead of TaskContinuationOptions enum|Warning | Yes 


## Microsoft.VisualStudio.Threading.Analyzers (VSTHR)

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
| [ASYNC0002](https://roslyn-analyzers.readthedocs.io/en/latest/analyzers-info/async/non-async-method-names-should-not-be-suffixed-with-async.html#non-async-method-names-should-not-be-suffixed-with-async) |	Non asynchronous method names shouldn't end with Async | Warning |
| [ASYNC0003](https://roslyn-analyzers.readthedocs.io/en/latest/analyzers-info/async/avoid-async-void-methods.html#avoid-async-void-methods) |	Avoid void returning asynchronous method |	Warning |
| [ASYNC0004](https://roslyn-analyzers.readthedocs.io/en/latest/analyzers-info/async/use-configure-await-false.html#use-configure-await-false) |	Use ConfigureAwait(false) on await expression |	Warning |


## Meziantou.Analyzer

https://www.meziantou.net/enforcing-asynchronous-code-good-practices-using-a-roslyn-analyzer.htm
https://github.com/meziantou/Meziantou.Analyzer/tree/master/docs

| Id | Description | Default Severity |
| -- | ----------- | ----------- |
| [MA0004](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0004.md) | Use .ConfigureAwait(false) | Warning |
| [MA0032](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0032.md) | Specify a cancellation token | Info |
| [MA0040](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0040.md) | Flow the cancellation token when available | Info |
| [MA0045](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0045.md) | Do not use blocking call (make method async) | Info |
| [MA0079](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0079.md) | Flow a cancellation token using .WithCancellation() | Info |
| [MA0080](https://github.com/meziantou/Meziantou.Analyzer/blob/master/docs/Rules/MA0080.md) | Specify a cancellation token using .WithCancellation() | Info |

## Roslynator

https://github.com/JosefPihrt/Roslynator/blob/master/src/Analyzers/README.md

| Id | Description | Default Severity |
| -- | ----------- | ----------- |
| [RCS1046](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1046.md) | Asynchronous method name should end with 'Async' |	None |
| [RCS1047](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1047.md) | Non-asynchronous method name should not end with 'Async' |	Info |
| [RCS1090](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1090.md) | Call 'ConfigureAwait(false)' |	Info |
| [RCS1174](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1174.md) | Remove redundant async/await |	None |
| [RCS1210](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1210.md) | Return Task.FromResult instead of returning null |	Warning |
| [RCS1229](https://github.com/JosefPihrt/Roslynator/blob/master/docs/analyzers/RCS1229.md) | Use async/await when necessary |	Info |



https://github.com/hvanbakel/Asyncify-CSharp
https://www.nuget.org/packages/Asyncify/


## Async Code Smells

### 1. Redundant async/await

Using `async/await` keyword results in implicit memory allocation required for the state machine responsible for orchestrating asynchronous invocations. When the awaited expression is the only one or the last statement in the function it might be skipped. However, there's a couple of concerns around this code optimization which you should be aware of. Before you start applying it I highly recommend reading an excellent blog post about it from Stephen Cleary [Eliding Async and Await](https://blog.stephencleary.com/2016/12/eliding-async-await.html)

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

If we are writing asynchronous code then we should always prefer calling asynchronous methods if they exist. Many IO related APIs offer asynchronous counterparts of their well know synchronous methods. Their should be our first choice.

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

There ara two reason why Async Void methods are harmful: 
- A caller of the method is not able to await asynchronous operation.
- There's no way to handle exception throw by te method. `!!!If the exception occurs your process crash!!!`.

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

If we pass asynchronous lambda function the `Action` argument, compiler generates `async void` method which downsides were described in the previous code smell. There are two solutions for this problem: if it's possible then we should change parameter type from `Action` to `Func<Task>` otherwise we need to implement that callback delegate synchronously. It's worth to mention that some APIs already provide counterparts of their methods that accepts `Func<Task>` for the callback parameters.

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

`System.Threading.Tasks.Task` implements `IDisposable` interface. Calling a method returning task directly in `using` expressions results in `Task` disposal at the end of `using` block which is never a expected behavior.

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

If we skip `await` keyword for asynchronous operation inside the `using` block then the disposable object could be disposed before asynchronous invocation finish. This might result in incorrect behavior and very often ends with a runtime exception notifying that we are trying to perform operation on the object that is already disposed. This issue has two root causes: either is done by accident when somebody simply forgot about adding `async/await` keywords or it's a result of incorrectly applied code optimization described in `Redundant async/await` code smell. 

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

Missing `await` keyword for asynchronous operation will result in function completing before a given async operation finish. The function will behave non-deterministically and the final outcome will be different from the expectations. What is worst, if un-waited expression throws an exception it 
goes unnoticed and it doesn't cause process crash which makes it eve more harder to spot. You should always await asynchronous expression or assign returned task to a variable and ensure that finally something await it.

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

There's also a standard compiler warning `CS4014` for tat issue but it's only able to report un-waited expressions inside the `async` methods.

### 8. Synchronous waits

`async/await` keyword are viral which means if you want to await asynchronous expression and you are in non-asyc method then you are forced to rewrite the whole call chain to asynchronous. The easier solution seems to be calling `Wait` or `Result` on the returned task but it's just asking for the troubles. This solution will cost you two thread for that execution or even result in a deadlock. This problem is more widely described in [
ASP.NET Core Diagnostic Scenarios - Asynchronous Programming](https://github.com/davidfowl/AspNetCoreDiagnosticScenarios/blob/master/AsyncGuidance.md#avoid-using-taskresult-and-taskwait). I highly recommend reading this article - you will find there even more asynchronous code smells.

❌ Wrong

```cs
void DoSomething()
{
    Thread.Sleep(1); // Reported diagnostics: MA0045
    Task.Delay(2).Wait();  // Reported diagnostics: VSTHRD002, MA0045
    var result1 = GetAsync().Result; // Reported diagnostics: VSTHRD002, MA0045
    var result2 = GetAsync().GetAwaiter().GetResult() // Reported diagnostics: VSTHRD002, MA0045
}
```

✔️ Correct
```cs
void DoSomething()
{
    await Task.Delay(1);
    await Task.Delay(2);    
    var result1 = await GetAsync();
    var result2 = await GetAsync();
}
```


🛠️ Configuration
```
# VSTHRD002: Avoid problematic synchronous waits
dotnet_diagnostic.VSTHRD002.severity = error

# MA0045: Do not use blocking call (make method async)
dotnet_diagnostic.MA0045.severity = error
```

### 9. Missing ConfigureAwait(bool)

By default, when we await asynchronous operation using `await` keyword, the continuation is scheduled using captured SynchronizationContext or TaskScheduler. This comes with additional performance cost and might result in deadlock depends on the SynchronizationContext/TaskScheduler provided by the environment - especially in `WindowsForms`, `WPF` and old `ASP.NET` application (yes, ASP.NET Core is not using SynchronizationContext). `ConfigureAwait` method wraps returned task into `ConfiguredTaskAwaitable` structure which change the logic of scheduling the continuation. By calling `ConfigureAwait(continueOnCapturedContext: false)` we are ensuring that the current context (if provided) is ignored while invoking the continuation. Setting `continueOnCapturedContext` parameter to `true` doesn't make any sense. If you want to go into the details about this subject I recommend reading [ConfigureAwait FAQ](https://devblogs.microsoft.com/dotnet/configureawait-faq/) by `Stephen Toub`.  

❌ Wrong

```cs
async Task DoSomethingAsync()
{
    await DoSomethingElse(); //Reported diagnostics: ASYNC0004, MA0004, RCS1090, VSTHRD111
}
```

✔️ Correct
```cs
async Task DoSomethingAsync()
{
    await DoSomethingElse().ConfigureAwait(false);
}
```

🛠️ Configuration
```
# ASYNC0004: Use ConfigureAwait(false) on await expression
dotnet_diagnostic.ASYNC0004.severity = error

# MA0004: Use .ConfigureAwait(false)
dotnet_diagnostic.MA0004.severity = error

# RCS1090: Call 'ConfigureAwait(false)'.
dotnet_diagnostic.RCS1090.severity = error

# VSTHRD111: Use ConfigureAwait(bool)
dotnet_diagnostic.VSTHRD111.severity = error
```

All of the above analyzers offer appropriate code fix.

### 10. Returning null from a Task-returning method

Returning `null` value from non-async method that declares `Task/Task<>` as a returning type results in `NullReferenceException` if somebody awaits the method invocation. To avoid that, you should always return result from this kind of method using `Task.CompletedTask` or `Task.FromResult<T>(null)` helpers.
  
❌ Wrong

```cs
Task DoAsync() 
{
    return null; //Reported diagnostics: MA0022, VSTHRD114
}

Task<object> GetSomethingAsync() 
{
    return null;  //Reported diagnostics: MA0022, VSTHRD114, RCS1210
}

Task<HttpResponseMessage> TryGetAsync(HttpClient httpClient)
{
    return httpClient?.GetAsync("/some/endpoint"); //Reported diagnostics: RCS1210
}
```

✔️ Correct
```cs
Task DoAsync() 
{
    return Task.CompletedTask;
}

Task<object> GetSomethingAsync() 
{
    return Task.FromResult<object>(null);
}

Task<HttpResponseMessage> TryGetAsync(HttpClient httpClient)
{
    return httpClient?.GetAsync("/some/endpoint") ?? Task.FromResult(default(HttpResponseMessage));
}
```

🛠️ Configuration
```
# MA0022: Return Task.FromResult instead of returning null
dotnet_diagnostic.MA0022.severity = error

# RCS1210: Return Task.FromResult instead of returning null.
dotnet_diagnostic.RCS1210.severity = error

# VSTHRD114: Avoid returning a null Task
dotnet_diagnostic.VSTHRD114.severity = error
```

Right now, non of the analyzers is able to detect all three cases so we should go with one of two combinations: `RCS1210` with `VSTHRD114` or `RCS1210` with `MA0022`.


### 11. Asynchronous method names should end with Async

I'm not a fan of this rule. It adds unnecessary noise and reminds me about the [hungarian notation](https://en.wikipedia.org/wiki/Hungarian_notation). In the description of [VSTHRD200](https://github.com/microsoft/vs-threading/blob/master/doc/analyzers/VSTHRD200.md) we can see:

> `The .NET Guidelines for async methods includes that such methods should have names that include an "Async" suffix.` 

However, I wasn't able to find an original document and there's nothing about it in the [Framework Design Guidelines - Naming Guidelines](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/naming-guidelines). IMHO, this naming convention only makes sense when a class provides both synchronous and asynchronous versions of a given method - this is the case mostly for APIs that were created before `async/await` era. Anyway, if this rule belongs to your coding standard you can easily spot all the violations with the following diagnostics: `VSTHRD200`, `ASYNC0001`, `RCS1046`.

❌ Wrong

```cs
async Task DoSomething() //Reported diagnostics: VSTHRD200, ASYNC0001, RCS1046
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
# ASYNC0001: Asynchronous method names should end with Async
dotnet_diagnostic.ASYNC0001.severity = error

# VSTHRD200: Use "Async" suffix for async methods
dotnet_diagnostic.VSTHRD200.severity = error

#RCS1046: Asynchronous method name should end with 'Async'.
dotnet_diagnostic.RCS1046.severity = error
```


### 12. Non asynchronous method names shouldn't end with Async

This rule definitely makes more sense for me than the previous one. Adding `Async` suffix to non-asynchronous method might cause confusion. I think this code smell is rather a result of carless refactoring or requirements change rather than intended action.

❌ Wrong

```cs
void DoSomethingAsync() //Reported diagnostics: VSTHRD200, ASYNC0002, CS1047
{    
}
```

✔️ Correct
```cs
void DoSomething()
{    
}
```

🛠️ Configuration
```
# VSTHRD200: Use "Async" suffix for async methods
dotnet_diagnostic.VSTHRD200.severity = error

# ASYNC0002: Non asynchronous method names should end with Async
dotnet_diagnostic.ASYNC0002.severity = error

# RCS1047: Non-asynchronous method name should not end with 'Async'.
dotnet_diagnostic.RCS1047.severity = error

```

It's worth to point out that `VSTHRD200` is tracking both naming deviations, it simply check if `Async` suffix is applied correctly. It might be good if you need both rules, but if you just need only check if `Async` suffix is not applied to synchronous methods then you should rather use `ASYNC0002` or `RCS1047`.

### 13. Pass cancellation token

Forgetting about passing cancellation token might cost you a lot of trouble. Log running operation without a cancellation token can block the action of stopping the application or can result in thread starvation when there's a lot of cancelled web requests. In order to avoid such problems you should always provide and pass a cancellation token to the methods that accept it, even if it's an optional parameter. `Meziantou.Analyzer` package implements two diagnostic which can detect missing cancellation token: `MA0032` is reported always when we skip cancellation token parameter and `MA0040` is reported only when there's a cancellation token in current scope that can be used. More details about those analyzers you can find in the article from analyzers author [
Detect missing CancellationToken using a Roslyn Analyzer](https://www.meziantou.net/detect-missing-cancellationtoken-using-a-roslyn-analyzer.htm).

❌ Wrong

```cs
public async Task<string> GetSomethingA(HttpClient httpClient, CancellationToken cancellationToken)
{
    var response = await httpClient.GetAsync(new Uri("/some/endpoint")); //Reported diagnostics: MA0040
    return await response.Content.ReadAsStringAsync();
}

public async Task<string> GetSomethingB(HttpClient httpClient)
{
    var response = await httpClient.GetAsync(new Uri("/some/endpoint")); //Reported diagnostics: MA0032
    return await response.Content.ReadAsStringAsync();
}
```

✔️ Correct
```cs
public async Task<string> GetSomething(HttpClient httpClient, CancellationToken cancellationToken)
{
    var response = await httpClient.GetAsync(new Uri("/some/endpoint"), cancellationToken);
    return await response.Content.ReadAsStringAsync();
}
```

🛠️ Configuration
```
# MA0040: Specify a cancellation token
dotnet_diagnostic.MA0032.severity = error

# MA0040: Flow the cancellation token when available
dotnet_diagnostic.MA0040.severity = error
```

### 14. Using cancellation token with IAsyncEnumerable

This is a similar code smell as the previous one but it's strictly related to the usage of `IAsyncEnumerable` an can quite easily overlooked. It might not be so obvious, but passing a cancellation token to asynchronous enumerator is done by calling `WithCancellation()` method. In case of `IAsyncEnumerable` the `Meziantou.Analyzer` provides two diagnostics: `MA0080` for all missing invocation of `WithCancellation()` method and `MA0079` only when any `CancellationToken` is present in the current context.

❌ Wrong

```cs
async Task IterateB(IAsyncEnumerable<string> enumerable, CancellationToken cancellationToken)
{
    await foreach (var item in enumerable) // Reported diagnostics: MA0079
    {
    }
}

async Task IterateA(IAsyncEnumerable<string> enumerable)
{
    await foreach (var item in enumerable) // Reported diagnostics: MA0080
    {
    }
}
```

✔️ Correct
```cs
async Task Iterate(IAsyncEnumerable<string> enumerable, CancellationToken cancellationToken)
{
    await foreach (var item in enumerable.WithCancellation(cancellationToken)) 
    {
    }
}
```

🛠️ Configuration
```
# MA0079: Use a cancellation token using .WithCancellation()
dotnet_diagnostic.MA0079.severity = error

# MA0080: Use a cancellation token using .WithCancellation()
dotnet_diagnostic.MA0080.severity = error
```

## Summary

| # | Code smell | AsyncFixer | VSTHR | Roslyn.Analyzers | Meziantou.Analyzer | Roslynator |
| --: | -- | ----------- | ----------- |----------- |----------- |----------- |
| 1. | Unnecessary async/await usage  | AsyncFixer01  | | | | RCS1174 |
| 2. | Call sync methods inside async method |   AsyncFixer02  | VSTHRD103 | | |
| 3. | Async void methods | AsyncFixer03  | VSTHRD100 | ASYNC0003 | | |
| 4. | Unsupported async delegates | | VSTHRD101	| | |
| 5. | Not awaited Task within using expression | | VSTHRD107 | | ||
| 6. | Not awaited Task inside the using block  | AsyncFixer04   |  | | | RCS1229
| 7. | Unobserved result of asynchronous method | | VSTHRD110 | | |
| 8. | Synchronous waits | | VSTHRD002 | | MA0042, MA0045 | |
| 9. | Missing `ConfigureAwait(bool)` | | VSTHRD111 | ASYNC0004 | MA0004 | RCS1090	|
| 10.| Returning null from a Task-returning method | | VSTHRD114 | | | RCS1210 |
| 11.| Asynchronous method names should end with Async |  | VSTHRD200 | ASYNC0001 | | RCS1046 |
| 12.| Non asynchronous method names shouldn't end with Async | | | ASYNC0002 | | RCS1047|
| 13.| Pass cancellation token | | | | MA0032,MA0040 | |
| 14.| Using cancellation token with IAsyncEnumerable | | | | MA0079,MA0080 | |
| 15.| Downcasting from a nested task to an outer task |  AsyncFixer05  | | | | |
| 16.| Awaiting foreign Tasks | | VSTHRD003 | | |