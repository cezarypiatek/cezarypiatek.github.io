---
title: "Non-nullable references with C# 8 and .NET Core 3.0"
description: "How to catch NullReferenceException in design time"
date: 2019-10-03T00:20:45+02:00
tags : ["dotnetcore", "c#", "visual studio"]
highlight: true

image: "splashscreen.jpg"
isBlogpost: true
---

Two weeks ago .NET Core 3.0 was officially published. Together with the new version of the framework, Visual Studio got a support for a long awaited C# 8.0. The complete list of the new language feature is available [here](https://docs.microsoft.com/en-US/dotnet/csharp/whats-new/csharp-8) on the MSDN but the one that deserves a special attention is [Nullable reference types](https://docs.microsoft.com/en-US/dotnet/csharp/whats-new/csharp-8#nullable-reference-types). This is very important change in the language semantic because from now we will be able to eliminated a certain class of errors related reference `nullability` on the compilation stage. In this blog post I will show you how to use this new language feature and how to achieve similar benefits if you still cannot use .NET Core 3.0 in your projects.


## How to use Non-nullable references

If our project is targeting .NET Core 3.0 or higher we can start using non-nullable references. However, when we add `?` annotation to the reference type we get the following warning: 

> `CS8632: The annotation for nullable reference types should only be used in code within a '#nullable' annotations context.`

Our code will compile but all the rules related to the non-nullable references will be ignored (our code will be interpreted as it was before C# 8). Because this feature is a breaking change in the language it should be explicitly enabled. To test it in a single file add `#nullable enable` directive. In order to enable it for the whole project add `<Nullable>enable</Nullable>` to your csproj definition.  If you are serious about using non-nullable references I would recommended enabling it for the whole solution by adding `Directory.Build.props` file in the root directory of your source code with the content as follows:

```
<Project>
 <PropertyGroup>
    <Nullable>enable</Nullable>
    <RunAnalyzersDuringBuild>true</RunAnalyzersDuringBuild>
    <RunAnalyzersDuringLiveAnalysis>true</RunAnalyzersDuringLiveAnalysis>
 </PropertyGroup>
</Project>
```

Since now all the references to the reference types are treated as `non-nullable` unless they are explicitly marked as nullable with `?` annotation. These new rules are verified by the Roslyn analyzers from `Microsoft.CodeAnalysis.CSharp` package (which is added implicitly to all C# projects). There is over a 40 rules related to the `nullability` and the complete list is presented below:


## The era before C# 8 
|Code|Title|
|---|----|
|CS8073|The result of the expression is always the same since a value of this type is never equal to 'null'|
|CS8597|Thrown value may be null.|
|CS8600|Converting null literal or possible null value to non-nullable type.|
|CS8601|Possible null reference assignment.|
|CS8602|Dereference of a possibly null reference.|
|CS8603|Possible null reference return.|
|CS8604|Possible null reference argument.|
|CS8605|Unboxing a possibly null value.|
|CS8606|Possible null reference assignment to iteration variable|
|CS8607|A possible null value may not be passed to a target marked with the [DisallowNull] attribute|
|CS8608|Nullability of reference types in type doesn't match overridden member.|
|CS8609|Nullability of reference types in return type doesn't match overridden member.|
|CS8610|Nullability of reference types in type of parameter doesn't match overridden member.|
|CS8611|Nullability of reference types in type of parameter doesn't match partial method declaration.|
|CS8612|Nullability of reference types in type doesn't match implicitly implemented member.|
|CS8613|Nullability of reference types in return type doesn't match implicitly implemented member.|
|CS8614|Nullability of reference types in type of parameter doesn't match implicitly implemented member.|
|CS8615|Nullability of reference types in type doesn't match implemented member.|
|CS8616|Nullability of reference types in return type doesn't match implemented member.|
|CS8617|Nullability of reference types in type of parameter doesn't match implemented member.|
|CS8618|Non-nullable field is uninitialized. Consider declaring as nullable.|
|CS8619|Nullability of reference types in value doesn't match target type.|
|CS8620|Argument cannot be used for parameter due to differences in the nullability of reference types.|
|CS8621|Nullability of reference types in return type doesn't match the target delegate.|
|CS8622|Nullability of reference types in type of parameter doesn't match the target delegate.|
|CS8624|Argument cannot be used as an output for parameter due to differences in the nullability of reference types.|
|CS8625|Cannot convert null literal to non-nullable reference type.|
|CS8626|The 'as' operator may produce a null value for a type parameter.|
|CS8629|Nullable value type may be null.|
|CS8631|The type cannot be used as type parameter in the generic type or method. Nullability of type argument doesn't match constraint type.|
|CS8632|The annotation for nullable reference types should only be used in code within a '#nullable' annotations context.|
|CS8633|Nullability in constraints for type parameter doesn't match the constraints for type parameter in implicitly implemented interface method'.|
|CS8634|The type cannot be used as type parameter in the generic type or method. Nullability of type argument doesn't match 'class' constraint.|
|CS8638|Conditional access may produce a null value for a type parameter.|
|CS8643|Nullability of reference types in explicit interface specifier doesn't match interface implemented by the type.|
|CS8644|Type does not implement interface member. Nullability of reference types in interface implemented by the base type doesn't match.|
|CS8645|Interface is already listed in the interface list with different nullability of reference types.|
|CS8653|A default expression introduces a null value for a type parameter.|
|CS8654|A null literal introduces a null value for a type parameter.|
|CS8655|The switch expression does not handle some null inputs.|
|CS8667|Partial method declarations have inconsistent nullability in constraints for type parameter|
|CS8714|The type cannot be used as type parameter in the generic type or method. Nullability of type argument doesn't match 'notnull' constraint.|


By default all these rules are reported as `WARNING`, which means even if they are violated the code will compiled and worked. My advice is to go through this list carefully and increase the severity to `ERROR` level for the most of them. In order the the way these rules are interpreted you have to at first add `*.ruleset` file to your project.


I would recommend putting rules file side by side with the `Directory.Build.props` file and add the following entry:

```
 <CodeAnalysisRuleSet>MyRules.ruleset</CodeAnalysisRuleSet>
```