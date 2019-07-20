---
title: "Effective mocking"
description: "Easily mocking with Roslyn help"
date: 2019-07-20T00:20:45+02:00
tags : ["roslyn", "testing", "productivity"]
highlight: true

image: "splashscreen.jpg"
isBlogpost: true
---

Recently, I've been asked if Roslyn can be used for helping with writing code that involve preparing mocks with `NSubstitute`. My answer of course was `"Yes"` but instead of rushing into creating a new project that will implement this functionality I performed a small research. I checked [nuget.org](https://nuget.org) and [Visual Studio extensions marketplace](https://marketplace.visualstudio.com) and I discovered that there is a bunch of existing analyzers and extensions that facilitate working with mocks and not only for `NSubstitute` but for other mocking frameworks just like `Moq` or `Fake It Easy` too.  In this blog post I will show you how these tools are helping to avoid common problems with mocking and boost your productivity by saving you a lof of typing. The examples will be mostly based on the `Moq` library because it's my favouring mocking package. 


## Moving runtime problems to design time
The idea behind mocking is to create in runtime a type that inherit from mocked type and behave in the way that we specify in mock configuration. The most common problem with mocking is that not everything related to mock preparation can be verify in design time and we need to compile and run our test to verify if the mock was constructed correctly. For example, from the semantical and syntactical point of view, it's possible to write code that create mock fo sealed class or for non-overridable method (sealed or non-abstract or non-virtual). However, when we run a test that use that mock we've got the exception.

//TODO: here comes the screenshot with this exception

With [Moq.Analyzers](https://www.nuget.org/packages/Moq.Analyzers/) we can detect that problem in design time, right in the moment when we type the code that create such invalid mock.

//TODO: here comes the screenshot with invalid code that is highlighted

Similar problem is with providing a expected behavior for mocked method because the signature of delegate provided for `Returns()` method must much the signature of mocked method. There is no way to express such kind of constrain with `C#` syntax so this code will compile but won't work:

//TODO: example of invalid

This verification can be shifted from runtime to design time thanks to roslyn analyzer:

//TODO: example of roslyn diagnostic



##  Less typing to create a mock
There is a lot of typing during creating mocks which is a dummy work. For example to mock a method with a three parameter (without carrying for their values) we need to write code like that:

```csharp
var mock = new Mock<ISampleInterface>();
mock.Setup(m => m.DoSomething(It.IsAny<int>(), It.IsAny<decimal>(), It.IsAny<string>()))
    .Returns((p1, p2, p3)=>  EXPECT_VALUE);
```

Typing repeatable `It.IsAny<>()` and trying to match the method signature in `Returns()` is quite boring and error prone. Happily this issue can be solved with visual studio extension that is able to propose and insert the whole code for us.

//TODO: insert the screenshot that presents this code substitution

If you need to return from the mock a sample object that has many properties that should be initialized with sample values you can use [MappingGenerator](https://github.com/cezarypiatek/MappingGenerator) that is able to scaffold object initialization.

//TODO: screenshot from object initialization



//TODO: add to every paragraph a link to tool for every mocking framework