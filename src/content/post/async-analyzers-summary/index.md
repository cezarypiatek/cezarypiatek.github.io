---
title: "Async code smells and how to track them down with analyzers - Summary"
description: "Which analyzer package should I use and how to configure it to avoid most common problems related to async/await."
date: 2020-10-25T10:00:45+02:00
tags : ["dotnet", "csharp", "async", "roslyn", "analyzers"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---

In the last two posts I've described 14 different code smells related to the `async/await` keywords. Besides the problem description I've also provided info about code analyzers which are able to detect and report a given issue. Those analyzer comes from few different packages that are not strictly devoted to the asynchronous programming area. They contain also rules from other fields with predefined severity which might not be appropriate to your needs or you might not be interested in enforcing them at all. The fact that those analyzers comes from different packages provided by different community members results in duplicated effort (some rules were implemented more than once) and force us to spend more time researching then and deciding which one to use. **I wish there was a single analyzer package that contains all those rules related to async programming, and only them.** This will result in better time disposition of people who works on the analyzers (in most cases, they are doing it in their spare time without getting paid for it), increasing analyzers quality and definitely simplify the consumption. Right now we need to somehow deal with what we have. To save you some time and to finally answer the question **"Which analyzer package should I use and how to configure it to avoid problems related to async/await?"** I decided to write this summary. 

## Installing the analyzers

Here's the entries for `csproj` that add async analyzers to your project.

```xml
<ItemGroup>
    <PackageReference Include="AsyncFixer" Version="1.3.0">
        <PrivateAssets>all</PrivateAssets>
        <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
    <PackageReference Include="Asyncify" Version="0.9.7" >
        <PrivateAssets>all</PrivateAssets>
        <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
    <PackageReference Include="Meziantou.Analyzer" Version="1.0.570">
        <PrivateAssets>all</PrivateAssets>
        <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
    <PackageReference Include="Microsoft.CodeAnalysis.FxCopAnalyzers" Version="3.3.0">
        <PrivateAssets>all</PrivateAssets>
        <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
    <PackageReference Include="Microsoft.VisualStudio.Threading.Analyzers" Version="16.8.50" >
        <PrivateAssets>all</PrivateAssets>
        <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
    <PackageReference Include="Roslynator.Analyzers" Version="3.0.0">
        <PrivateAssets>all</PrivateAssets>
        <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
</ItemGroup>
```

If you install analyzer packages manually using Nuget UI or CLI then you might notice that some package references are decorated with
`PrivateAssets` as well as `IncludeAssets` properties. This is due to the fact that packages were marked as [DevelopmentDependency](https://docs.microsoft.com/en-us/nuget/reference/nuspec#developmentdependency). **I think the lack of those attributes is rather an overlook and you can safely add them for analyzer references which are missing them** - they do not provide any runtime dependencies which will be required to run your app or library. **If you do not add it, those packages became your dependencies which is rather not expected:**

![Nuget package with references to other analyzers](package_dependencies.jpg)


> I decided to not use `Roslyn.Analyzers` package because the maintainer is not responding to Github Issues and PRs. No activity since 2017 so the project looks dead to me.




## Configuring the rules

```
# AsyncFixer01: Unnecessary async/await usage
dotnet_diagnostic.AsyncFixer01.severity = suggestion

# RCS1174: Remove redundant async/await.
dotnet_diagnostic.RCS1174.severity = suggestion

# AsyncFixer02: Long-running or blocking operations inside an async method
dotnet_diagnostic.AsyncFixer02.severity = error

# NOTE: Not working when method is async
dotnet_diagnostic.VSTHRD103.severity = error

# AsyncFixer03: Fire & forget async void methods
dotnet_diagnostic.AsyncFixer03.severity = error

# VSTHRD100: Avoid async void methods
dotnet_diagnostic.VSTHRD100.severity = error

# VSTHRD101: Avoid unsupported async delegates
dotnet_diagnostic.VSTHRD101.severity = error

# VSTHRD107: Await Task within using expression
dotnet_diagnostic.VSTHRD107.severity = error

# AsyncFixer04: Fire & forget async call inside a using block
dotnet_diagnostic.AsyncFixer04.severity = error

# RCS1229: Use async/await when necessary.
dotnet_diagnostic.RCS1229.severity = error

# VSTHRD110: Observe result of async calls
dotnet_diagnostic.VSTHRD110.severity = error

# CS4014: Because this call is not awaited, execution of the current method continues before the call is completed
dotnet_diagnostic.CS4014.severity = error

# VSTHRD002: Avoid problematic synchronous waits
dotnet_diagnostic.VSTHRD002.severity = error

# MA0045: Do not use blocking call (make method async)
dotnet_diagnostic.MA0045.severity = error

# AsyncifyInvocation: Use Task Async
dotnet_diagnostic.AsyncifyInvocation.severity = error

# AsyncifyVariable: Use Task Async
dotnet_diagnostic.AsyncifyVariable.severity = error

# MA0004: Use .ConfigureAwait(false)
dotnet_diagnostic.MA0004.severity = none

# RCS1090: Call 'ConfigureAwait(false)'.
dotnet_diagnostic.RCS1090.severity = none

# VSTHRD111: Use ConfigureAwait(bool)
dotnet_diagnostic.VSTHRD111.severity = none

# CA2007: Consider calling ConfigureAwait on the awaited task
dotnet_diagnostic.CA2007.severity = none

# MA0022: Return Task.FromResult instead of returning null
dotnet_diagnostic.MA0022.severity = error

# RCS1210: Return Task.FromResult instead of returning null.
dotnet_diagnostic.RCS1210.severity = error

# VSTHRD114: Avoid returning a null Task
dotnet_diagnostic.VSTHRD114.severity = error

# VSTHRD200: Use "Async" suffix for async methods
dotnet_diagnostic.VSTHRD200.severity = none

#RCS1046: Asynchronous method name should end with 'Async'.
dotnet_diagnostic.RCS1046.severity = none

# VSTHRD200: Use "Async" suffix for async methods
dotnet_diagnostic.VSTHRD200.severity = none

# RCS1047: Non-asynchronous method name should not end with 'Async'.
dotnet_diagnostic.RCS1047.severity = none

# MA0040: Specify a cancellation token
dotnet_diagnostic.MA0032.severity = suggestion

# MA0040: Flow the cancellation token when available
dotnet_diagnostic.MA0040.severity = error

# MA0079: Use a cancellation token using .WithCancellation()
dotnet_diagnostic.MA0079.severity = suggestion

# MA0080: Use a cancellation token using .WithCancellation()
dotnet_diagnostic.MA0080.severity = error
```

Explanation:
- Rules related to redundant `async/await` keywords marked as `suggestion` because are not critical and should be applied with caution.
- All rules related to blocking calls are marked as `error`.
- Rules detecting `async void` methods and lambdas as well as and un-awaited asynchronous operations configured with severity set to `error`.
- Detecting missing `ConfigureAwait(false)` discarded because right now I'm not working on apps with SynchronizationContext. It should be applied with caution.
- Returning null instead of Task set to `error`
- Rules related to the async method naming convention discarded. Those conventions don't make any sense to me.
- Rules verifying the flow of `CancellationToken` set to severity `error.
- Rules enforcing the mandatory of `CancellationToken` set to `suggestion` - Satisfying that rule can result in introducing breaking changes in the API.

You can have two options. You can leave the default settings as they are and progressively adjust it to your need or you can set them all to none and the increase the severity for the rules that you are interested in. You can easily set the severity for multiple rules at once using a context menu in the Solution Explorer:


## Summary

| #   | Code smell                                             | AsyncFixer          | VS-Threading    | Roslyn.Analyzers | Meziantou.Analyzer | Roslynator     | FxCop       | Asyncify                                  |
|----:|--------------------------------------------------------|---------------------|-----------------|------------------|--------------------|----------------|-------------|-------------------------------------------|
| 1.  | Unnecessary async/await usage                          | 🔎🛠️  AsyncFixer01 |                 |                  |                    | 🔎🛠️  RCS1174 |             |                                           |
| 2.  | Call sync methods inside async method                  | 🔎🛠️  AsyncFixer02 | 🔎🛠️ VSTHRD103 |                  |                    |                |             |                                           |
| 3.  | Async void methods                                     | 🔎🛠️ AsyncFixer03  | 🔎🛠️ VSTHRD100 | 🔎🛠️  ASYNC0003 |                    |                |             |                                           |
| 4.  | Unsupported async delegates                            |                     | 🔎 VSTHRD101    |                  |                    |                |             |                                           |
| 5.  | Not awaited Task within using expression               |                     | 🔎🛠️ VSTHRD107 |                  |                    |                |             |                                           |
| 6.  | Not awaited Task inside the using block                | 🔎 AsyncFixer04     |                 |                  |                    | 🔎🛠️ RCS1229  |             |                                           |
| 7.  | Unobserved result of asynchronous method               |                     | 🔎 VSTHRD110    |                  |                    |                |             |                                           |
| 8.  | Synchronous waits                                      |                     | 🔎🛠️VSTHRD002  |                  | 🔎MA0042, MA0045   |                |             | 🔎🛠️AsyncifyInvocation, AsyncifyVariable |
| 9.  | Missing `ConfigureAwait(bool)`                         |                     | 🔎🛠️VSTHRD111  | 🔎🛠️ ASYNC0004  | 🔎🛠️ MA0004       | 🔎🛠️RCS1090   | 🔎🛠️CA2007 |                                           |
| 10. | Returning null from a Task-returning method            |                     | 🔎🛠️VSTHRD114  |                  | 🔎MA0022           | 🔎🛠️RCS1210   |             |                                           |
| 11. | Asynchronous method names should end with Async        |                     | 🔎🛠️VSTHRD200  | 🔎🛠️ASYNC0001   |                    | 🔎RCS1046      |             |                                           |
| 12. | Non asynchronous method names shouldn't end with Async |                     |                 | 🔎🛠️ASYNC0002   |                    | 🔎RCS1047      |             |                                           |
| 13. | Pass cancellation token                                |                     |                 |                  | 🔎MA0032,MA0040    |                |             |                                           |
| 14. | Using cancellation token with IAsyncEnumerable         |                     |                 |                  | 🔎MA0079,MA0080    |                |             |                                           |


🔎 - Analyzer

🛠️ - CodeFix