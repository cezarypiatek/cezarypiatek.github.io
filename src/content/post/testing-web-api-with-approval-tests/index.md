---
title: "Testing WebAPI using ApprovalTests"
description: "How to create maintainable tests for WebApi with minimal amount of work."
date: 2021-03-14T00:08:00+02:00
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
Additionally there's a bug in the `WebApplicationFactory` implementation and by default hosted services are not stopped while calling `Dispose` - this might result in unexpected behaviors if your app is using them. Another thing is that after you create httpClient with `CreateClient` method, you still can't be sure if the app is fully initialize and ready to operate. We can deal with all those problems by creating a custom class that inherits from `WebApplicationFactory<Program>`:

```cs
class SampleApplicationFactory : WebApplicationFactory<Program>, IAsyncDisposable
{
    private IHost? _host;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(collection =>
        {
            //TODO: Register mocked connectors for external services
        });
    }

    /// <summary>
    ///     This method ensures that tested application is fully initialized
    /// </summary>
    public async Task Install()
    {
        var client = this.CreateClient();
        var startupTimeout = TimeSpan.FromMilliseconds(2000);
        var stopWatch = new Stopwatch();
        stopWatch.Start();
        do
        {
            var response = await client.GetAsync("health/ready");
            if (response.IsSuccessStatusCode)
            {
                return;
            }
        } while (stopWatch.Elapsed < startupTimeout);

        throw new InvalidOperationException("Cannot initialize service within the expected timeout");
    }

    protected override IHost CreateHost(IHostBuilder builder)
    {
        // INFO: Intercept host object to stop Hosted Service during the Dispose
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

Now we can create sample test as follows:

```cs
[Test]
public async Task should_fetch_newly_created_user()
{
    // STEP 1: Setup SUT and connector for it
    var applicationFactory = new SampleApplicationFactory();
    await applicationFactory.Install();
    var apiClient = applicationFactory.CreateClient();

    // STEP 2: Create new users
    var createResponse = await apiClient.PostAsJsonAsync("/user/", new CreateUserDTO
    {
        FirstName = "John",
        LastName = "Doe",
        Email = "john.doe@gmail.com"
    });
    var createResult = await createResponse.Content.ReadAsAsync<EntityCreatedResult>();
    
    // STEP 3: Fetch newly created user
    var getUserResponse = await apiClient.GetAsync("/user/" + createResult.Id);
    var foundUser = await getUserResponse.Content.ReadAsAsync<UserDTO>();

    // STEP 4: Verify the expectations
    Assert.Multiple(() =>
    {
        Assert.AreEqual(createResult.Id, foundUser.Id, "User Id different than expected");
        Assert.AreEqual("John", foundUser.FirstName, "User FirstName different than expected");
        Assert.AreEqual("Doe", foundUser.LastName, "User LastName different than expected");
    });
}
```

To simplify things related to serialization and deserialization requests payloads I used [Microsoft.AspNet.WebApi.Client](https://www.nuget.org/packages/Microsoft.AspNet.WebApi.Client/) nuget package. This package contains helper extension methods like `PostAsJsonAsync` and `ReadAsAsync`.

## What's wrong with the Assertions?

No matter what kind of assertion library (`NUnit`, `xUnit`, `FluentAssertions`, `Shouldly`) we are using for writing a code responsible for verifying our expectations, it's very tedious job. The amount of work is directly proportional to the richness of the returned object. It might be very time consuming and it could divert our attention from more important things. Very often we end up with a huge assertion block which degrades the readability of our test cases and it's hard to maintain. With this classical approach it's also hard to track additive changes in API. When we add a new field to the API, we need to remember about adding appropriate assertions for that field in all test cases where it is needed.

## Snapshot assertions
All those problems can be solved with `snapshot assertions`. In `dotnet` we have a few libraries that facilitate this kind of testing: 

- [ApprovalTests.Net](https://github.com/approvals/approvaltests.net)
- [Verify](https://github.com/VerifyTests/Verify)
- [Snapshooter](https://github.com/SwissLife-OSS/snapshooter), 
- [Snapper](https://github.com/theramis/Snapper),
- [Polaroider](https://github.com/WickedFlame/Polaroider) 

`ApprovalTests.Net` was the first library from this area that I came across and since then I used it in few projects with success. `Approvals` project seems to be quite mature and popular as it provides implementation for different programming languages. Please visit the official website [https://approvaltests.com/](https://approvaltests.com/) for more details.

So how does it work? Before we start using `ApprovalTests.Net` we need to configure it by adding appropriate attributes on test class or assembly level. In order to avoid repetition I always add `ApprovalTestsSettings.cs` file to the test project with the following content:

```
[assembly:UseReporter(typeof(NUnitReporter), typeof(DiffReporter))]
```

Now `ApprovalTests.Net` is ready to use. In order to write snapshot assertion we need to call `Approvals.VerifyJson` with a response payload that we want to verify:

```cs
// STEP 3: Fetch newly created user
var getUserResponsePayload = await apiClient.GetStringAsync("/user/" + createResult.Id);


