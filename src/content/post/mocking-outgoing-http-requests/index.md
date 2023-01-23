---
title: "Mocking outgoing http requests in ASP.NET Core tests"
description: "How to replace services in DI container with mocks in tests using WebApplicationFactory."
date: 2023-01-21T00:21:45+02:00
tags : ["testing", "mocks", "aspcore", "dotnet", "wiremock"]
highlight: true
highlightLang: ["cs", "json"]
image: "splashscreen.jpg"
isBlogpost: true
---

In my previous blog post, I discussed the use of dependency injection (DI) containers for mocking dependencies in tests for ASP.NET Core applications. While this approach is useful in some cases, I personally prefer a different approach that operates outside of the process and works directly with the actual protocol. In this post, I will be introducing WireMock.NET, a powerful tool for mocking HTTP requests in tests. Unlike the DI container approach, WireMock.NET allows for more accurate and complete testing of HTTP communication. Additionally, it eliminates the need for complicated hacks and workarounds when trying to mock HTTP requests. This post will provide a comprehensive guide on how to use WireMock.NET in your ASP.NET Core tests to effectively mock HTTP requests.


## What is the WireMock.NET?

[WireMock.NET](https://github.com/WireMock-Net/WireMock.Net) is a .NET version of [WireMock](https://wiremock.org/), a library for stubbing and mocking web services. It allows you to simulate the behavior of a real HTTP server in your tests, without the need for a real service to be running. You can use WireMock.NET to define the responses that should be returned for specific requests, and it will intercept and handle those requests for you. This makes it easy to test your code that makes HTTP requests, without having to rely on the actual external service being available.

## Getting started

To get started, you need to install `WireMock.Net` as the nuget package. After installing, you can start using WireMock.NET by creating an instance of the WireMockServer class, configuring it with the desired behavior, and starting it. Once the server is running, you can make your HTTP requests as normal and WireMock.NET will intercept and handle them based on your configuration.

```cs
[Test]
public async Task sample_wiremock_usage()
{
  //INFO: Setup WireMock.Net server
  using var wiremock = WireMockServer.StartWithAdminInterface(port: 1080, ssl: false);
  
  //INFO: Setup WebApplicationFactory
  await using var appFactory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
  {
    builder.ConfigureAppConfiguration(configurationBuilder =>
    {
      //INFO: Override downstream service addresses pointing to WireMock address
      configurationBuilder.AddInMemoryCollection(new Dictionary<string, string>
      {
        ["ExternalServices:Github"] = "http://localhost:1080/GithubService/"
      });
    });
  });

  //INFO: Stub outgoing request
  wiremock
    .Given(
      Request.Create()
        .WithPath("/GithubService/repos/cezarypiatek/MappingGeneratorReleases/releases/latest")
        .UsingGet()
    )
    .RespondWith(
      Response.Create()
        .WithStatusCode(200)
        .WithHeader("Content-Type", "application/json; charset=utf-8")
        .WithBodyAsJson(new
        {
          tag_name = "2023.1.52"
        })
    );
}
```

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
      "Url": "http://localhost:1080/GithubService/repos/cezarypiatek/MappingGeneratorReleases/releases/latest",
      "AbsoluteUrl": "http://localhost:1080/GithubService/repos/cezarypiatek/MappingGeneratorReleases/releases/latest",
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
          "HttpRequestsSample"
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

## Best practices


## Other features

WireMock.NET offers a variety of features beyond basic stubbing and mocking of HTTP requests. One such feature is the ability to [proxy requests](https://github.com/WireMock-Net/WireMock.Net/wiki/Proxying) to a real service using WireMock and capture the responses in the form of mappings. This enables you to easily capture responses from a real service and use them as the basis for your stubs, eliminating the need for manual response definition.

WireMock.NET also enables you to read mappings and stub definitions from [static files](https://github.com/WireMock-Net/WireMock.Net/wiki/Mapping#static-mappings). This allows for easy storage and management of your stubs in a separate file, rather than having to define them programmatically. This can be useful for sharing stubs across different tests or projects.

In addition to this, WireMock.NET also allows for the creation of dynamic [response templates](https://github.com/WireMock-Net/WireMock.Net/wiki/Response-Templating) that include data from the request. This allows you to create responses that vary based on the details of the request, which can be useful for testing edge cases or simulating the behavior of a real service.

Another powerful feature of WireMock.NET is the ability to simulate service behavior with [Scenarios and States](https://github.com/WireMock-Net/WireMock.Net/wiki/Scenarios-and-States). This allows you to test different scenarios and edge cases by simulating different states of a service and switching between them. This can be useful for testing how your code handles different types of failures or responses from a service.

## The rest ....

Beside preparing stubs directly in your code you have also option to
- provide static mappings in external json file
- proxy request to a real service via WireMock and snapshot it in the form of mappings 


- load predefined mocks from file
- record requests in proxy mode
- setup wiremock server
- override app config
- add prefix to identify downstream service 
- create mapping
- dispose mapping
- create stub object to simplify stubbing request to given downstream service
- debugging:
  - fetch a list of requests received by wiremock
  - get id of a partially matched mapping
  - fetch details of a given mapping
  - compare expectations with received request

- API (WithMapping() method) is quite verbose, gives a lot of flexibility how we can define expected request and response. If your Rest API is designed in a consistent way, you will probably need only a subset of this possibilities. To reduce repeatable code, it's good to encode most common scenario with helper extension methods. I created a own mapping model that simplify stub definitions:
