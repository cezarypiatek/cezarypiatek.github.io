---
title: "Mocking GraphqQL queries with WireMock.NET"
description: "Mocking outgoing HTTP requests in ASP.NET Core tests"
date: 2024-01-13T00:10:45+02:00
tags : ["testing", "mocks", "aspcore", "dotnet", "WireMock"]
highlight: true
highlightLang: ["cs", "json"]
image: "splashscreen.jpg"
isBlogpost: true
---


GraphQL is a query language for APIs that allows clients to request exactly what they need, making data fetching more efficient compared to traditional REST APIs. It supports three different ways of interactions between client and server: queries, mutations, and subscriptions. When you start integrating a GraphQL API as a consumer in your application, it's likely necessary to write automated tests to ensure the integration works correctly. In this blog post, I presents how to mock GraphQl queries using WireMock.NET.
<!--more--> 

## GraphQL over HTTP

GraphQL protocol is build on top of HTTP hence a tool like WireMock.NET can be used for stubbing GraphQL responses. A key to mock GraphQL communication is knowing the format of requests and responses. A detailed documentation of the protocol can be found in the specification [GraphQLOverHTTP](https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md) but in shorthand it looks as follows:

-  For requests, GraphQL uses standard HTTP methods, primarily `POST` for queries and mutations. The request body contains a JSON object with fields for the query, variables, and operation name. When using `GET` request, all required data should be appropriately encoded and passed as query params. Example request payload:

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

- Responses are also in JSON, with `data` field for successful requests or an `errors` array detailing any issues. Content-Type should be set to `"application/graphql-response+json"` or `"application/json"` and the status code should always be set to 200. Example response payload:
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

 WireMock.net stubs consists of two parts: the matcher and the response. The matcher is responsible for identifying a request for which the predefined response will be returned. We need to prepare an appropriate matcher to catch GraphQL requests. 
 
 The first step involves determining the type of request method (GET or POST) used by our GraphQL client. This information can typically be obtained by examining client code or by sniffing network traffic with tools like Fiddler. However, matching only by `request method` and `path` may not be sufficient, particularly when different GraphQL requests are made during a test scenario. 
 
 As we already known, GraphQL requests are also characterized by attributes such as `query`, `variables`, and an optional `operationName`. These are passed as query string parameters in GET requests or encapsulated within the JSON payload for POST requests. Selecting the appropriate attribute for matching involves a careful consideration. Utilizing `query` as a matcher may lead to maintainability challenges, as it requires replicating the exact query issued by the application. Solely relying on the `variables` attribute may not be universally applicable, as some queries lack parameters. While `operationName` is optional, its usage is enforced when employing tools like StrawberryShake for generating GraphQL client. Therefore he most effective approach is to combine `operationName` with `variables` for matching. 
 
 While preparing a matcher, we also need to remember to format the request payload according to the GraphQL specification. To be compliant with the spec it's good to use `JsonSerializers` from nuget packages like `GraphQL.NewtonsoftJson` or `GraphQL.SystemTextJson`.

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
                })
                ))
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

Some GraphQL client libraries like StrawberryShaker might rewrite our original query with a request for `__typename` metadata field. To make the client works correctly, we need to include a proper value for that metadata as a part of response data for every object.

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

## Simulating error response

In GraphQL, regardless of whether a query partially or totally fails, the HTTP status code typically returned is 200 OK. This is because GraphQL, unlike REST, handles errors at the application level rather than the HTTP level. Even if a query fails, the server still successfully processes the request and returns a response in the expected format, which includes an errors field in the JSON payload to provide details about what went wrong. For network or server errors unrelated to the GraphQL query itself, standard HTTP error codes (like 400, 500, etc.) may still be used. 

GraphQL protocol distinguish two kinds of errors:
-  `Request errors` - usually caused by client mistakes like syntax or validation issues, prevent execution from starting and result in a response with no 'data' entry, but an 'errors' entry detailing the issue.
-  `Field errors` - occur during execution due to issues like internal errors or value coercion failures, usually the service's fault, leading to partial results with both 'data' and 'errors' entries in the response.


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
