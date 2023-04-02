---
title: "WireMock.NET - Introduction"
description: "Mocking outgoing HTTP requests in ASP.NET Core tests"
date: 2023-04-02T00:10:45+02:00
tags : ["testing", "mocks", "aspcore", "dotnet", "WireMock"]
highlight: true
highlightLang: ["cs", "json"]
image: "splashscreen.jpg"
isBlogpost: true
---

In my previous blog post, I discussed the use of dependency injection (DI) containers for mocking dependencies in tests for ASP.NET Core applications. While this approach is useful in some cases, I personally prefer using mocks/stubs/fakes that don't require any changes in the app internals and work directly with the actual protocol used by the application being tested. 

In this post, I will introduce to you `WireMock.NET`, a powerful tool for mocking HTTP requests. Unlike the DI container approach, WireMock.NET allows for more accurate and complete testing of HTTP communication. Additionally, it eliminates the need for complicated hacks and workarounds when trying to mock HTTP requests. 

## What is the WireMock.NET?

[WireMock.NET](https://github.com/WireMock-Net/WireMock.Net) is a .NET version of [WireMock](https://WireMock.org/), a library for stubbing and mocking HTTP services. With WireMock.NET, you can define the expected responses for particular requests, and the library will intercept and manage those requests for you. This allows for easy testing of the code that makes HTTP requests, without having to rely on the actual external service being available and without hacking HttpClient.


## How to setup WireMock.NET?

To get started, you need to install [WireMock.Net](https://www.nuget.org/packages/WireMock.Net) nuget package first: 

```xml
<PackageReference Include="WireMock.Net" Version="1.5.17" />
```

After installing, you can start using `WireMock.NET` by creating an instance of the `WireMockServer` class and configuring it with the desired behavior. This can be easily done by calling `WireMockServer.Start` or `WireMockServer.StartWithAdminInterface` method.

```cs
using var wireMock = WireMockServer.StartWithAdminInterface(port: 1080, ssl: false);
```

You need to also change mocked service address in your application config to point it to WireMock server address.

```cs
await using var appFactory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
{
  builder.ConfigureAppConfiguration(configurationBuilder =>
  {
    //INFO: Override downstream service addresses pointing to WireMock address
    configurationBuilder.AddInMemoryCollection(new Dictionary<string, string>
    {
      ["ExternalServices:WeatherService"] = "http://localhost:1080"
    });
  });
});
```

Now you can start defining mocks for the outgoing requests by using `WithMapping` method.

```cs
wireMock.WithMapping(new MappingModel
{
    Request = new RequestModel
    {
        Methods = new[] { "GET" },
        Path = "/api/v1.0/weather",
        Params = new List<ParamModel>
        {
            new ParamModel()
            {
                Name = "lat", 
                Matchers = new MatcherModel[] {new() {Name = "ExactMatcher", Pattern = "10.99"}}
            },
            new ParamModel()
            {
                Name = "lon", 
                Matchers = new MatcherModel[] {new() {Name = "ExactMatcher", Pattern = "44.34"}}
            }
        }
    },
    Response = new ResponseModel
    {
        StatusCode = 200,
        Headers = new Dictionary<string, object>
        {
            ["Content-Type"] = "application/json; charset=utf-8"
        },
        BodyAsJson = new
        {
            temp = 298.48,
            feels_like = 298.74,
            temp_min = 297.56,
            temp_max = 300.05,
            pressure = 1015,
            humidity = 64
        }
    }
});
```

Alternatively, you can use fluent syntax which seems to be more concise:

```cs
wireMock
    .Given(
        Request.Create()
            .WithPath("/api/v1.0/weather")
            .WithParam("lat", "10.99")
            .WithParam("lon", "44.34")
            .UsingGet()
    )
    .RespondWith(
        Response.Create()
            .WithStatusCode(200)
            .WithHeader("Content-Type", "application/json; charset=utf-8")
            .WithBodyAsJson(new
            {
                temp = 298.48,
                feels_like = 298.74,
                temp_min = 297.56,
                temp_max = 300.05,
                pressure = 1015,
                humidity = 64
            })
    );
```
Once the server is running, you can make your HTTP requests as normal and WireMock.NET will intercept and handle them based on your configuration.

The complete minimal sample setup can look as follows:

```cs
[Test]
public async Task sample_WireMock_usage()
{
  //INFO: Setup WireMock.Net server
  using var wireMock = WireMockServer.StartWithAdminInterface(port: 1080, ssl: false);
  
  //INFO: Setup WebApplicationFactory
  await using var appFactory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
  {
    builder.ConfigureAppConfiguration(configurationBuilder =>
    {
      //INFO: Override downstream service addresses pointing to WireMock address
      configurationBuilder.AddInMemoryCollection(new Dictionary<string, string>
      {
        ["ExternalServices:WeatherService"] = "http://localhost:1080"
      });
    });
  });

  //INFO: Prepare stub for outgoing request
  wireMock
    .Given(
        Request.Create()
            .WithPath("/api/v1.0/weather")
            .WithParam("lat", "10.99")
            .WithParam("lon", "44.34")
            .UsingGet()
    )
    .RespondWith(
        Response.Create()
            .WithStatusCode(200)
            .WithHeader("Content-Type", "application/json; charset=utf-8")
            .WithBodyAsJson(new
            {
                temp = 298.48,
                feels_like = 298.74,
                temp_min = 297.56,
                temp_max = 300.05,
                pressure = 1015,
                humidity = 64
            })
    );

    //INFO: Automate tested app
}
```

## Other features

WireMock.NET offers a variety of features beyond basic stubbing and mocking of HTTP requests. One such feature is the ability to [proxy requests](https://github.com/WireMock-Net/WireMock.Net/wiki/Proxying) to a real service and capture the responses in the form of mappings. You can use them as a basis for your stubs, eliminating the need for manual response definition.

WireMock.NET also enables you to read mappings and stub definitions from [static files](https://github.com/WireMock-Net/WireMock.Net/wiki/Mapping#static-mappings), rather than having to define them programmatically. This can be useful for sharing stubs across different tests or projects.

In addition to this, WireMock.NET also allows for the creation of dynamic [response templates](https://github.com/WireMock-Net/WireMock.Net/wiki/Response-Templating) that include data from the request. This allows you to create responses that vary based on the details of the request, which can be useful for testing edge cases or simulating the behavior of a real service.

Another powerful feature of WireMock.NET is the ability to simulate service behavior with [Scenarios and States](https://github.com/WireMock-Net/WireMock.Net/wiki/Scenarios-and-States). You can easily simulate different states of a service and switch between them. This can be useful for testing how your code handles different types of failures or responses from a service.


> To learn more about the possibilities of WireMock.NET, I highly recommend reading the [WireMock Wiki page](https://github.com/WireMock-Net/WireMock.Net/wiki)