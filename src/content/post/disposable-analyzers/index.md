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

*[Warning]: Not so serious


TODO: Does it handle new `using var` syntax?
TODO: Handle Async Disposable
TODO: http://joeduffyblog.com/2005/04/08/dg-update-dispose-finalization-and-resource-management/
TODO: https://docs.microsoft.com/en-us/dotnet/standard/garbage-collection/unmanaged
TODO: Other disposable code smells (split init logic from constructor)
{{< tabs tabTotal="5" tabID="1" tabName1="FXCop" tabName2="Roslynator" tabName3="CodeCracker"  tabName4="Disposable Fixer" tabName5="Sonar" >}}
{{< tab tabNum="1" >}}

FXCop
https://github.com/dotnet/roslyn-analyzers/blob/master/src/Microsoft.CodeAnalysis.FxCopAnalyzers/Microsoft.CodeAnalysis.FxCopAnalyzers.md

|Code|Title|Severity|Is enabled|Code fix|
|---|----|:----:|:----:|:----:|
|[CA1063](https://docs.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1063)|Implement IDisposable Correctly|⚠️|✔️|❌|
|[CA1001](https://docs.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1001)|Types that own disposable fields should be disposable|⚠️|✔️|✔️|
|[CA1816](https://docs.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1816)|Dispose methods should call SuppressFinalize|⚠️|✔️|❌|
|[CA2213](https://docs.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca2213)|Disposable fields should be disposed|⚠️|✔️|❌|
|[CA2216](https://docs.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca2216)|Disposable types should declare finalizer|⚠️|✔️|❌|
|[CA2215](https://docs.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca2215)|Dispose methods should call base class dispose|⚠️|✔️|✔️|
|[CA2000](https://docs.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca2000)|Dispose objects before losing scope|⚠️|✔️|❌|

{{< /tab >}}
{{< tab tabNum="2" >}}
Roslynator:

|Code|Title|Severity|Is enabled|Code fix|
|---|----|:----:|:----:|:----:|
|[RCS1133](http://pihrt.net/roslynator/analyzer?id=RCS1133)|Remove redundant Dispose/Close call.|👻|✔️|✔️|

{{< /tab >}}
{{< tab tabNum="3" >}}
CodeCracker

https://code-cracker.github.io/diagnostics.html

|Code|Title|Severity|Is enabled|Code fix|
|---|----|:----:|:----:|:----:|
|[CC0022](https://code-cracker.github.io/diagnostics/CC0022.html)|Should dispose object|⚠️|✔️|✔️|
|[CC0029](https://code-cracker.github.io/diagnostics/CC0029.html)|Disposables Should Call Suppress Finalize|⚠️|✔️|✔️|
|[CC0033](https://code-cracker.github.io/diagnostics/CC0033.html)|Dispose Fields Properly|⚠️|✔️|✔️|
|[CC0032](https://code-cracker.github.io/diagnostics/CC0032.html)|Dispose Fields Properly|ℹ️|✔️|✔️|

{{< /tab >}}
{{< tab tabNum="4" >}}
Disposable Fixer
https://github.com/BADF00D/DisposableFixer
https://marketplace.visualstudio.com/items?itemName=DavidStormer.DisposableFixer2019


|Code|Title|Severity|Is enabled|Code fix|
|---|----|:----:|:----:|:----:|
|DF0000|Marks undisposed anonymous objects from object creations.|⚠️|✔️|✔️|
|DF0001|Marks undisposed anonymous objects from method invocations.|⚠️|✔️|✔️|
|DF0010|Marks undisposed local variables.|⚠️|✔️|✔️|
|DF0020|Marks undisposed objects assinged to a field, originated in an object creation.|⚠️|✔️|✔️|
|DF0022|Marks undisposed objects assinged to a property, originated in an object creation.|⚠️|✔️|✔️|
|DF0021|Marks undisposed objects assinged to a field, originated from method invocation.|⚠️|✔️|✔️|
|DF0023|Marks undisposed objects assinged to a property, originated from a method invocation.|⚠️|✔️|✔️|
|DF0024|Marks undisposed objects assinged to a field, originated in an object creation.|⚠️|✔️|❌|
|DF0026|Marks undisposed objects assinged to a property, originated in an object creation.|⚠️|✔️|❌|
|DF0025|Marks undisposed objects assinged to a field, originated from method invocation.|⚠️|✔️|❌|
|DF0027|Marks undisposed objects assinged to a property, originated from a method invocation.|⚠️|✔️|❌|
|DF0030|Marks undisposed objects assinged to a field, originated in an object creation.|⚠️|✔️|❌|
|DF0032|Marks undisposed objects assinged to a property, originated in an object creation.|⚠️|✔️|❌|
|DF0031|Marks undisposed objects assinged to a field, originated from method invocation.|⚠️|✔️|❌|
|DF0033|Marks undisposed objects assinged to a property, originated from a method invocation.|⚠️|✔️|❌|
|DF0034|Marks undisposed objects assinged to a field, originated in an object creation.|⚠️|✔️|❌|
|DF0036|Marks undisposed objects assinged to a property, originated in an object creation.|⚠️|✔️|❌|
|DF0035|Marks undisposed objects assinged to a field, originated from method invocation.|⚠️|✔️|❌|
|DF0037|Marks undisposed objects assinged to a property, originated from a method invocation.|⚠️|✔️|❌|
|DF0028|Marks undisposed factory properties.|⚠️|✔️|❌|
|DF0029|Marks undisposed static factory properties.|⚠️|✔️|❌|
|DF0100|Marks return values that hides the IDisposable implementation of return value.|⚠️|✔️|❌|
|DF0110|Marks an Dispose implementation that is not in use.|⚠️|✔️|❌|

{{< /tab >}}
{{< tab tabNum="5" >}}

https://www.nuget.org/packages/SonarAnalyzer.CSharp/

|Code|Title|Severity|Is enabled|Code fix|
|---|----|:----:|:----:|:----:|
|[S3966](https://rules.sonarsource.com/csharp/RSPEC-3966)|Objects should not be disposed more than once|⚠️|✔️|❌|
|[S2931](https://rules.sonarsource.com/csharp/RSPEC-2931)|Classes with "IDisposable" members should implement "IDisposable"|⚠️|❌|❌|
|[S2930](https://rules.sonarsource.com/csharp/RSPEC-2930)|"IDisposables" should be disposed|⚠️|✔️|❌|
|[S2997](https://rules.sonarsource.com/csharp/RSPEC-2997)|"IDisposables" created in a "using" statement should not be returned|⚠️|✔️|❌|
|[S4002](https://rules.sonarsource.com/csharp/RSPEC-4002)|Disposable types should declare finalizers|⚠️|❌|❌|
|[S2952](https://rules.sonarsource.com/csharp/RSPEC-2952)|Classes should "Dispose" of members from the classes' own "Dispose" methods|⚠️|❌|❌|
|[S2953](https://rules.sonarsource.com/csharp/RSPEC-2953)|Methods named "Dispose" should implement "IDisposable.Dispose"|⚠️|✔️|❌|
|[S3881](https://rules.sonarsource.com/csharp/RSPEC-3881)|"IDisposable" should be implemented correctly|⚠️|✔️|❌|
{{< /tab >}}
{{< /tabs >}}