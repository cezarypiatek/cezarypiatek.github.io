---
title: "Common Setup and Teardown in dotnet tests without test framework magic"
description: "Practical Tips for handling test fixture in a maintainable way using only C# features."
date: 2024-01-06T00:10:45+02:00
tags : ["aspcore", "dotnet",  "testing"]
highlight: true
highlightLang: ["cs"]
image: "splashscreen.png"
isBlogpost: true
---


In this blog post I describe the typical problems caused by the usage of `Setup` and `Teardown` method in dotnet tests and how those problems can be solved by using only C# language features.

<!--more--> 

## Typical test development lifecycle

A typical developer writes some tests. Being a conscientious developer who values clean code principles, he refactors these tests, extracting the duplicated code responsible for preparing and cleaning up test fixtures into separate methods intended for SetUp and TearDown. These methods are implicitly run by the test framework before and after each test. Another developer adds a few more tests and, noticing that all code responsible for preparing and cleaning data is placed in the SetUp and TearDown methods, also refactors the newly added tests, moving the appropriate parts of those tests to the SetUp and TearDown methods. Subsequently, another developer follows suit.

## The problem
The work pattern described above leads to the following problems:

1. The SetUp and TearDown methods tend to become overly complex. Over time, it becomes challenging to discern which parts of these methods correspond to specific test cases. This issue presents not only a maintenance challenge but can also lead to performance problems as the cumulative setup and cleanup operations for all tests are executed for each individual test.
2. Understanding the test scenario becomes more difficult as it requires jumping back and forth between the actual test code and the SetUp and TearDown methods. Sometimes it's not even obvious that such methods exist, especially when somebody goes even further end extract those methods to base class and starts using test class inheritance.
3. As the test cases method needs to access objects prepared by SetUp method, the test class starts being polluted with extra members. It can negatively contribute to test readability.
4. If the teardown method fails, the test case is still marked as success. This might hide issues with your test suite for a long time.

These observations are not a novel discovery. Some of these problems were described by James Newkirk (co-author of Nunit) in one of his blog posts in 2007 https://jamesnewkirk.typepad.com/posts/2007/09/why-you-should-.html Despite this being 17 years ago, people continue to adopt these problematic patterns. This may be due to the fact that James suggested to keep the setup logic in the test methods, even at the cost of introducing code duplication. From what I have observed, developers are often discouraged from duplicating "similar" lines of code.

## The Solution

I solve this issue by taking the leverage of `IDiposable` types. The solution is very simple: just create a dedicated class that represents your test fixture. The constructor of this class takes the responsibilities of the Setup method and Dispose method implementation from `IDisposable` interface can act as a Teardown. When you create an instance of your test fixture with `using` syntax, the compiler ensures that `Dispose` method is automatically called at the end of your test method scope. Thanks to the `using declaration syntax` introduced in C# 8, it's very neat in application as we no longer need to create new code block for disposable scope:


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

To make sure that test case fixture is correctly used - always disposed - you can set [CA2000](https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/ca2000) rule to error in your `.editorconfig` file. Thanks to that, the build will always fail if somebody forgets to add `using` keyword.

```
# CA2000: Dispose objects before losing scope
dotnet_diagnostic.CA2000.severity = error
```

You might wonder about segregating the fixture code for a specific group of tests. There are several options available. You can create a dedicated test case fixture type for a particular group of tests, or you can employ the factory or builder pattern (or a combination of both) to create a specialized instance of the test fixture that will suit the needs of a given test scenario. With the latter approach, you can minimize code duplication without compromising other qualities of your test code.


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


Here are some of the benefits of applying this approach to managing Setup and Teardown:

1. The explicit invocation of setup and teardown codes as part of test case execution enhances understanding of the logic of each test case.
2. As setup and teardown codes are integral to the test case execution, it simplifies issue detection, maintenance, and performance assessment.
3. The approach allows for the creation of versatile and reusable test fixtures. Since setup code is explicitly called, it's straightforward to pass parameters that adapt the fixture to the specific needs of a given test case.
4. The TestCaseFixture type can serve as a container for resources needed both in Setup and Teardown logic and for elements accessed within the test case. This makes fixture elements easily discoverable and explicitly accessible.
5. Test fixtures can be reused between different test classes, eliminating the need for inheritance.
6. This method is independent of the test framework. It can be employed with NUnit, xUnit, or any other framework of your choice.

I have been successfully using this method for many years, keeping test maintainable without excessive effort. 



