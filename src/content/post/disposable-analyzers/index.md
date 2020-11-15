---
title: "Scavenging overlooked disposables with code analyzers"
description: "Which analyzer package should I use and how to configure it to avoid most common problems related to disposables."
date: 2020-11-07T16:00:45+02:00
tags : ["dotnet", "csharp", "disposable", "roslyn", "analyzers"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---

Have you ever missed to disposed an object which require that? How many times this was caused by the fact that you didn't know that a given type implements `IDisposable`? How many times did it slip through your code review? Did it result in the production incident? You can stop worrying about those problems thanks to code analyzers. I'm going to show you now where you can find appropriate rules and how to configure them.


TODO: Does it handle new `using var` syntax?
TODO: Handle Async Disposable
TODO: http://joeduffyblog.com/2005/04/08/dg-update-dispose-finalization-and-resource-management/
TODO: https://docs.microsoft.com/en-us/dotnet/standard/garbage-collection/unmanaged
TODO: Other disposable code smells (split init logic from constructor)

Problems:
- Method that return a tuple of disposables
- Factory method that prepares a tuple of disposable objects
- Not obvious who's responsible for disposing when the instance is passed between the objects
- Does the dispose fire when exception occurs in the constructor?
- exception between disposing two objects
Trying to apply disposable related analyzers to my solutions I've spotted a few quite common patters
of using IDisposable types that violate analyzers rules and I wasn't able to satisfied them - even when I fixed the real problem.


```cs
public static DisposableWrapper Create()
{
    var disposableInner1 = new DisposableType1(); // Reports: CA2000
    var disposableInner2 = new DisposableType2();
    return new DisposableWrapper(disposableInner1, disposableInner2);
}
``` 

```cs
public static DisposableWrapper Create()
{
    DisposableType1 disposableInner1;
    DisposableType2 disposableInner2;
    try
    {
        var disposableInner1 = new DisposableType1();
        var disposableInner2 = new DisposableType2();
        return new DisposableWrapper(disposableInner1, disposableInner2);
    }
    catch
    {
        disposableInner1?.Dispose();
        disposableInner2?.Dispose();
        throw;
    }
}
```

```cs
var (disposable1, disposable2) = CreateSomething();
```



{{< tabs tabTotal="5" tabID="1" tabName1="FXCop (7)" tabName2="Roslynator (1)" tabName3="Code Cracker (4)"  tabName4="Disposable Fixer (23)" tabName5="Sonar (8)" >}}
{{< tab tabNum="1" >}}

|Code|Title|Severity|Enabled|Code fix|
|---|----|:----:|:----:|:----:|
|[CA1001](https://docs.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1001)|Types that own disposable fields should be disposable|<span title="Warning">⚠️</span>|✔️|✔️|
|[CA1063](https://docs.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1063)|Implement IDisposable Correctly|<span title="Warning">⚠️</span>|✔️|❌|
|[CA1816](https://docs.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1816)|Dispose methods should call SuppressFinalize|<span title="Warning">⚠️</span>|✔️|❌|
|[CA2000](https://docs.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca2000)|Dispose objects before losing scope|<span title="Warning">⚠️</span>|✔️|❌|
|[CA2213](https://docs.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca2213)|Disposable fields should be disposed|<span title="Warning">⚠️</span>|✔️|❌|
|[CA2215](https://docs.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca2215)|Dispose methods should call base class dispose|<span title="Warning">⚠️</span>|✔️|✔️|
|[CA2216](https://docs.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca2216)|Disposable types should declare finalizer|<span title="Warning">⚠️</span>|✔️|❌|

👉 [Full list of supported rules](https://github.com/dotnet/roslyn-analyzers/blob/master/src/Microsoft.CodeAnalysis.FxCopAnalyzers/Microsoft.CodeAnalysis.FxCopAnalyzers.md)

👉 [Nuget package](https://www.nuget.org/packages/Microsoft.CodeAnalysis.FxCopAnalyzers/)

👉 [Official website](https://github.com/dotnet/roslyn-analyzers#microsoftcodeanalysisfxcopanalyzers)


{{< /tab >}}
{{< tab tabNum="2" >}}

|Code|Title|Severity|Enabled|Code fix|
|---|----|:----:|:----:|:----:|
|[RCS1133](http://pihrt.net/roslynator/analyzer?id=RCS1133)|Remove redundant Dispose/Close call.|<span title="Hidden">👻</span>|✔️|✔️|

👉 [Full list of supported rules](https://github.com/JosefPihrt/Roslynator/blob/master/src/Analyzers/README.md)

👉 [Nuget package](https://www.nuget.org/packages/Roslynator.Analyzers/)

👉 [Official website](https://github.com/JosefPihrt/Roslynator)


{{< /tab >}}
{{< tab tabNum="3" >}}

|Code|Title|Severity|Enabled|Code fix|
|---|----|:----:|:----:|:----:|
|[CC0022](https://code-cracker.github.io/diagnostics/CC0022.html)|Should dispose object|<span title="Warning">⚠️</span>|✔️|✔️|
|[CC0029](https://code-cracker.github.io/diagnostics/CC0029.html)|Disposables Should Call Suppress Finalize|<span title="Warning">⚠️</span>|✔️|✔️|
|[CC0032](https://code-cracker.github.io/diagnostics/CC0032.html)|Dispose Fields Properly|<span title="Info">ℹ️</span>|✔️|✔️|
|[CC0033](https://code-cracker.github.io/diagnostics/CC0033.html)|Dispose Fields Properly|<span title="Warning">⚠️</span>|✔️|✔️|


👉 [Full list of supported rules](https://code-cracker.github.io/diagnostics.html)

👉 [Nuget package](https://www.nuget.org/packages/codecracker.CSharp/)

👉 [Official website](https://code-cracker.github.io)


{{< /tab >}}
{{< tab tabNum="4" >}}

|Code|Title|Severity|Enabled|Code fix|
|---|----|:----:|:----:|:----:|
|DF0000|Marks undisposed anonymous objects from object creations.|<span title="Warning">⚠️</span>|✔️|✔️|
|DF0001|Marks undisposed anonymous objects from method invocations.|<span title="Warning">⚠️</span>|✔️|✔️|
|DF0010|Marks undisposed local variables.|<span title="Warning">⚠️</span>|✔️|✔️|
|DF0020|Marks undisposed objects assinged to a field, originated in an object creation.|<span title="Warning">⚠️</span>|✔️|✔️|
|DF0021|Marks undisposed objects assinged to a field, originated from method invocation.|<span title="Warning">⚠️</span>|✔️|✔️|
|DF0022|Marks undisposed objects assinged to a property, originated in an object creation.|<span title="Warning">⚠️</span>|✔️|✔️|
|DF0023|Marks undisposed objects assinged to a property, originated from a method invocation.|<span title="Warning">⚠️</span>|✔️|✔️|
|DF0024|Marks undisposed objects assinged to a field, originated in an object creation.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0025|Marks undisposed objects assinged to a field, originated from method invocation.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0026|Marks undisposed objects assinged to a property, originated in an object creation.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0027|Marks undisposed objects assinged to a property, originated from a method invocation.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0028|Marks undisposed factory properties.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0029|Marks undisposed static factory properties.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0030|Marks undisposed objects assinged to a field, originated in an object creation.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0031|Marks undisposed objects assinged to a field, originated from method invocation.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0032|Marks undisposed objects assinged to a property, originated in an object creation.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0033|Marks undisposed objects assinged to a property, originated from a method invocation.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0034|Marks undisposed objects assinged to a field, originated in an object creation.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0035|Marks undisposed objects assinged to a field, originated from method invocation.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0036|Marks undisposed objects assinged to a property, originated in an object creation.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0037|Marks undisposed objects assinged to a property, originated from a method invocation.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0100|Marks return values that hides the IDisposable implementation of return value.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0110|Marks an Dispose implementation that is not in use.|<span title="Warning">⚠️</span>|✔️|❌|

Disposable Fixer seems to be very rich set of dispose related rules. However, the rule that tracks un-disposed object is split into several sub-rules based on the object source (creation, method call) and the object holder (no holder - anonymous object, static field, static property, this instance field, this instance property, other object property, other object field etc).


It has 23 rules but there's a lof duplication and in a result there are 11 different (unique) rules:

|Code|Title|Severity|Enabled|Code fix|
|---|----|:----:|:----:|:----:|
|DF0000|Marks undisposed anonymous objects from object creations.|<span title="Warning">⚠️</span>|✔️|✔️|
|DF0001|Marks undisposed anonymous objects from method invocations.|<span title="Warning">⚠️</span>|✔️|✔️|
|DF0010|Marks undisposed local variables.|<span title="Warning">⚠️</span>|✔️|✔️|
|DF0020|Marks undisposed objects assinged to a field, originated in an object creation.|<span title="Warning">⚠️</span>|✔️|✔️|
|DF0021|Marks undisposed objects assinged to a field, originated from method invocation.|<span title="Warning">⚠️</span>|✔️|✔️|
|DF0022|Marks undisposed objects assinged to a property, originated in an object creation.|<span title="Warning">⚠️</span>|✔️|✔️|
|DF0023|Marks undisposed objects assinged to a property, originated from a method invocation.|<span title="Warning">⚠️</span>|✔️|✔️|
|DF0028|Marks undisposed factory properties.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0029|Marks undisposed static factory properties.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0100|Marks return values that hides the IDisposable implementation of return value.|<span title="Warning">⚠️</span>|✔️|❌|
|DF0110|Marks an Dispose implementation that is not in use.|<span title="Warning">⚠️</span>|✔️|❌|


👉 [Visual Studio Extension](https://marketplace.visualstudio.com/items?itemName=DavidStormer.DisposableFixer2019)

👉 [Nuget package](https://www.nuget.org/packages/DisposableFixer/)

👉 [Official website](https://github.com/BADF00D/DisposableFixer)

{{< /tab >}}
{{< tab tabNum="5" >}}

|Code|Title|Severity|Enabled|Code fix|
|---|----|:----:|:----:|:----:|
|[S2930](https://rules.sonarsource.com/csharp/RSPEC-2930)|"IDisposables" should be disposed|<span title="Warning">⚠️</span>|✔️|❌|
|[S2931](https://rules.sonarsource.com/csharp/RSPEC-2931)|Classes with "IDisposable" members should implement "IDisposable"|<span title="Warning">⚠️</span>|❌|❌|
|[S2952](https://rules.sonarsource.com/csharp/RSPEC-2952)|Classes should "Dispose" of members from the classes' own "Dispose" methods|<span title="Warning">⚠️</span>|❌|❌|
|[S2953](https://rules.sonarsource.com/csharp/RSPEC-2953)|Methods named "Dispose" should implement "IDisposable.Dispose"|<span title="Warning">⚠️</span>|✔️|❌|
|[S2997](https://rules.sonarsource.com/csharp/RSPEC-2997)|"IDisposables" created in a "using" statement should not be returned|<span title="Warning">⚠️</span>|✔️|❌|
|[S3881](https://rules.sonarsource.com/csharp/RSPEC-3881)|"IDisposable" should be implemented correctly|<span title="Warning">⚠️</span>|✔️|❌|
|[S3966](https://rules.sonarsource.com/csharp/RSPEC-3966)|Objects should not be disposed more than once|<span title="Warning">⚠️</span>|✔️|❌|
|[S4002](https://rules.sonarsource.com/csharp/RSPEC-4002)|Disposable types should declare finalizers|<span title="Warning">⚠️</span>|❌|❌|


👉 [Visual Studio Extension](https://www.sonarlint.org/visualstudio)

👉 [Full list of supported rules](https://rules.sonarsource.com/csharp)

👉 [Nuget package](https://www.nuget.org/packages/SonarAnalyzer.CSharp/)

👉 [Official website](https://rules.sonarsource.com/)

{{< /tab >}}
{{< /tabs >}}



## Summary


|#|Title|FxCop|Roslynator|Code Cracker|Sonar|Disposable Fixer|
|---:|----|:----:|:----:|:----:|:----:|:----:|
|1|Implement IDisposable Correctly|✔️|❌|❌|✔️|❌|
|2|Types that own disposable fields should be disposable|✔️|❌|❌|✔️|❌|
|3|Dispose methods should call SuppressFinalize|✔️|❌|✔️|❌|❌|
|4|Disposable fields should be disposed|✔️|❌|✔️|✔️|❌|
|5|Disposable types should declare finalizer|✔️|❌|❌|✔️|❌|
|6|Dispose methods should call base class dispose|✔️|❌|❌|❌|❌|
|7|Dispose objects before losing scope|✔️|❌|✔️|✔️|✔️|
|8|Remove redundant Dispose/Close call.	|❌|✔️|❌|❌|❌|
|9|Objects should not be disposed more than once|❌|❌|❌|✔️|❌|
|10|"IDisposables" created in a "using" statement should not be returned|❌|❌|❌|✔️|❌|
|11|Classes should "Dispose" of members from the classes’ own "Dispose" methods|❌|❌|❌|✔️|❌|
|12|Methods named "Dispose" should implement "IDisposable.Dispose" |❌|❌|❌|✔️|❌|
|13|Return values that hides the IDisposable implementation of return value.|❌|❌|❌|❌|✔️|
|14|Redundant Dispose method |❌|❌|❌|❌|✔️|