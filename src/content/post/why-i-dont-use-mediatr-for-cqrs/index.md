---
title: "Why I don't use MediatR for CQRS"
description: "Is MetiatR really suitable for implementing CQRS pattern?"
date: 2021-12-04T00:18:45+02:00
tags : ["architecture", "dotnet", "dotnetcore", "patterns"]
highlight: true
highlightLang: ["cs"]
image: "splashscreen.jpg"
isBlogpost: true
---

The purpose of this article is not to critize the MediatR library. MediatR is a tool, and as every tool, it has its own scope of application and used incorrecly might do more harm than good.

I heard very first time about CQRS pattern around 2015 on one of the software development conference. I'm not sure why I didn't start using it immediately but few years later, after gaining more experience with building application I finally understand what problem does it solved and how this approach makes things much easier to create and maintain.
There's a great keynote from Greg Young entitled [8 Lines of Code](https://www.infoq.com/presentations/8-lines-code-refactoring/) in which he explain in very neat way how to refactor towards the CQRS. The pattern is very straight forward and in order to implement it in C# you just need those 4 interfaces:


```cs
public interface IQueryHandler<TQuery, TQueryResult>
{
  Task<TQueryResult> Handle(TQuery query, CancellationToken cancellationToken);
}

public interface IQueryDispatcher
{
    Task<TQueryResult> Dispatch<TQuery, TQueryResult>(TQuery query);
}


public interface ICommandHandler<TCommand, TCommandResult>
{
  Task<TCommandResult> Handle(TCommand query, CancellationToken cancellationToken);
}

public interface ICommandDispatcher
{
    Task<TCommandResult> Dispatch<TCommand, TCommandResult>(TQuery query);
}

```


Ofc you need also `IQueryDispatcher` and `ICommandDispatcher` implementation and some plumbing code responsible for registering it in the Dependency Injection container which is dependent on the DI implementation. For ASP Core default container it might looks as follows:


```cs
public class QueryDispatcher: IQueryDispatcher
{
    private readonly IServiceProvider _serviceProvider;

    public QueryDispatcher(IServiceProvider serviceProvider) => _serviceProvider = serviceProvider;

    public async Task<TQueryResult> Dispatch<TQuery, TQueryResult>(TQuery query)
    {
      var handler = _serviceProvider.GetRequiredService<IQueryHandler<TQuery, TQueryResult>>();
      var httpContext = _serviceProvider.GetRequiredService<IHttpContextAccessor>
      return await handler.Handle(query, httpContext.Context.CancellationToken);
    };
}

```

Let's start from the definition taken from the [MSDN article about CQRS](https://docs.microsoft.com/en-us/azure/architecture/patterns/cqrs):

> CQRS stands for Command and Query Responsibility __Segregation__, a pattern that __separates read and update__ operations for a data store.

I intentionally highlighted `segregation` and `separates` words in the CQRS definition as it's the most important part of this pattern and this should be a starting point for the discussion "should I use MediatR for CQRS?". In MediatR we don't have concepts like `Commands` and `Queries`. There's more generic things called the `Request` (represented by `IRequest<T>` and `IRequestHandler<TRequest TRequestResult>`)  as well as `Notification` (`INotification` and `INotificationHandler<TNotification>`). So there's no concepts of `Queries` and `Commands` but we can implemented them using only `Request` or with `Requests` and `Notification`. But this is more like with the nail and hammer - "if you have a hammer everything looks like a nail".