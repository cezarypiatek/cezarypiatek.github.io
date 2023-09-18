---
title: "Sharing WireMock in sequential and parallel tests"
description: "Practical Tips for solving the challenges of WireMock instance re-usage"
date: 2023-09-18T00:10:45+02:00
tags : ["aspcore", "dotnet", "wiremock", "testing","parallel"]
highlight: true
highlightLang: ["cs"]
image: "splashscreen.jpg"
isBlogpost: true
---


As .NET developers, we understand the significance of writing automated tests to ensure our applications function correctly. However, as our applications grow more complex and diverse, optimizing the test process becomes crucial. One effective approach is reusing components like tested application and Wiremock instances between test cases. While this optimization can improve test efficiency, it can also introduce challenges of ensuring that different test cases do not interfere with each other. In this blog post, we'll delve into the biggest problems related to WireMock instance re-usage and explore a potential solution.

## Reusing components' instances

To re-use tested application and WireMock instances between tests, we can create a class that holds those instances and manages their lifecycle. I like to call it `GlobalTestFixture`. A sample implementation can look as follows:

```cs
public class GlobalTestFixture: IAsyncDisposable
{
    private WebApplicationFactory<Program>? _myService;
    public WebApplicationFactory<Program> MyService => 
            _myService ?? throw new InvalidOperationException("Fixture not initializer");

    private WireMockServer? _wireMockServer;
    public WireMockServer WireMockServer => 
            _wireMockServer ?? throw new InvalidOperationException("Fixture not initializer");

    public void Initialize()
    {
        _wireMockServer = WireMockServer.StartWithAdminInterface();
        _myService = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder => {
                builder.ConfigureAppConfiguration(configurationBuilder =>
                {
                    //INFO: Override downstream service addresses pointing to WireMock address
                    configurationBuilder.AddInMemoryCollection(new Dictionary<string, string>
                    {
                        ["ExternalServices:WeatherService"] = _wireMockServer.Url
                    });
                }
             );
        });
        //INFO: This enforces app setup
        _ = _myService.CreateClient();
    }

    public async ValueTask DisposeAsync()
    {
        _wireMockServer?.Dispose();
        if(_myService!= null)
            await _myService.DisposeAsync();
    }
}
```

The code responsible for creating `WireMockServer` and `WebApplicationFactory` was put in a dedicated instance method instead of the constructor to handle disposal of those components correctly. With this approach, for example if WebApplicationFactory creation fails, the WireMockServer instance will still be disposed correctly. This won't be possible if we put all that code in the constructor.

