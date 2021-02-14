---
title: "Pure functions and unused return values"
description: "How to completely automate continuous integration and release management of visual studio extensions."
date: 2021-02-14T10:00:45+02:00
tags : ["dotnet", "dotnetcore", "roslyn", "code analysis", "ReSharper"]
highlight: true
highlightLang: ["yaml", "powershell","fsharp"]
image: "splashscreen.jpg"
isBlogpost: true
---

[Quick notes on a rant](https://gist.github.com/dsyme/32de0d1bb0799ca438477c34205c3531)

`Implicitly discarding information is so 20th Century`. There are programming languages where returned values need to be explicitly handled. For example in `F#` we have to use somehow the returned value or discard it explicitly with `ignore` function. The following example code will result in compilation warning:

//TODO: Try get example

```fsharp
open System

[<EntryPoint>]
let main argv =
    DateTime.Today.ToShortDateString()
    printfn "Hello World from F#!"
    0
```

> warning FS0020: The result of this expression has type 'string' and is implicitly ignored. Consider using 'ignore' to discard this value explicitly, e.g. 'expr |> ignore', or 'let' to bind the result to a name, e.g. 'let result = expr'.

However, in `PowerShell` unconsumed values are treated as the function results. For example the following function returns a list of two values:

```powershell
```

At first it might be surprising for people who comes from different programming languages but the purpose of `return` keyword is not return the value but rather mark the exit point. The `return value` syntax is a shorthand for:

```powershell
value
return
```
If your function has only one exit point you probably don't need to use `return` keyword at all. Very often our custom `PowerShell` functions return more than we expected. In order to fix that we need to find a line that produce unbound value and discard it by piping it to `Out-Null`. 

Those were examples from other `dotnet` languages, but in `C#`, the unused return values are simply ignored which might result in accidental bugs. Lucky me, I got a pleasure to make this kind of bug and find it later in production code. So what can we do with the lack of support on the language level and protect our `C#` codebase from this kind of bugs? As Don Syme mentioned in his notes, we can use some sort of static code analyzers. This market need was spotted years ago by `JetBrains` company that released [JetBrains.Annotations](https://www.nuget.org/packages/JetBrains.Annotations/2021.1.0-eap01) nuget package that contains various attributes that extend static code analysis performed by their produces (originally only by the `ReSharper`, and later also by the `Rider` too). This package contains [[PureAttribute]](https://www.jetbrains.com/help/resharper/Reference__Code_Annotation_Attributes.html#PureAttribute) which is intended to mark the functions that can be classified as [Pure Function](https://en.wikipedia.org/wiki/Pure_function). Based on the configuration, all unbound calls to those methods are appropriately reported by the [Solution Wide Analysis](https://www.jetbrains.com/help/resharper/Code_Analysis__Solution-Wide_Analysis.html) module. `BCL` also contains [PureAttribute](https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.contracts.pureattribute?view=netframework-4.7.2) which is a part of CodeContracts framework and unused calls to methods with that attribute can be reported as [CA1806: Do not ignore method results](https://docs.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca1806) with [Microsoft.CodeAnalysis.NetAnalyzers](https://www.nuget.org/packages/Microsoft.CodeAnalysis.NetAnalyzers) analyzers package. Unfortunately, `CodeContracts` is dead and `[System.Diagnostics.Contracts.Pure]` annotations is gradually abandoned - you can read more about this attribute here [The Pure Attribute in .NET Core](https://www.infoq.com/news/2019/01/pure-attribute-net-core/).


However, not every return-value-purpose functions can be classified as `Pure Function` because of the side effects cause by the fact of using `IO` - for example methods that read data from external storage like file or database. `JetBrains.Annotations` package contains another attribute for that purpose called [[MustUseReturnValueAttribute]](https://www.jetbrains.com/help/resharper/Reference__Code_Annotation_Attributes.html#MustUseReturnValueAttribute)

This attribute base approach requires additional attention during the function authoring and the lack of those attributes in existing libraries still might be a source of troubles. `JetBrains` offers a something called [External Annotations](https://www.jetbrains.com/help/resharper/Code_Analysis__External_Annotations.html#creating) that should solve the problem with the lack of annotations in third-party libraries but this is still an extra work to do. How about reversing that approach and shifting the burden of deciding if a returned value is needed from method author to the method consumer - just like it's in language like `F#`. To do that I extended my analyzers page [CSharpExtensions](https://github.com/cezarypiatek/CSharpExtensions) with a dedicated diagnostic `CSE005: Return value unused` that is able to find and report every unused result from a method call, await expression, or object creation. By default all violation are reported as warning, but this can be easily changed with an appropriate entry in `ruleset` file or `.editorconfig`

```editorconfig
[*.cs]
dotnet_diagnostic.CSE005.severity = error
```

After running the first version of my analyzer on one of my ASP.Core projects, I got a lot of warnings. Almost all of them were cause by the fluent API's, the one for configuring different aspects of ASP.Core like `dependency injection` or the pipelines and the other hive was located in components using `FluentValidator`. I really don't like those fluent builders because they are really confusing. I always need to check if a given function returns a new instance or the same on which I operated. This approach makes only sense for immutable types, adding it in other situation only for the sake of method call chaining seems to be a real abuse. In order to deal with this kind of third-party methods, I added an option to configure `CSE005` analyzer and exclude a given return types from the analysis.


```json
{
  "CSE005": {
    "IgnoredReturnTypes": [ 
        "Microsoft.Extensions.DependencyInjection.IServiceCollection",
        "Microsoft.Extensions.Configuration.IConfigurationBuilder",
        "Microsoft.Extensions.Logging.ILoggingBuilder"
        ] 
  } 
}
```

To make it work you need to save this config as `CSharpExtensions.json` add include it in your project file as follows:

```xml
<ItemGroup>
    <AdditionalFiles Include="CSharpExtensions.json" />
</ItemGroup>
```