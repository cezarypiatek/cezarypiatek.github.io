---
title: "Mocking GraphqQL queries with WireMock.NET"
description: "Mocking outgoing HTTP requests in ASP.NET Core tests"
date: 2024-01-14T00:10:45+02:00
tags : ["testing", "mocks", "aspcore", "dotnet", "WireMock"]
highlight: true
highlightLang: ["cs", "json"]
image: "splashscreen.jpg"
isBlogpost: true
---


GraphQL is a query language for APIs that allows clients to request exactly what they need, making data retrieval more efficient than traditional REST APIs. It supports three different types of client-server interaction: queries, mutations and subscriptions. When you start integrating a GraphQL API as a consumer in your application, it's likely that you'll need to write automated tests to ensure that the integration works correctly. In this blog post, I will show you how to mock GraphQL queries using WireMock.NET.
<!--more--> 

## GraphQL over HTTP

The GraphQL protocol is built on top of HTTP, so a tool like WireMock.NET can be used to stub GraphQL responses. A key to mocking GraphQL communication is knowing the format of the requests and responses. Detailed documentation of the protocol can be found in the [GraphQLOverHTTP](https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md) specification, but in shorthand it looks like this:

-  For requests, GraphQL uses standard HTTP methods, primarily `POST` for queries and mutations. The request body contains a JSON object with fields for the query, variables, and operation name. When using a `GET` request, all required data should be appropriately encoded and passed as query params. Example request payload:

    ```json
    {
    "query": "query GetRepoBasicInfo($owner:String!, $repoName:String!) {\n repository(owner: $owner, name:$repoName)\n {  \n  stargazerCount\n  latestRelease {      \n      tagName      \n    }\n  }\n} ",
    "variables": {
        "owner": "cezarypiatek",
        "repoName": "NScenario"
    },
    "operationName": "GetRepoBasicInfo"
    }
    ```

- Responses are also in JSON, with a `data` field for successful requests or an `errors` array detailing any problems. Content-Type should be set to `application/graphql-response+json'` or `application/json'` and the status code should always be set to 200. Example response payload:
    ```json
    {
        "data": {
            "repository": {
                "stargazerCount": 67,
                "latestRelease": {
                    "tagName": "5.2.0"
                }
            }
        }
    }
    ```

## Mocking query request

WireMock.net stubs consist of two parts: the matcher and the response. The matcher is responsible for identifying a request for which the predefined response will be returned. We need to prepare a suitable matcher to catch GraphQL requests. 
 
The first step is to determine the type of request method (GET or POST) used by our GraphQL client. This information can usually be obtained by examining the client code or by sniffing network traffic with tools such as Fiddler. However, matching by `request method` and `path`` alone may not be sufficient, especially if different GraphQL requests are made during a test scenario. 

As we already know, GraphQL requests are also characterised by attributes such as `query`, `variables` and an optional `operationName`. These are passed as query string parameters in GET requests, or included in the JSON payload for POST requests. Choosing the appropriate attribute to match a specif query requires careful consideration. Using `query` as a matcher can lead to maintainability issues, as it requires replicating the exact query issued by the application. Relying solely on the `variables` attribute may not be universally applicable, as some queries lack parameters. While `operationName` is optional, its usage is enforced when employing tools like StrawberryShake for generating GraphQL client. Therefore, the most effective approach is to combine `operationName` with `variables` for matching. 

When preparing a matcher, we must also remember to format the request payload according to the GraphQL specification. To be compliant, it's a good idea to use `JsonSerializers` from nuget packages such as `GraphQL.NewtonsoftJson` or `GraphQL.SystemTextJson`.

Example stub definition for GET request:

```cs
var wireMock = WireMockServer.Start();
var graphQlSerializer = new GraphQLSerializer();
wireMock
    .Given(
        Request.Create()
            .UsingGet()
            .WithPath("/graphql/proxy")
            .WithParam("operationName", "GetRepoBasicInfo")
            .WithParam("variables", Uri.EscapeDataString(graphQlSerializer.Serialize(new           
            {
                owner = "cezarypiatek",
                repoName = "NScenario"
            })))
            
    )
    .RespondWith(
        Response.Create()
            .WithStatusCode(200)
            .WithHeader("Content-Type", "application/graphql-response+json")
            .WithBody(graphQlSerializer.Serialize(new
            {
                data = new
                {
                    repository = new
                    {
                        stargazerCount = 67,
                        latestRelease = new 
                        {
                            tagName = "5.2.0"
                        }
                    }
                }
            }))
    );
