---
title: "Mocking outgoing HTTP requests in ASP.NET Core tests"
description: "How to replace services in DI container with mocks in tests using WebApplicationFactory."
date: 2023-03-07T00:21:45+02:00
tags : ["testing", "mocks", "aspcore", "dotnet", "WireMock"]
highlight: true
highlightLang: ["cs", "json"]
image: "splashscreen.jpg"
isBlogpost: true
---

In my previous blog post, I discussed the use of dependency injection (DI) containers for mocking dependencies in tests for ASP.NET Core applications. While this approach is useful in some cases, I personally prefer a different approach - mocks/stubs/fakes that operates outside of the process and works directly with the actual protocol. 

In this post, I will introduce to you `WireMock.NET`, a powerful tool for mocking HTTP requests. Unlike the DI container approach, WireMock.NET allows for more accurate and complete testing of HTTP communication. Additionally, it eliminates the need for complicated hacks and workarounds when trying to mock HTTP requests. 

**From this article you will learn:**
- How to easily prepare mocks for HTTP endpoints with WireMock.
- How to troubleshoot most common problems. 
- How to improve readability and mailability of your test scenarios.
- How to avoid traps related to HTTP endpoint mocking.

## What is the WireMock.NET?

[WireMock.NET](https://github.com/WireMock-Net/WireMock.Net) is a .NET version of [WireMock](https://WireMock.org/), a library for stubbing and mocking HTTP services. With WireMock.NET, you can define the expected responses for particular requests, and the library will intercept and manage those requests for you. This allows easy to test code that makes HTTP requests, without having to rely on the actual external service being available and without hacking HttpClient.


## How to setup WireMock.NET?

To get started, you need to install [WireMock.Net](https://www.nuget.org/packages/WireMock.Net) nuget package first: 

```xml
<PackageReference Include="WireMock.Net" Version="1.5.17" />
```

After installing, you can start using `WireMock.NET` by creating an instance of the `WireMockServer` class, configuring it with the desired behavior, and starting it. This can be easily done by calling `WireMockServer.Start` or `WireMockServer.StartWithAdminInterface` method.

You need to also change mocked service address in your application config to point it to WireMock server address.

Now you can start defining mocks for the outgoing requests by using `WithMapping` method.

The minimal sample setup can look as follows:

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
        ["ExternalServices:WeatherService"] = "HTTP://localhost:1080/WeatherService"
      });
    });
  });

  //INFO: Stub outgoing request
  wireMock.WithMapping(new MappingModel
  {
      Request = new RequestModel
      {
          Methods = new[] { "GET" },
          Path = "/WeatherService/api/v1.0/weather?lat=10.99&lon=44.34"
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
}
```

You can alternatively use fluent syntax for defining mappings:

```cs
WireMock
  .Given(
      Request.Create()
          .WithPath("/WeatherService/api/v1.0/weather?lat=10.99&lon=44.34")
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

## Troubleshooting

One of the most common issues when working with WireMock.NET are incorrectly defined stubs. If you are receiving 404 code instead of the expected response, that indicates your stubs do not match the requests made by tbe tested app. To troubleshoot this issue, you can use the debugger to investigate requests that reached WireMock server by checking `WireMockServer.LogEntries` and comparing requests parameters with mappings defined in `WireMockServer.Mappings` objects. 

However, checking these objects with a debugger can be cumbersome. An alternative approach is to open the WireMock server's admin interface in a web browser by visiting [http://localhost:1080/__admin/requests](http://localhost:1080/__admin/requests). This will show you all the requests that have been received by WireMock. You should search for the `RequestMatchResult` section of a given request, and all elements from `MatchDetails` with a score below 1 could indicate a problem.

```json
[
  {
    "Guid": "dfab6ee2-1250-4c84-b9f3-b3ae3c83732e",
    "Request": {
      "ClientIP": "::1",
      "DateTime": "2023-01-22T17:22:20.9899245Z",
      "Path": "/GithubService/repos/cezarypiatek/MappingGeneratorReleases/releases/latest",
      "AbsolutePath": "/GithubService/repos/cezarypiatek/MappingGeneratorReleases/releases/latest",
      "Url": "HTTP://localhost:1080/GithubService/repos/cezarypiatek/MappingGeneratorReleases/releases/latest",
      "AbsoluteUrl": "HTTP://localhost:1080/GithubService/repos/cezarypiatek/MappingGeneratorReleases/releases/latest",
      "Query": {},
      "Method": "GET",
      "Headers": {
        "Accept": [
          "application/vnd.github.v3+json"
        ],
        "Host": [
          "localhost:1080"
        ],
        "User-Agent": [
          "HTTPRequestsSample"
        ],
        "traceparent": [
          "00-ec8a7a4a21eade4de75b183849f395c3-66391ac5260d57e6-00"
        ]
      },
      "Cookies": {}
    },
    "Response": {
      "StatusCode": 404,
      "Headers": {
        "Content-Type": [
          "application/json"
        ]
      },
      "BodyAsJson": {
        "Status": "No matching mapping found"
      },
      "DetectedBodyType": 2
    },
    "PartialMappingGuid": "12e03c70-6de2-4aa4-81c8-87ab4dab9cf3",
    "PartialRequestMatchResult": {
      "TotalScore": 1,
      "TotalNumber": 2,
      "IsPerfectMatch": false,
      "AverageTotalScore": 0.5,
      "MatchDetails": [
        {
          "Name": "PathMatcher",
          "Score": 0
        },
        {
          "Name": "MethodMatcher",
          "Score": 1
        }
      ]
    }
  }
]
```

Take the `PartialMappingGuid` and open `http://localhost:1080/__admin/mappings/{PartialMappingGuid}` to get details about the expected request shape. By comparing request data with mapping you should be able to quickly figure out what is wrong with your stub.

```json
{
  "Guid": "12e03c70-6de2-4aa4-81c8-87ab4dab9cf3",
  "UpdatedAt": "2023-01-22T17:22:16.9646198Z",
  "Request": {
    "Path": {
      "Matchers": [
        {
          "Name": "WildcardMatcher",
          "Pattern": "GithubService/repos/cezarypiatek/MappingGeneratorReleases/releases/latest",
          "IgnoreCase": false
        }
      ]
    },
    "Methods": [
      "GET"
    ]
  },
  "Response": {
    "StatusCode": 200,
    "BodyAsJson": {
      "tag_name": "2023.1.52"
    },
    "Headers": {
      "content-type": "application/json; charset=utf-8"
    }
  },
  "UseWebhooksFireAndForget": false
}
```

In order the use the WireMock Admin API, the WireMock server must be running. This is quite obvious fact, but it might be tricky during test session. We need to keep server alive a little longer thant the test duration. Setting breakpoint in the middle of test doesn't work because debugger freezes the whole process and we won't get any response from the Admin API. To handle this situation, I use a simple trick by putting `await Task.Delay(TimeSpan.FromMinutes(10));` in the place when I want to inspect WireMock Admin API.

## Best practices


### Avoiding endpoint addresses clash

When using WireMock it's important to ensure that there are no endpoint address clashes between multiple mocked servers. This might happen when tested application is using two different external dependencies with the same endpoint addressing. It might seem to be highly unlikely case, but believe me, it happens. When you hit the name clash, WireMock responses might not be what you expect and it might be very confusing. To avoid this issue, I recommend to suffix the mocked server address with the name of the service being mocked. The same name should be added as a prefix to every endpoint mapping.


```cs
const string WeatherServiceName = "WeatherService";

await using var appFactory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
{
  builder.ConfigureAppConfiguration(configurationBuilder =>
  {
    //INFO: Override downstream service addresses pointing to WireMock address
    configurationBuilder.AddInMemoryCollection(new Dictionary<string, string>
    {
      ["ExternalServices:WeatherService"] = $"http://localhost:1080/{WeatherServiceName}"
    });
  });
});

WireMock
  .Given(
      Request.Create()
          .WithPath($"/{WeatherServiceName}/api/v1.0/weather?lat=10.99&lon=44.34")
          .UsingGet()
  )
  .RespondWith(/*TODO*/);


```

When you start with a one service dependency, this might seems to be redundant but sooner or later you might hit the name clash. Applying this prefix-suffix trick from the very beginning might save you unnecessary debugging session.

### Dispose your mappings

WireMock instance can be re-used between tests to improve test execution performance. However, this approach can lead to mapping clashes, as each test may define different mappings for the same endpoints. This is a real trouble-maker as the WireMock's responses might very based on the test execution order. Test might pass when it's run in isolation and it might fail when it's run as a part of test suite because other test might add mapping for the same endpoint which better matching for current parameters. To ensure that mappings defined in a one test don't affect other tests, it's good to call the `Reset()` method before every test.  In this way, every test starts with a clean slate.

Another option is to create a disposable object that represents each mapping and deletes it in the `Dispose` method. This approach ensures that all mappings are deleted at the end of the test case, without the need for Setup/Teardown methods. It also allows for greater control over the scope of each mapping, which can be useful when testing different responses from the same endpoint within a single test case. 

```cs
public class RequestStub: IDisposable
{
    private readonly IWireMockServer _WireMock;
    private readonly Guid _stubId;

    public RequestStub(IWireMockServer WireMock, Guid stubId)
    {
        _WireMock = WireMock;
        _stubId = stubId;
    }

    public void Dispose() => _WireMock.DeleteMapping(_stubId);
}
```

Usage:

```cs
public RequestStub MockSomething()
{
    var stubId = Guid.NewGuid();
    _WireMock.WithMapping(new MappingModel
    {
        Guid = stubId,
        Request = /*TODO: Define request*/,
        Response = /*TODO: Define response*/
    });
    return new RequestStub(_WireMock, stubId);
}
```


### StubObjectPattern


Creating an endpoint mapping definition requires a couple lines of code. Even for a simple endpoint it might be at least 25 lines. Most of that code is related to endpoint parameters but it's not always important from the test case perspective. All that code for preparing stubs can quickly become complex and difficult to manage, degrading readability of our tests cases. 
My solution is to create an object that represents the stubbed service and provides methods for defining stubs for each operation consumed from that service. By wrapping the logic for creating stub definitions into meaningful methods, you can more easily understand the purpose of each stub and avoid errors or inconsistencies in your test code. 

```cs
public class WeatherServiceStub
{
    private const string ServicePrefix = "WeatherService";
    private readonly WireMockServer _WireMock;

    public WeatherServiceStub(WireMockServer WireMock)
    {
        _WireMock = WireMock;
    }

    public RequestStub MockCurrentWeather((double lat, double lon) location, Action<WeatherResponse> adjustResponse)
    {
        var mappingId = Guid.NewGuid();
        var expectedResponse = new WeatherResponse();
        adjustResponse(expectedResponse);

        _WireMock.WithMapping(new MappingModel
        {
            Guid = mappingId,
            Request = new RequestModel
            {
                Methods = new[] { "GET" },
                Path = $"{ServicePrefix}/api/v1.0/weather?lat={location.lat}&lon={location.lon}4"
            },
            Response = new ResponseModel
            {
                StatusCode = 200,
                Headers = new Dictionary<string, object>
                {
                    ["Content-Type"] = "application/json; charset=utf-8"
                },
                BodyAsJson = expectedResponse
            }
        });
        return new RequestStub(_WireMock, mappingId);
    }
}
```

Stub factory methods for specific endpoints accept a simplified form of request input parameters as well as a lambda function for overriding response default data. This approach allows for specifying in the test scenario only those attributes that are important from the test case perspective:

```cs
var weatherServiceStub = new WeatherServiceStub(WireMock);

using var currentWeatherMock = weatherServiceStub.MockCurrentWeather
(
  location: (10.99, 44.34), 
  response =>
  {
      response.temp = 298.48;
      response.feels_like = 298.74;
  }
);
```

**Benefits of using this approach:**

- It simplifies the process of defining and managing endpoint stubs. 
- It helps to avoid code duplication because those stub objects allow for reusing stub creation logic.
- It allows for writing more expressive and readable test scenarios. 


## Other features

WireMock.NET offers a variety of features beyond basic stubbing and mocking of HTTP requests. One such feature is the ability to [proxy requests](https://github.com/WireMock-Net/WireMock.Net/wiki/Proxying) to a real service and capture the responses in the form of mappings. You can use them as the basis for your stubs, eliminating the need for manual response definition.

WireMock.NET also enables you to read mappings and stub definitions from [static files](https://github.com/WireMock-Net/WireMock.Net/wiki/Mapping#static-mappings), rather than having to define them programmatically. This can be useful for sharing stubs across different tests or projects.

In addition to this, WireMock.NET also allows for the creation of dynamic [response templates](https://github.com/WireMock-Net/WireMock.Net/wiki/Response-Templating) that include data from the request. This allows you to create responses that vary based on the details of the request, which can be useful for testing edge cases or simulating the behavior of a real service.

Another powerful feature of WireMock.NET is the ability to simulate service behavior with [Scenarios and States](https://github.com/WireMock-Net/WireMock.Net/wiki/Scenarios-and-States). You can easily simulate different states of a service and switch between them. This can be useful for testing how your code handles different types of failures or responses from a service.


> To lear more about the possibilities of WireMock.NET I highly recommend a walkthrough the [WireMock Wiki page](https://github.com/WireMock-Net/WireMock.Net/wiki)