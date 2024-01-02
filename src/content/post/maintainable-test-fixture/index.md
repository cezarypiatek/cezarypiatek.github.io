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

## Typical test development lifecycle

A typical developer writes some tests. And because he's a good dev and he cares about clean code rules, he refactor those tests and extract duplicated code responsible for preparing and cleaning up test fixtures to SetUp and TearDown. Those methods that are run implicitly by test framework before and after each tests. Another developer add few more tests and he see that all code responsible for preparing and cleaning data is put in the SetUp and TearDown methods so he also refactor newly added tests and moves appropiate parts of those tests to SetUp and TearDown methods. Yet another developer follows the same path. 

## The problem
This leads to the following problems:

1. SetUp and TearDown methods become a dumpster fire. After a while it's impossible to tell which parts of those methods serve to which tests cases. It's not only a maintenance problem but it could also lead to performance issues as the sum of setup and cleanup for all tests will be run for each test.
2. It's harder to understand test scenario without jumping between the actual test code and SetUp and TearDown methods. Sometimes it's not even obvious that such methods exist, especially when somebody goes even further end extract those methods to base class and starts using test class inheritance. Having multiple levels of test class inheritance with a SetUp and TearDown is a real hell.
3. As the test cases method needs to access objects prepared by SetUp method, the test class starts beeing polluted with extra members. It can negatively contribute to test readability.
4. If the teardown method fails, the test case is still marked as success. This might hide issues with your test suite for a long time.

Those observations are not a novel discovery. Some of those problems were described by James Newkirk (co-author of Nunit) in one of his blog posts in 2007 https://jamesnewkirk.typepad.com/posts/2007/09/why-you-should-.html It was 17 years ago and people are still practice those patterns. This might be due to the fact that James pointed out the problem but he didn't show a solution.

## The Solution

I solve this problem by taking the leverage of `IDiposable` types. This is very simple to implement and thanks to `using declaration syntax` introduced in C# 8 it's very neat in application:


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

You might ask what about splitting the fixture code for specific group of tests. We have a several options here. You can create a dedicated test case fixture type for a given group of tests or you can apply factory or builder pattern to create a specialized instance of tests fixture that will serve the purpose of a given test scenario. With the second approach you can reduce code duplication without risking performance degradation. 


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


I've been using this approach for many years with success keeping test maintenance without excessive effort. 


Benefits:
1. As the whole code is explicitly called, is much easier to comprehend test case logic.
2. Setup and teardown codes are part of test case execution so it's easier to detect any issues and it's much easier to maintain and assess test performance.
3. It's much easier to create more versatile and reusable test fixture that can be parametrized. As the setup code is called explicitly, it's much easier to pass parameters that will adjust fixture to a given test case needs.
4. This approach is test framework independent. You can use it with NUnit, xUnit or whatever you like.


