---
title: "Exceptions usages analyzer"
description: "Detect violation of exceptions usages best practices"
date: 2019-04-27T00:09:00+02:00
tags : ["dotnet", "c#", "exceptions", "architecture", "cleancode"]
scripts: ["//cdnjs.cloudflare.com/ajax/libs/mermaid/8.0.0/mermaid.min.js"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---

Over a year ago I've written a blog post about [designing exceptions](/post/the-art-of-designing-exceptions/). I found this article very useful by myself and I used it as a reference few times during code review. However it's almost impossible to expect that anybody after reading recommended resource will start to apply described rules immediately and will remember about it all the time - it's a learning process and it will take some time. A while ago I got interested with Roslyn (I've even got a public presentation about it - [polish recording available here](https://www.youtube.com/watch?v=wi1XHpUhx1Y)) and there is a really cool thing about Roslyn analyzers that can solve this problem - they help to actively introduce best practices into your codebase. Besides detecting all violation of given rule, Roslyn analyzers are able to provide a detailed explanation why given code can be harmful. With analyzer can be associated a `CodeFix` which can automatically rewrite suspicious code into the proper one. By adding roslyn analyzers to your solution you are helping your team to gain knowledge about best practices as well as to avoid potential code quality issues they are not aware of - and all of that happen via the shortest feedback loop - just in time of writing code. There are a plenty of already implemented rules (mostly free and open-sourced) such as:

- [Roslynator](https://github.com/JosefPihrt/Roslynator)
- [Refactoring Essentials](http://vsrefactoringessentials.com/)
- [Code Cracker](http://code-cracker.github.io/) 
- [DotNetAnalyzers](https://github.com/DotNetAnalyzers) 

If there is no analyzer that meets your expectation you can always create your own. You can easily find many tutorials in web that teach how to start your journey as a analyzer creator. If you need a comprehensive introduction I'm highly recommending to read  [Roslyn Cookbook](https://www.amazon.com/gp/product/1787286835/ref=as_li_tl?ie=UTF8&tag=cezarypiatekg-20&camp=1789&creative=9325&linkCode=as2&creativeASIN=1787286835&linkId=eb7d6a30d8c770bbb5110e858f00ad97) by `Manish Vasani`
(I used this book for preparing my talk about roslyn analyzers and I'm also using this as a reference when I create my own analyzers.) In this article I want to describe my ideas and implementation of roslyn analyzers for detecting issues related to the exceptions usages.


## Overview

##  Be more specific
Use more specific exception class in throw statement
Do not use `Exception` and `ApplicationException` in throw statements.

##  Context is the king
Use exception constructor that accept context information object

## Parameters validation

`BCL` contains predefined exceptions intended for parameter's validation such as: `ArgumentException`, `ArgumentNullException` and `ArgumentOutOfRangeException`. Every of this exception types has a constructor tha accept a string representing the name of the parameter that violate the contract of our method. The mandatory of providing this parameter should be enforce by the [UseContextAwareConstructorAnalyzer](https://github.com/smartanalyzers/ExceptionAnalyzer/blob/master/src/ExceptionAnalyzer/ExceptionAnalyzer/Rules/UseContextAwareConstructor/UseContextAwareConstructorAnalyzer.cs), however it's important to provide valid parameter name. Even if we do so, our code could become easily outdated especially if we don't use `nameof()` expression. In order to prevent that I've created [ArgumentExceptionParameterNameAnalyzer](https://github.com/smartanalyzers/ExceptionAnalyzer/blob/master/src/ExceptionAnalyzer/ExceptionAnalyzer/Rules/ArgumentExceptionParameterName/ArgumentExceptionParameterNameAnalyzer.cs) which is responsible for verification if the value of the exception constructor's parameter with name `parameterName` match the name of any current method parameter.

## Original culprit

I come across many times on the code when somebody catch exception and from the `catch` clause throw a new one without supplying the original exception as the inner exception parameter. Re-throwing exception from the `catch` clause should be for providing more context information (example with validation and files) instead of hiding the original reason. Maybe some programmer are doing it purposely advocating it with security concerns but this aspect should be rather handled on the service boundary (errors are a part of contract). The original exception in the logs certainly helps you investigate the problem and find faster the reason of the failure. In order to detect this code smell I've created [ProvideInnerExceptionInCatchAnalyzer](https://github.com/smartanalyzers/ExceptionAnalyzer/blob/master/src/ExceptionAnalyzer/ExceptionAnalyzer/Rules/ProvideInnerExceptionInCatch/ProvideInnerExceptionInCatchAnalyzer.cs). This analyzer searches for all `throw` statements inside the `catch` clause which don't pass caught exception as a `inner exception` parameter for the new exception.

## Exception Driven Logic

What is the `Exception Driven Logic`? It's a kind of code where business flows are implemented using exceptions mechanism (`try-catch`) instead of condition statements (`if-else`). It can be easily identified because in the same method given exception is throw and catch, something like that:


```cs
try
{
	// do sth
	if(condition)
	{
	   throw new SpecificException();
	}
	// do sth
}
catch(SpecificException e)
{
	// do sth
}
```
This approach makes the code harder to analyze and has a huge impact on the performance. According to 
[Writing High-Performance .NET Code](https://www.amazon.com/gp/product/0990583457/ref=as_li_tl?ie=UTF8&tag=cezarypiatekg-20&camp=1789&creative=9325&linkCode=as2&creativeASIN=0990583457&linkId=fa07e52bebc6240c4c889eea6b23c76b) by Ben Watson it can be even XX times slower. Exceptions are for exceptional situation (when you don't know how to react for given conditions) and should not be used for well known business workflow. In order to prevent this kind of violation in code I've implemented [ExceptionDrivenLogicAnalyzer](https://github.com/smartanalyzers/ExceptionAnalyzer/blob/master/src/ExceptionAnalyzer/ExceptionAnalyzer/Rules/ExceptionDrivenLogic/ExceptionDrivenLogicAnalyzer.cs) which is able to spot places where the same exception is thrown and caught inside the code of same method.

## Summary
This is a first experimental implementation of analyzers so they might occur false positives. I will be appreciate if you will try it and let me know if it was able to spot a real problems in your code base or all that situation was a correct one.