```

Example stub definition for POST request:

```cs
var wireMock = WireMockServer.Start();
var graphQlSerializer = new GraphQLSerializer();
wireMock
    .Given(
        Request.Create()
            .UsingPost()
            .WithPath("/graphql/proxy")
            .WithBody(new JsonPartialMatcher(
                graphQlSerializer.Serialize(new
                {
                    operationName = "GetRepoBasicInfo",
                    variables = new
                    {
                        owner = "cezarypiatek",
                        repoName = "NScenario"
                    }
                })))
    )
    .RespondWith(
        Response.Create()
            .WithStatusCode(200)
            .WithHeader("Content-Type", "application/graphql-response+json")
            .WithBody(graphQlSerializer.Serialize(new
            {
                data = new
                {
                    repository = new 
                    {
                        stargazerCount = 67,
                        latestRelease = new 
                        {
                            tagName = "5.2.0"
                        }
                    }
                }
            }))
    );
```

Since our matching pattern for body is only a subset of the actual JSON payload, we need to use a [JsonPartialMatcher](https://github.com/WireMock-Net/WireMock.Net/wiki/Request-Matching-JsonPartialMatcher) 

Some GraphQL client libraries, such as StrawberryShaker, may rewrite our original query with a request for the `__typename` metadata field. In order for the client to work correctly, we need to include a proper value for this metadata as part of the response data for each object.

```cs
 .RespondWith(
    Response.Create()
        .WithStatusCode(200)
        .WithHeader("Content-Type", "application/graphql-response+json")
        .WithBody(graphQlSerializer.Serialize(new
        {
            data = new
            {
                repository = new 
                {
                    __typename = "Repository",
                    stargazerCount = 67,
                    latestRelease = new 
                    {
                        __typename = "Release",
                        tagName = "5.2.0"
                    }
                }
            }
        }))
    );
```

If you have a problem with matching GraphQL requests, you can use [WireMockInspector](https://github.com/WireMock-Net/WireMockInspector) to diagnose the issue.

## Simulating error response

In GraphQL, regardless of whether a query fails partially or completely, the HTTP status code returned is typically 200 OK. This is because, unlike REST, GraphQL handles errors at the application level rather than at the HTTP level. Even if a query fails, the server will still successfully process the request and return a response in the expected format, which includes an error field in the JSON payload to provide details of what went wrong. For network or server errors unrelated to the GraphQL query itself, standard HTTP error codes (such as 400, 500, etc.) can still be used. 

The GraphQL protocol distinguishes between two types of error:
- `Request errors' - usually caused by client errors such as syntax or validation problems, prevent execution from starting and result in a response with no 'data' entry, but an 'errors' entry detailing the problem.
- Field errors' - occur during execution due to problems such as internal errors or value coercion failures, usually the fault of the service, and result in partial results with both 'data' and 'errors' entries in the response.


Mocking `Request error` response:

```cs
.RespondWith
(
    Response.Create()
        .WithStatusCode(200)
        .WithHeader("Content-Type", "application/graphql-response+json")
        .WithBody(graphQlSerializer.Serialize(new
        {            
            errors = new string[]
            {
                
            }
        }))
);
```

Mocking `Field errors` response:

```cs
.RespondWith
(
    Response.Create()
        .WithStatusCode(200)
        .WithHeader("Content-Type", "application/graphql-response+json")
        .WithBody(graphQlSerializer.Serialize(new
        {
            data = new
            {
                
            },
            errors = new []
            {
                new 
                {
                    message = "Name for character with ID 1002 could not be fetched.",
                    locations = new [] { new { line = 6, column= 7 }},
                    path = new object[] { "hero", "heroFriends", 1, "name" }
                }
            }
        }))
);
```

Detailed specification for GraphQL errors is available here https://spec.graphql.org/October2021/#sec-Errors