// STEP 4: Verify the expectations
Approvals.VerifyJson(getUserResponsePayload);
```

After first test run, `ApprovalTests.Net` creates two files:

- `TestClassName.test_method_name.received.json`- contains the asserted payload
- `TestClassName.test_method_name.approved.json`- empty file

and executes default git merge tool comparing those two files. Now it's our turn, we need to verify manually if the payload is ok and approve it. __This is very important step and we should review the content carefully with appropriate attention - blindly approved snapshots are recipe for a disaster.__ The merging tool should copy content from the `*.received.json` to `*.approved.json`. After that our snapshot is ready and we can delete `*.received.json` file as it's no longer needed. With the next test runs, `ApprovalTests.Net` will compare receive payload with the one saved in the `*.approved.json` file, and if it detects any difference a git merge tool should be executed to present the difference in a readable way and give us opportunity to adjust the snapshot when the change was expected.

The snapshot files (`*.approved.json` ) should be added to version control and the temporal files with currently received payload (`*.received.json`) should be added to ignored files list.

## Which git merge tool to run

## Non deterministic snapshots

Sometimes we are not able to create a deterministic snapshot because some of the attributes are changing with every API call like ids or dates. We need to somehow exclude them from comparison. I do that by obfuscating the values of those attributes with a constant string `__IGNORED_VALUE__` with the following helper method:

```cs
public static class JsonExtensions
{
    public static string WithIgnores(this string jsonPayload, params string[] ignoredPaths)
    {
        var json = JToken.Parse(jsonPayload);
        foreach (var ignoredPath in ignoredPaths)
        {
            foreach (var token in json.SelectTokens(ignoredPath))
            {
                switch (token)
                {
                    case JValue jValue:
                        jValue.Value = "__IGNORED_VALUE__";
                        break;
                    case JArray jArray:
                        jArray.Clear();
                        jArray.Add("__IGNORED_VALUE__");
                        break;
                }
            }
        }

        return json.ToString(Formatting.None);
    }
}
```

Now we can easily exclude certain attributes before executing assertion:

```cs
// STEP 3: Fetch newly created user
var getUserResponsePayload = await apiClient.GetStringAsync("/user/" + createResult.Id);

// STEP 4: Verify the expectations
Approvals.VerifyJson(getUserResponsePayload.WithIgnores("$.id"));
```

For declaring ignored fields I'm using [JSONPath](https://github.com/json-path/JsonPath) notation. Here's my cheat sheet:

| Path | Meaning|
|-------|-------|
|$.X | Ignore attribute with X name |
|$.Y[*].X | Ignore attribute X for every element of Y collection |
| $.Y[*] | Ignore every element of Y collection by keeping the number of elements |
| $.Y | If Y is collection, then ignore every element as well as the number of elements |


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

    