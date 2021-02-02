---
title: "Testing WebAPI using ApprovalTests"
description: "How to create maintainable tests for WebApi with minimal amount of work."
date: 2021-01-30T00:08:00+02:00
tags : ["dotnet", "csharp", "WebAPI", "ApprovalTest", "testing"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---

Thanks to [Microsoft.AspNetCore.TestHost](https://www.nuget.org/packages/Microsoft.AspNetCore.TestHost/) package, setting up our application with `WebApi` in tests is super easy:

```cs
using var applicationFactory = new WebApplicationFactory<Program>();
var httpClient = applicationFactory.CreateClient();
```


However this form has some limitations. It doesn't allow for mocking components used by our application - I guess you don't want to run tests against the real infrastructure, at least locally.
Additionally there's a bug in the `WebApplicationFactory` implementation and by default hosted services are not stopped while calling `Dispose` - this might result in unexpected behaviors if your app is using Hosted services. Another thing is that after you create httpClient with `CreateClient` method, you still can't be sure if the app is fully initialize and ready to operate. We can deal with all those problems by creating a custom class that inherits from `WebApplicationFactory<Program>`:

```cs
class WeatherApplicationFactory: WebApplicationFactory<Program>, IAsyncDisposable
{
    private IHost? _host;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(collection =>
        {
            //TODO: Register mocked connectors for external services
        });
    }

    public Task Install()
    {
        //TODO: Call healthcheck/ready endpoint until it returns 200 with a given timeout
    }

    protected override IHost CreateHost(IHostBuilder builder)
    {
        _host = base.CreateHost(builder);
        return _host;
    }

    public async ValueTask DisposeAsync()
    {
        if (_host != null)
        {
            await _host.StopAsync();
        }
        base.Dispose();
    }
}
```

Now we can use that class as follows:

```cs
await using var applicationFactory = new WeatherApplicationFactory();
var httpClient = applicationFactory.CreateClient();
```

## What to mock

Create strongly typed client or use the auto-generated one [Auto generated WebAPI client library with NSwag](/post/auto-generated-web-api-client/)

Tests that operates on the Web API level falls into the category that lays between `unit tests` and `integration tests` - I call them `component tests`. Those kinds of tests should verify your application in isolation from the external dependencies. Those external dependencies can be dived into two categories: 
- infrastructure - example: database, message broker, distributed caches, metrics stores, etc.
- other services - example: other business components integrated via Rest API, Soap or GRPC.

In terms of the first category - the less we mock the higher level of confidence about the correctness of our service we can get. Of course, settings up infrastructure dedicated for unit tests session might be quite expensive and time consuming but it's doable. It's worth to consider a hybrid option when we use mocks while running test locally on the dev machine and setup a real infra using for example some docker orchestrator like `docker-compose` or `Kubernetes` for testing during the `CI` builds. Based on my experience I would recommend to avoid mocking database access layer (repositories or whatever you call it). Just use LocalDB, docker container image with your database, or at least in-memory version if such option is available. This will save you a lot of troubles and gives you even a higher level of confidence.


## Do not HttpClient directly

1. Create test host - watch out on the Hosted services stop
    - mock only the infrastructure
    - do not mock any component that orchestrate the infrastructure (do not mock repositories)
2. Create (Test) API client
    - Never use HttpClient directly in your test cases
    - Create strongly typed client
    - Use auto-generated client
3. Create wrapper around the API client to simplify the test-case scenario script
4. HttpAssert for checking the response code 
    - provide a meaningful and broad explanation why the expected code is different (show the request and actual response)
5. Use ApprovalTests for response verification
  -  define reporters
  - auto-approval
  - add `.receive` files and (`*.bak`) to `.gitignore`
6. Make the output deterministic
    - Ignore certain paths (Timestamps, Id, etc)
    - define ignore jsonPaths
7. Verify the minimal subset that gives the expected amount of confidence
   - define jsonpaths to verify
9. This approach makes test cases totally separated from the implementation details or even technology.
10. Keep application settings and test settings separately

    