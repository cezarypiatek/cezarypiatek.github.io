---
title: "Common Setup and Teardown in dotnet tests without test framework magic"
description: "Practical Tips for solving the challenges of WireMockServer instance re-usage"
date: 2024-01-02T00:10:45+02:00
tags : ["aspcore", "dotnet",  "testing"]
highlight: true
highlightLang: ["cs"]
image: "splashscreen.png"
isBlogpost: true
---


In this blog post I describe the typical problems cause by the usage of `Setup` and `Teardown` method in dotnet tests and how those problems can be solved by using only C# language features.

<!--more--> 

## Typical test development lifecycle

A typical developer writes some tests. Being a conscientious developer who values clean code principles, he refactors these tests, extracting the duplicated code responsible for preparing and cleaning up test fixtures into separate methods intended for SetUp and TearDown. These methods are implicitly run by the test framework before and after each test. Another developer adds a few more tests and, noticing that all code responsible for preparing and cleaning data is placed in the SetUp and TearDown methods, also refactors the newly added tests, moving the appropriate parts of those tests to the SetUp and TearDown methods. Subsequently, another developer follows suit.

## The problem
The work pattern described above leads to the following problems:

1. The SetUp and TearDown methods tend to become overly complex. Over time, it becomes challenging to discern which parts of these methods correspond to specific test cases. This issue presents not only a maintenance challenge but can also lead to performance problems as the cumulative setup and cleanup operations for all tests are executed for each individual test.
2. Understanding the test scenario becomes more difficult as it requires jumping back and forth between the actual test code and the SetUp and TearDown methods. Sometimes it's not even obvious that such methods exist, especially when somebody goes even further end extract those methods to base class and starts using test class inheritance.
3. As the test cases method needs to access objects prepared by SetUp method, the test class starts being polluted with extra members. It can negatively contribute to test readability.
4. If the teardown method fails, the test case is still marked as success. This might hide issues with your test suite for a long time.

These observations are not a new discovery. Some of those problems were described by James Newkirk (co-author of Nunit) in one of his blog posts in 2007 https://jamesnewkirk.typepad.com/posts/2007/09/why-you-should-.html Despite that was 17 years ago, people continue to adopt these problematic patterns. This might be due to the fact that James highlighted the problem but he didn't offer a solution.

## The Solution

I solve this issue by taking the leverage of `IDiposable` types. This is very simple to implement, and thanks to `using declaration syntax` introduced in C# 8, it's very neat in application:


```cs
public class TestCaseFixture : IDisposable
{
    public TestCaseFixture()
    {
        // TODO: Setup code goes here
    }

    public void Dispose()
    {
        // TODO: Teardown code goes here
    }
}
```

Sample usage looks as follows:

```cs

public class Tests
{
    [Test]
    public void should_do_something()
    {
        using var fixture = new TestCaseFixture();
        
        // TODO: Here goes the test case scenario        
    }
}    

```

To make sure that test case fixture is correctly used - always disposed - you can set [CA2000](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca2000) rule to error in your `.editorconfig` file. Thanks to that, the build will always fail if somebody forget to add `using` keyword.

```
# CA2000: Dispose objects before losing scope
dotnet_diagnostic.CA2000.severity = error
```

You might wonder about segregating the fixture code for a specific group of tests. There are several options available. You can create a dedicated test case fixture type for a particular group of tests, or you can employ the factory or builder pattern (or a combination of both) to create a specialized instance of the test fixture that will suit the needs of a given test scenario. With the latter approach, you can minimize code duplication without compromising performance.


```cs
public class TestCaseFixtureBuilder
{
    //TODO: Add methods for customizing TestCaseFixture definition

    public TestCaseFixture Build() => new();
}

public static class TestCaseFixtureFactory
{
    public static TestCaseFixture CreateFixture(Action<TestCaseFixtureBuilder>? adjust = null)
    {
        var instance = new TestCaseFixtureBuilder();
        adjust?.Invoke(instance);
        return instance.Build();
    }
}
```

Sample usage 


```cs
using static TestCaseFixtureFactory;

public class Tests
{
    [Test]
    public void should_do_something()
    {
        using var fixture = CreateFixture(builder =>
        {
            // TODO: call builder's methods to customize your fixture
        });
        
        // TODO: Here goes the test case scenario        
    }
}    
```


Here are some benefits off applying this approach to dealing with Setup and Teardown:

1. As the whole code is explicitly called, is much easier to comprehend test case logic.
2. Setup and teardown codes are part of test case execution so it's easier to detect any issues and it's much easier to maintain and assess test performance.
3. It's much easier to create more versatile and reusable test fixture that can be parametrized. As the setup code is called explicitly, it's much easier to pass parameters that will adjust fixture to a given test case needs.
4. TestCaseFixture type can serve as a container for a resources that need to be share between Setup and Teardown logic as well as for those elements that will be needed to access from the test case. Thanks to that, test fixture's elements are easy to discover and they are access in a explicit way.
5. Test fixtures can be reused between test classes without the need for inheritance.
6. This method is independent of the test framework. It can be employed with NUnit, xUnit, or any framework of your choice.

I have been successfully using this method for many years, keeping test maintenance without excessive effort. 

