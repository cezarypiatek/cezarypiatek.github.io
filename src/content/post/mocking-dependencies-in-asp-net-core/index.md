---
title: "Mocking dependencies in ASP.NET Core tests"
description: "How to replace services in DI container with mocks in tests using WebApplicationFactory."
date: 2023-01-06T00:21:45+02:00
tags : ["testing", "mocks", "aspcore", "dotnet", "dotnetcore"]
highlight: true
highlightLang: ["cs"]
image: "splashscreen.jpg"
isBlogpost: true
---


As I recently spent some time writing and refactoring tests that utilize WebApplicationFactory, I've come to have some thoughts and ideas for improvement that I'd like to share. In this article, I'll delve into the process of mocking dependencies in a DI container when using WebApplicationFactory, and offer some insights and best practices I've learned along the way. Whether you're a seasoned pro or new to unit testing ASP.NET Core applications, I hope this information will be helpful as you work to simplify and streamline your tests.


## Getting started

Testing an ASP.NET Core application can be a complex task, especially when it comes to mocking dependencies in a DI container. Fortunately, the `WebApplicationFactory` class provided by the [Microsoft.AspNetCore.Mvc.Testing](https://www.nuget.org/packages/Microsoft.AspNetCore.Mvc.Testing) nuget package offers a convenient way to simplify the process of setting up and tearing down a test server for integration tests.

Here's a minimal setup that you need to host your web app for the testing purpose:

```cs
[Test]
public async Task should_do_something_v1()
{
    // arrange
    await using var appFactory = new WebApplicationFactory<Program>();
    var client = appFactory.CreateClient();

    // act
    // assert
}
```

However, using `WebApplicationFactory` in this way doesn't allow for replacing any dependencies in `DI Container`. We can overcome that by creating a class that inherits from `WebApplicationFactory` and overrides `ConfigureWebHost`. By using a simple trick with `Action<IServiceCollection>` lambda accepted by the constructor, we can make it reusable:

```cs
public class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    private readonly Action<IServiceCollection>? _overrideDependencies;

    public CustomWebApplicationFactory(Action<IServiceCollection>? overrideDependencies = null)
    {
        _overrideDependencies = overrideDependencies;
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services => _overrideDependencies?.Invoke(services));
    }
}
```

With our `CustomWebApplicationFactory` we can easily prepare the app setup with mocked dependencies as follows:

```cs
[Test]
public async Task should_do_something_v2()
{
    // arrange
    await using var appFactory = new CustomWebApplicationFactory(services =>
    {
        // Mock IXDataProvider
        services.Replace(ServiceDescriptor.Scoped(_ =>
        {
            var providerMock = new Mock<IXDataProvider>();
            providerMock.Setup(x => x.GetData()).Returns(new XData { Attr1 = "Val1", Attr2 = "Val2"});
            return providerMock.Object;
        }));

        // Mock IYDataRepository
        services.Replace(ServiceDescriptor.Scoped(_ =>
        {
            var repositoryMock = new Mock<IYDataRepository>();
            var entity = new YDataEntity { Id = 1, Name = "Some Name" };
            repositoryMock.Setup(x => x.Get(entity.Id)).Returns(entity);
            return repositoryMock.Object;
        }));
    });

    var client = appFactory.CreateClient();

    // act
    // assert
}
```

To create a mocked implementations I used [Moq](https://www.nuget.org/packages/Moq) library.

As you can see, our `CustomWebApplicationFactory` allows for replacing services in DI container quite easily, but there are a few things that I don't like here:
- There is a certain amount of code that you need to always repeat for every mocked service. It degrades test code readability and distracts our attention from what's really important here. 
- We need to know the original component lifecycle, which smells like an information leak. The component lifecycle is not important from the test case perspective, so it should't be visible here.

## Improving test setup readability

We can try to improve the readability and simplify the test setup code with this extension method:

```cs
public static class MockExtensions
{
    public static void Mock<TService>(this IServiceCollection @this, Action<Mock<TService>> customize) where TService : class
    {
        var serviceType = typeof(TService);
        if (@this.FirstOrDefault(x => x.ServiceType == serviceType) is { } existingServiceDescriptor)
        {
            @this.Replace(new ServiceDescriptor(serviceType, _ =>
            {
                var mock = new Mock<TService>();
                customize(mock);
                return mock.Object;
            }, existingServiceDescriptor.Lifetime));
            return;
        }

        throw new InvalidOperationException($"'{serviceType}' was not registered in DI Container");
    }
}
```
Now our test looks a little leaner:

```cs
[Test]
public async Task should_do_something_v3()
{
    // arrange
    await using var appFactory = new CustomWebApplicationFactory(services =>
    {
        services.Mock<IXDataProvider>(mock =>
        {
            mock.Setup(x => x.GetData()).Returns(new XData { Attr1 = "Val1", Attr2 = "Val2" });
        });

        services.Mock<IYDataRepository>(mock =>
        {
            var entity = new YDataEntity { Id = 1, Name = "Some Name"};
            mock.Setup(x => x.Get(entity.Id)).Returns(entity);
        });
    });

    var client = appFactory.CreateClient();
    
    // act
    // assert
}
```

This is definitively progress in the right direction, but there's still one problem that might affect test maintainability.
Mocking explicitly specific interfaces in our test case code makes test tightly coupled to the implementation details. This is not good because every time we refactor application code (without changing its behavior), we will be forced to adjust test code to the new implementation. A good example for that could be when we decide that the repository pattern doesn't play well with our architecture and we want to replace with a different solution. This could turn our internal structure upside down. Ideally, after every refactoring, we would like to run existing test suit (without changing it) to verify that the expected behavior was preserved. The same problem could appear when the data source changes - for example our app will need to load given entities from the new GRPC service instead of from the old database. Changing `IYDataRepository` to `ISampleGrpcService` will require changing the code of all test cases that mock `IYDataRepository` interface.

We can try to limit the scope of changes by abstracting the code responsible for mocking specific interfaces. This can be done with test data builder approach:

```cs
public class TestDataBuilder
{
    private XData? _xData;

    public void WithXData(string attr1, string attr2) 
        => this._xData = new XData {Attr1 = attr1, Attr2 = attr2};

    private readonly List<YDataEntity> _sampleEntities = new();

    public void WithYData(int id, string name) 
        => _sampleEntities.Add(new YDataEntity { Id = id, Name = name});

    public void Build(IServiceCollection serviceCollection)
    {
        if (_xData != null)
        {
            serviceCollection.Mock<IXDataProvider>(mock =>
            {
                mock.Setup(x => x.GetData()).Returns(_xData);
            });
        }

        if (_sampleEntities.Count > 0)
        {
            serviceCollection.Mock<IYDataRepository>(mock =>
            {
                foreach (var entity in _sampleEntities)
                {
                    mock.Setup(x => x.Get(entity.Id)).Returns(entity);
                }
            });
        }
    }
}
```

> Ideally, the data builder methods should not use the internal structures of the application as parameters. Instead, they should use custom data structures that only include the attributes that are important for the test case. You can create a custom data structure for this purpose or list the necessary attributes as parameters for the builder method. The builder method should be responsible for converting the custom data structure into the internal structures of the application. If there are any changes to the internal structures of the application, you will only need to adjust the builder methods. The test case code will not be affected.


To use the new approach with data builder, we need to modify our `CustomWebApplicationFactory` to accept as constructor parameter a lambda that customizes the `TestDataBuilder` instead of `IServiceCollection`:

```cs
public class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    private readonly Action<TestDataBuilder>? _setupTestData;

    public CustomWebApplicationFactory(Action<TestDataBuilder>? setupTestData = null)
    {
        _setupTestData = setupTestData;
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            if (_setupTestData != null)
            {
                var dataBuilder = new TestDataBuilder();
                _setupTestData(dataBuilder);
                dataBuilder.Build(services);
            }
        });
    }
}
```

Using the new version of `TestDataBuilder`, we can prepare test data in a very concise, readable, and maintainable way as follows:

```cs
[Test]
public async Task should_do_something_v4()
{
    // arrange
    await using var appFactory = new CustomWebApplicationFactory(builder =>
    {
        builder.WithXData(attr1: "Val1", attr2: "Val2");
        builder.WithYData(id: 1, name: "Some Name");
    });

    var client = appFactory.CreateClient();
   
    // act
    // assert
}
```


## Summary

In this blog post, I examined the use of WebApplicationFactory and Moq to mock dependencies in a DI container for automated tests. By utilizing the extension methods to eliminate repetitive code and the builder pattern to abstract mocking logic, I was able to increase the readability and maintainability of our tests. 

I'd love to hear about your experience with mocking dependencies in a DI container when testing ASP.NET Core applications. Do you use a similar approach or have you discovered alternative solutions that work well for you? 