Now we need to ensure that the `Initialize` method will be invoked only once per test suit. We can achieve that manually by adding some sort of locking, or we can use mechanisms provided by our test frameworks. For example, while working with NUnit we can use [[SetUpFixture]](https://docs.nunit.org/articles/nunit/writing-tests/attributes/setupfixture.html) for that:


```cs
using NUnit.Framework;

// INFO: This class should be under main namespace or without namespace to run the setup and teardown only once for all tests
[SetUpFixture]
public class AllTestSetup
{
    public static GlobalTestFixture GlobalFixture { get; private set; }
    
    [OneTimeSetUp]
    public async Task GlobalSetup()
    {
        GlobalFixture = new GlobalTestFixture();
        GlobalFixture.Initialize();
    }

    [OneTimeTearDown]
    public async Task GlobalTeardown()
    {
        if (GlobalFixture != null)
        {
            await GlobalFixture.DisposeAsync();
        }
    }
}
```

A sample test case can look as follows:

```cs
using NUnit.Framework;
using static AllTestSetup;

public class Tests
{
    [Test]
    public async Task sample_test()
    {
        // Arrange
        var myServiceClient = GlobalFixture.MyService.CreateClient();

        GlobalFixture.WireMockServer.Given(
                Request.Create()
                    .UsingGet()
                    .WithPath("/WeatherService/api/v1.0/weather")
                    .WithParam("lat", "10.99")
                    .WithParam("long", "10.99")
            )
            .RespondWith(Response.Create()
                .WithStatusCode(200)
                .WithHeader("Content-Type", "application/json; charset=utf-8")
                .WithBodyAsJson(new
                {
                    temp = 298.48,
                    pressure = 1015,
                    humidity = 64
                }));
        
        // Act
        var response = await myServiceClient.GetAsync("WeatherForecast/GetWeatherForecast");
        
        // Assert
        //TODO: assert the response
    }
}
```

## Sharing WireMock in sequential tests

When multiple tests share the same WireMock instance, it accumulates mappings from all test cases executed before. This becomes problematic when tests involve scenarios where the tested application makes similar requests to an external service but expects different responses. The mappings created in previous test cases might interfere, leading to a non-deterministic test suite where test outcomes depend on the execution order.

One approach to mitigate this issue is to use the `ResetMappings()` method before each test to clear all mappings. However, this solution has a drawback: it removes all mappings, including any global mappings that should be shared among all test cases. While it's possible to recreate these global mappings after every ResetMappings() call, it can impact test execution time. Alternatively, you can track all mappings created within a test and remove them individually using the `DeleteMapping()` method at the end of each test case. This approach allows you to preserve the necessary global mappings while ensuring the test suite remains deterministic. However, it requires careful tracking and management of mappings within each test.


## Sharing WireMock in parallel tests

In parallel execution, simply removing all mappings before each test is not feasible because it can adversely affect other concurrently running tests. Tracking mappings within each test falls short either, as mappings added by one test could still temporarily collide with mappings from other tests. Sharing WireMock in parallel test execution requires a different approach compared to sequential testing. 


To solve this problem, you need a way to ensure that WireMock mappings, created within a given test case, match only those requests made by tested application within the same test case. So there's a need for a mechanism that allows for correlating together requests made from test to app, with requests made from the app to external dependency, with WireMock mapping within a given test. Such mechanism can be implemented based on HTTP headers. Here's a high-level overview of the solution:

1. Generate a unique identifier at the beginning of each test case. 

2. Include this identifier as a custom HTTP header in every request sent to the tested application.

3. Extend your WireMock mappings with an assertion for this custom header with a value of unique identifier generated for this test case.

4. Modify tested application to relay this custom header from the incoming request to all outgoing requests. This can be implemented for example with custom RequestHandler.


The last point requires us to modify the tested app only for the testing purpose. I don't like to add this kind of things as it always imposes an additional risk. A mechanism that should never be included in the app can affect the performance or stability, event if it seems to be very simple. Luckily, we don't need to add such mechanism as it's already built into the AspNetCore. It turns out that HttpClient contains [DiagnosticHandler](https://github.com/dotnet/runtime/blob/release/5.0/src/libraries/System.Net.Http/src/System/Net/Http/DiagnosticsHandler.cs#L286) which by default relays `traceparent` header from incoming to outgoing requests. The `traceparent` header is a part of OpenTelemetry standard and it's used for correlating requests between services - just what we need here.

A sample test that leverages `traceparent` can look as follows:

```cs
using static AllTestSetup;

public class Tests
{
    [Test]
    public async Task sample_parallel_test()
    {
        //Arrange
        // 1. Create Activity, to generate unique and correct value for traceparent
        using var activity = new Activity("TestCase").Start();
        var myServiceClient = GlobalFixture.MyService.CreateClient();
        
        // 2. Add traceparent header to all requests made from test scenario
        myServiceClient.DefaultRequestHeaders.Add("traceparent", activity.Id);

        GlobalFixture.WireMockServer.Given(
                Request.Create()
                    .UsingGet()
                    // 3. Add condition for traceparent header in WireMock mapping
                    .WithHeader("traceparent", $"*{activity.TraceId}*")
                    .WithPath("/WeatherService/api/v1.0/weather")
                    .WithParam("lat", "10.99")
                    .WithParam("long", "10.99")
            )
            .RespondWith(Response.Create()
                .WithStatusCode(200)
                .WithHeader("Content-Type", "application/json; charset=utf-8")
                .WithBodyAsJson(new
                {
                    temp = 298.48,
                    pressure = 1015,
                    humidity = 64
                }));
        
        // Act
        var response = await myServiceClient.GetAsync("WeatherForecast/GetWeatherForecast");
        
        // Assert
        //TODO: assert the response
    }
}
```

> Trace parent is always in the format: `{Version}-{Activity.TraceId}-{Activity.SpanId}-{Options}`. Only `Activity.TraceId` will be the same for all requests within single test, so I used `*{activity.TraceId}*` wildcard pattern to correctly match outgoing requests.


Steps 1,2 and 3 need to be repeated in every test case. To avoid repetitive code and ensure that traceparent is handled correctly in all test cases we can introduce test case fixture to manage that test's contextual data.

```cs
public class TestCaseFixture : IAsyncDisposable
{
    private readonly Activity _activity;
    private readonly WireMockServer _wireMockServer;
    public HttpClient MyServiceClient { get; }

    public TestCaseFixture(WireMockServer wireMockServer, WebApplicationFactory<Program> myService, string testCaseName)
    {
        _wireMockServer = wireMockServer;
        _activity = new Activity("TestCase").AddTag("TestMethod", testCaseName).Start();
        MyServiceClient = myService.CreateClient();
        MyServiceClient.DefaultRequestHeaders.Add("traceparent", _activity.Id);
    }

    public void MockExternalRequest(Action<IRequestBuilder> adjustRequest, Action<IResponseBuilder> adjustResponse)
    {
        var requestBuilder = Request.Create()
            .WithHeader("traceparent", $"*{_activity.TraceId}*");
        adjustRequest(requestBuilder);
        var responseBuilder = Response.Create();
        adjustResponse(responseBuilder);
        _wireMockServer.Given(requestBuilder).RespondWith(responseBuilder);
    }

    public ValueTask DisposeAsync()
    {
        _activity.Dispose();
        return default;
    }
}
```


Global fixture can be extended with factory method for test case fixture:

```cs
public class GlobalTestFixture: IAsyncDisposable
{
    public TestCaseFixture CreateTestCaseFixture([CallerMemberName] string testCaseName = "")
    {
        return new TestCaseFixture(WireMockServer, MyService, testCaseName);
    }
}
```

Having TestCaseFixture, we can refactor test cases to the following form:

```cs
public class Tests
{
    [Test]
    public async Task sample_parallel_test()
    {
        await using var fixture = AllTestSetup.GlobalFixture.CreateTestCaseFixture();

        fixture.MockExternalRequest
        (
            adjustRequest: builder => builder.UsingGet()
                .WithPath("/WeatherService/api/v1.0/weather")
                .WithParam("lat", "10.99")
                .WithParam("lon", "44.34"),
            
            adjustResponse: builder => builder.WithStatusCode(200)
                .WithHeader("Content-Type", "application/json; charset=utf-8")
                .WithBodyAsJson(new
                {
                    temp = 298.48,
                    pressure = 1015,
                    humidity = 64
                })
        );

        var response = await fixture.MyServiceClient.GetAsync("WeatherForecast/GetWeatherForecast");
        //TOD: assert the response
    }
}
```

Using `traceparent` for correlating requests not only solves the problem of re-using WireMock in sequential and parallel test execution, but also opens a possibility to visualize the flow of our test cases with tools like [Jeager](https://www.jaegertracing.io/).