---
title: "Mocking GraphqQL queries and mutations with WireMock.NET"
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

-  For requests, GraphQL uses standard HTTP methods (primarily POST for queries and mutations). The request body typically contains a JSON object with fields for the query, variables, and operation name. Example request payload:
    ```json
    {
        "query": "{ human(id: \"1000\") { name height } }",
        "variables": {},
        "operationName": "GetHumanData"
    }
    ```
- Responses are also in JSON, with `data` field for successful requests or an `errors` array detailing any issues. Content-Type should be set to `"application/graphql-response+json"` or `"application/json"` and the status code should always be set to 200. Example response payload:
    ```json
    {
        "data": {
            "human": {
            "name": "Luke Skywalker",
            "height": 1.72
            }
        },
        "errors": [
            {

            }
        ]
    }
    ```

## Mocking query request

Short spec
https://graphql.org/learn/serving-over-http/

Detailed specification
https://github.com/graphql/graphql-over-http/blob/main/spec/GraphQLOverHTTP.md

Serialization spec https://spec.graphql.org/October2021/#sec-JSON-Serialization

```xml
<PackageReference Include="WireMock.Net" Version="1.5.46" />
<PackageReference Include="GraphQL.NewtonsoftJson" Version="7.7.2" />
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