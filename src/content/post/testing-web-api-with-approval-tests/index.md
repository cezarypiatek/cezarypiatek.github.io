---
title: "Testing WebAPI with ApprovalTests.NET"
description: "How to create maintainable tests for WebApi with minimal amount of work."
date: 2021-03-16T00:08:00+02:00
tags : ["dotnet", "csharp", "WebAPI", "ApprovalTest", "testing"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---

In this blog post I'm going to share my experience on testing `ASP.NET Core` applications with applying unconventional method called `snapshot assertions`. In comparison to the classical approach this method should save you a lot of time and improve assertions maintainability. <!--more--> 
## Setting up tests with TestHost

Thanks to [Microsoft.AspNetCore.TestHost](https://www.nuget.org/packages/Microsoft.AspNetCore.TestHost/) package, setting up our `WebApi` application in tests is super easy:

```cs
using var applicationFactory = new WebApplicationFactory<Program>();
var httpClient = applicationFactory.CreateClient();
```

However, this form has some limitations. It doesn't allow for mocking components used by our application - I guess you don't want to run tests against the real infrastructure, at least not when it happens in local development environment. Additionally, there's a bug in the `WebApplicationFactory` implementation and by default hosted services are not stopped while calling `Dispose` - this might result in unexpected behaviors if your app is using them. Another thing is that after you create HttpClient instance with `CreateClient` method, you still can't be sure if the app is fully initialized and ready to operate. We can deal with all those problems by creating a custom class that inherits from `WebApplicationFactory<Program>`:

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

Now we can create a sample test as follows:

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

To simplify things related to serialization and deserialization request payloads, I used [Microsoft.AspNet.WebApi.Client](https://www.nuget.org/packages/Microsoft.AspNet.WebApi.Client/) NuGet package. This package contains helper extension methods like `PostAsJsonAsync` and `ReadAsAsync`.

## What's wrong with the classical assertions?

No matter which one of the classical assertion libraries (`NUnit`, `xUnit`, `FluentAssertions`, `Shouldly`) we use for writing code responsible for verifying our expectations, it's always a very tedious job. The amount of work is directly proportional to the richness of the returned object. It might be very time-consuming and it could divert our attention from more important things. Very often we end up with a huge assertion block which degrades the readability of our test cases and is hard to maintain. With this classical approach, it's also hard to track additive changes in API. When we add a new field to the API, we need to remember about adding appropriate assertions for that field in all test cases where it's needed.


## Snapshot assertions to the rescue
All those problems can be solved with `snapshot assertions`. The main idea behind this approach is to automatically capture a snapshot of the expected state and use it for later verifications. The snapshot is stored in a separate file alongside the source code and should be kept in the version control system. In `dotnet` we have a few libraries that facilitate this kind of testing: 

- [ApprovalTests.Net](https://github.com/approvals/approvaltests.net)
- [Verify](https://github.com/VerifyTests/Verify)
- [Snapshooter](https://github.com/SwissLife-OSS/snapshooter), 
- [Snapper](https://github.com/theramis/Snapper),
- [Polaroider](https://github.com/WickedFlame/Polaroider) 

`ApprovalTests.Net` was the first library from this area that I came across and since then I have used it in a few projects with success. `Approvals` project seems to be quite mature and popular as it provides implementations for a variety of programming languages (Java, C#, C++, PHP, Python, Swift, JavaScript, Perl, Go, Lua, Objective C, and Ruby). Please visit the official website [https://approvaltests.com/](https://approvaltests.com/) for more details.

## Using `ApprovalTests.Net`

So how does it work? Before we start using `ApprovalTests.Net` we need to configure it by adding appropriate attributes on a test class or assembly level. To avoid repetition I always add `ApprovalTestsSettings.cs` file to the test project with the following content:

```cs
[assembly:UseReporter(typeof(NUnitReporter), typeof(DiffReporter))]
```

Now, `ApprovalTests.Net` is ready to use. In order to write snapshot assertion we need to call `Approvals.VerifyJson` with a response payload that we want to verify:

```cs
// STEP 3: Fetch newly created user
var getUserResponsePayload = await apiClient.GetStringAsync("/user/" + createResult.Id);


// STEP 4: Verify the expectations
Approvals.VerifyJson(getUserResponsePayload);
```

After the first test run, `ApprovalTests.Net` creates two files:

- `TestClassName.test_method_name.received.json`- contains the asserted payload
- `TestClassName.test_method_name.approved.json`- empty file

and executes the default git merge tool comparing those two files. Now it's our turn, we need to verify manually if the payload is ok and approve it. __This is a very important step and we should review the content carefully with appropriate attention - blindly approved snapshots are a recipe for disaster.__ The merging tool should copy content from the `*.received.json` to `*.approved.json`. After that our snapshot is ready and we can delete `*.received.json` file as it's no longer needed. With the next test runs, `ApprovalTests.Net` will compare received payload with the one saved in the `*.approved.json` file, and if it detects any difference a git merge tool should be executed to present the difference in a readable way and give us an opportunity to adjust the snapshot when the change was expected.

The snapshot files (`*.approved.json` ) should be added to version control and the temporal files with currently received payload (`*.received.json`) should be added to the ignored files list.

## Which git merge tool to run

If we configure `ApprovalTests.Net` to use `DiffReporter` then, when it's needed, the library will try to use the first available git merge tool and do it in the following order:

- BeyondCompare,
- P4Merge,
- AraxisMerge,
- Meld,
- SublimeMerge,
- Kaleidoscope,
- CodeCompare,
- DeltaWalker,
- WinMerge,
- DiffMerge,
- TortoiseMerge,
- TortoiseGitMerge,
- TortoiseIDiff,
- KDiff3,
- TkDiff,
- Guiffy,
- ExamDiff,
- Diffinity,
- VisualStudio,
- VisualStudioCode,
- Rider,
- Vim,
- Neovim

This order can be overridden by defining `DiffEngine_ToolOrder` environment variable or we can explicitly specify reporter implementation that should be used. For example, when we have a few git merge tools installed, we can enforce usage of the specific one as follows:

```cs
[assembly:UseReporter(typeof(NUnitReporter), typeof(WinMergeReporter))]
```



## Non deterministic snapshots

Sometimes we are not able to create a deterministic snapshot because some of the attributes are changing with every API call like ids or dates. We need to somehow exclude them from the comparison. I do that by obfuscating the values of those attributes with a constant string `__IGNORED_VALUE__` with the following helper method:

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


## Massive snapshot update

Sometimes we need to make a change in API that affects a lot of existing snapshots. This happens when we add a new field, remove an existing one, change the logic of calculating something, change data format or we are just fixing the bug. When we run the whole test suite after this kind of change, the `ApprovalTests.Net` will open a git merge tool for every snapshot that should be changed which is quite inconvenient. For this kind of situation, I use a different strategy. I change the `ApprovalTests.Net` configuration to use [auto-approver](https://stackoverflow.com/a/37604286/876060), letting it override all affected snapshot with current data and review it before committing it to the repository. I use [GitFork](https://git-fork.com/) for that purpose, which makes things quite easy. I keep the `auto-approver` implementation with the required configuration as a git patch and apply it when I need it.


## Multiple assertions in a single test case

`ApprovalTests.Net` automatically creates snapshot file names based on the tested class and method names. This is some sort of limitation because we can't call `Approvals.VerifyJson` multiple times in the same test method, as every consecutive invocation will override the same snapshot files causing incorrect behavior. To overcome that limitation, there's a dedicated method `ApprovalResults.ForScenario` that allows defining sub-scenario scopes within a single test case. 

```cs
[Test]
public async Task should_fetch_newly_created_user()
{
    using (ApprovalResults.ForScenario("First User"))
    {
        // Create new users
        var createResponse = await apiClient.PostAsJsonAsync("/user/", new CreateUserDTO
        {
            FirstName = "John",
            LastName = "Doe",
            Email = "john.doe@gmail.com"
        });

        var createResult = await createResponse.Content.ReadAsAsync<EntityCreatedResult>();

        // Fetch newly created user
        var getUserResponsePayload = await apiClient.GetStringAsync("/user/" + createResult.Id);

        // Verify the expectations
        Approvals.VerifyJson(getUserResponsePayload.WithIgnores("$.id"));
    }

    using (ApprovalResults.ForScenario("Second User"))
    {
        // Create new users
        var createResponse = await apiClient.PostAsJsonAsync("/user/", new CreateUserDTO
        {
            FirstName = "Jane",
            LastName = "Doe",
            Email = "john.doe@gmail.com"
        });

        var createResult = await createResponse.Content.ReadAsAsync<EntityCreatedResult>();

        // Fetch newly created user
        var getUserResponsePayload = await apiClient.GetStringAsync("/user/" + createResult.Id);

        // Verify the expectations
        Approvals.VerifyJson(getUserResponsePayload.WithIgnores("$.id"));
    }

    using (ApprovalResults.ForScenario("All users"))
    {   
        // Fetch all users
        var getAllUsersResponsePayload = await apiClient.GetStringAsync("/user/");

        // Verify the expectations
        Approvals.VerifyJson(getAllUsersResponsePayload.WithIgnores("$[*].id"));
    }
}
```

The text passed to `ApprovalResults.ForScenario` becomes part of the snapshot file name. `Approvals.VerifyJson` stops the assertion which means when the assertion is not met then the test case is marked as failed and stopped immediately. This behavior combined with the usage of `ApprovalResults.ForScenario` has the following implications:

- In order to create initial snapshots for all scenarios within the test case we need to run it as many times as we have scenarios. When a given assertion is reached, the test fails because there is no approved snapshot yet and we need to do the approval. After each approval, the operation needs to be repeated until we approve snapshots for all scenarios.

- If there is an intended change in the application behavior that results in the need to adjust the existing snapshot, we have a similar problem as with initial snapshot creation. To adjust snapshots for all scenarios we need to run our test case as many times as the number of scenarios.

Running the same test case for every scenario once again is a quite tedious task. I solve this problem with [auto-approver](https://stackoverflow.com/a/37604286/876060).

## Summary

A sample WebAPI project with tests presented in this article is available on Github [SampleWebApiTestsWithApprovals](https://github.com/cezarypiatek/SampleWebApiTestsWithApprovals).