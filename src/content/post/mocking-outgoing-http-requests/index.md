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

## Troubleshooting

In case of unmatched requests you can do the following 
- investigate with debugger `wiremock.Mappings` to see currently defined stubs and `wiremock.LogEntries` to check all requests received by `WireMock` server.

Sometimes it's easier to open in webbrowser `http://localhost:1080/__admin/requests` url to get detailed info about all requests received by wiremock.

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

Find your unmatched request, take the `PartialMappingGuid` and open `http://localhost:1080/__admin/mappings/{PartialMappingGuid}`.
Comparing request data with mapping you should be able to quickly figure out what is wrong with your stub. Take a look at `Score` attribute in `MatchDetails`. All items with Score set to 9 are the culprits.
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