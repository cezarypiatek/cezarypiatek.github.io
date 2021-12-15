---
title: "Why I don't use MediatR for CQRS"
description: "Is MediatR really suitable for implementing CQRS pattern?"
date: 2021-12-14T00:18:45+02:00
tags : ["architecture", "dotnet", "dotnetcore", "patterns"]
highlight: true
highlightLang: ["csharp"]
image: "splashscreen.jpg"
isBlogpost: true
---

The purpose of this article is not to criticize the MediatR library. MediatR is a tool - and just like any tool, it has its own scope of application, and being used incorrectly might do more harm than good. This blog post summarizes my thoughts about using MediatR for supporting CQRS architecture.

<!--more-->

## On the way to understand the CQRS

I heard about the CQRS pattern for the very first time in 2015 at one of software development conferences (here's [the recording](https://www.youtube.com/watch?v=Emr4jkhW9L4&ab_channel=PROIDEAEvents) - only in Polish). However, it took me three more years to gain enough experience with building applications to finally understand what problem does it solve and how this approach makes software much easier to create and maintain. The thing that finally convinced me to start using CQRS in practice was a great keynote from Greg Young entitled [8 Lines of Code](https://www.infoq.com/presentations/8-lines-code-refactoring/). If you haven't seen it yet, I highly recommend spending those 45 minutes on it, as it might be a turning point in your software development career. The main message of that presentation is that the key to good architecture is simplicity. Quite often frameworks promise that simplicity but in reality they introduce a lot of "magic", making systems harder to understand and maintain. After watching this video, it turned out that the CQRS pattern is pretty simple to implement and __you actually need only 4 interfaces__.
 
 ## Implementing "Vanilla" CQRS

The CQRS is a strategic pattern. There's a general rule that the `read` and `write` operation should be somehow `separated`. This rule can be implemented in the code using different tactical patterns. The first step that you can take when refactoring an existing system with classical n-layer architecture towards the CQRS is to split existing application services into the read and write services. For example, if you have a `UserService` that performs all operations related to the `User` area, you can divide the existing operations appropriately, based on the responsibility, into two services: `UserReadService` and `UserWriteService`. Those `Read` and `Write` services should be independent of each other - you should not use the Read service inside the Write service, or the other way around. This is the easiest way to start using CQRS in an existing system. However, from my experience, a better approach is to use the pattern presented by Greg Young and implement every operation as a separate type. This way, our code will be more aligned with [SOLID principles](https://en.wikipedia.org/wiki/SOLID), especially with:

- [Single Responsibility](https://en.wikipedia.org/wiki/Single-responsibility_principle) rule - because logic responsible for a given operation is enclosed in its own type.
- [Open-Closed](https://en.wikipedia.org/wiki/Open%E2%80%93closed_principle) rule - because to add new operation you don't need to edit any of the existing types, instead you need to add a new file with a new type representing that operation. 

You can do it as a next step after you split your services into `read` and `write`, or use it from the beginning when you are developing a new system. To implement this approach (let's call it `CQRS Vanilla` for further reference) in C#, you just need those 4 interfaces:

```cs
interface IQueryHandler<in TQuery, TQueryResult>
{
    Task<TQueryResult> Handle(TQuery query, CancellationToken cancellation);
}

interface IQueryDispatcher
{
    Task<TQueryResult> Dispatch<TQuery, TQueryResult>(TQuery query, CancellationToken cancellation);
}

interface ICommandHandler<in TCommand, TCommandResult>
{
    Task<TCommandResult> Handle(TCommand query, CancellationToken cancellation);
}

interface ICommandDispatcher
{
    Task<TCommandResult> Dispatch<TCommand, TCommandResult>(TCommand command, CancellationToken cancellation);
}
```

Some guidelines recommend that the `Handle` method of `ICommandHandler` should not return anything. However, in real world applications, there's always a need to return something (like validation result or identifier of a newly created resource), so it's much easier when this method returns an object.

We also need to provide an implementation of dispatcher's interfaces. For ASP.NET core with default DI container it might look as follows:

```cs
class CommandDispatcher : ICommandDispatcher
{
    private readonly IServiceProvider _serviceProvider;

    public CommandDispatcher(IServiceProvider serviceProvider) => _serviceProvider = serviceProvider;

    public Task<TCommandResult> Dispatch<TCommand, TCommandResult>(TCommand command, CancellationToken cancellation)
    {
        var handler = _serviceProvider.GetRequiredService<ICommandHandler<TCommand, TCommandResult>>();
        return handler.Handle(command, cancellation);
    }
}

class QueryDispatcher : IQueryDispatcher
{
    private readonly IServiceProvider _serviceProvider;

    public QueryDispatcher(IServiceProvider serviceProvider) => _serviceProvider = serviceProvider;

    public Task<TQueryResult> Dispatch<TQuery, TQueryResult>(TQuery query, CancellationToken cancellation)
    {
        var handler = _serviceProvider.GetRequiredService<ICommandHandler<TQuery, TQueryResult>>();
        return handler.Handle(query, cancellation);
    }
}

```
The last thing to make everything work is a little bit of plumbing code to register all necessary components in DI container:

```cs
public class Startup
{
  public void ConfigureServices(IServiceCollection services)
  {
      services.TryAddSingleton<ICommandDispatcher, CommandDispatcher>();
      services.TryAddSingleton<IQueryDispatcher, QueryDispatcher>();
      
      // INFO: Using https://www.nuget.org/packages/Scrutor for registering all Query and Command handlers by convention
      services.Scan(selector =>
      {
        selector.FromExecutingAssembly()
                .AddClasses(filter =>
                {
                    filter.AssignableTo(typeof(IQueryHandler<,>));
                })
                .AsImplementedInterfaces()
                .WithSingletonLifetime();
      });
      services.Scan(selector =>
      {
        selector.FromExecutingAssembly()
                .AddClasses(filter =>
                {
                    filter.AssignableTo(typeof(ICommandHandler<,>));
                })
                .AsImplementedInterfaces()
                .WithSingletonLifetime();
      });
  }
}
```

And that's all you need to start using CQRS in your project. As you can see, there are only 4 interfaces and a few lines of code that depend on your DI container of choice.

## What about MediatR

Implementing all that stuff by myself helped me to understand how the whole concept works. As everything seemed to be very straightforward, I started using this implementation in my applications without looking for any library or framework that implemented this concept. The fact that CQRS is so simple that you don't need any library for it was emphasized in the presentation I saw back in 2015. However, I started hearing questions from other developers: "Why don't you use MediatR for CQRS?" and from time to time I encounter different blog posts presenting how to implement CQRS with MediatR library. I was quite surprised because if it was so simple in 2015 then why do I now need a library to make it work? The arguments like "MediatR is well known in the community" and "it has a lot of stars on Github" don't seem to be convincing, taking into account the simplicity of the pattern. However, I decided to check what is it that `MediatR` can actually offer and I went through the documentation. I read it all and I didn't change my mind. I will explain why.

Let's start from the definition taken from the [MSDN article about CQRS](https://docs.microsoft.com/en-us/azure/architecture/patterns/cqrs):

> CQRS stands for Command and Query Responsibility __Segregation__, a pattern that __separates read and update__ operations for a data store.

I intentionally highlighted the `segregation` and `separates` words in the CQRS definition as it's the most important part of this pattern, and it should be a starting point for discussion on "should I use MediatR for CQRS?". In MediatR we don't have concepts like `Commands` and `Queries`. There's a more generic thing called the `Request`, represented by `IRequest<T>` and `IRequestHandler<TRequest TRequestResult>`. Of course there's also a `Notification` that can be implemented with `INotification` and `INotificationHandler<TNotification>`, but this is unrelated to CQRS so let's leave it alone. Using MediatR we can implement every operation as a separated type - same as with our "Vanilla framework" - but there's no distinction between `read` and write `operations`. Why is this a problem and why is it so important to have this kind of demarcation on the code level? The `Read` and `Write` operations have their own preclusive set of responsibilities. There are certain actions that are allowed or disallowed in a given kind of operation, a few examples from the top of my head:

- it's not allowed to modify data in query handlers
- it's not allowed to persist data in the storage (commit transaction) in query handlers
- it's not allowed to return modified data from the command handlers
- it's mandatory to commit transaction in command handlers after successful data modification
- at the end of processing command operation we likely want to send a notification about the event that just occurred; it's rather unlikely for query operations.

**When we have separate interfaces for query and command handlers, it's easier to focus on the scope of responsibility of that operation and it's much easier to notice any violation of CQRS rules during the code review.**

As I mentioned before, MediatR doesn't have Commands and Queries but we can introduce such distinction by adding the following marking interfaces:

```cs
interface ICommand<out TCommandResult>: IRequest<TCommandResult> { }
interface ICommandHandler<in TCommand, TCommandResult> : IRequestHandler<TCommand, TCommandResult> where TCommand : ICommand<TCommandResult> { }

interface IQuery<out TIQueryResult> : IRequest<TIQueryResult> { }
interface IQueryHandler<in TQuery, TQueryResult> : IRequestHandler<TQuery, TQueryResult> where TQuery : IQuery<TQueryResult> { }
```

Those four extra interfaces allow us to tell apart commands and queries operations. Now we are more aligned with the CQRS definition but this approach has some disadvantages related to maintenance. We need to inform other developers working on the project that we are allowed to use only those interfaces to implement our commands and queries, and we can't directly use gears provided the by MediatR. Of course, there's always a risk that somebody uses `IRequest` and `IRequestHandler` interfaces directly, especially when we have seasoned `MediatR` users or project newcomers - they will probably struggle with all habits. I especially don't recommend doing that in an existing project as the mix of this extra abstraction and the original MediatR interfaces might be very confusing. This might be counter-productive as we start fighting with a library that is not well aligned with our design.

Before we go this way, we should ask ourselves one important question: **"If the pattern consists of four interfaces and we need to create them anyway to use a library that should provide them, what is the benefit of that library?"**


### Cross Cutting Concerns

Another missing part in MediatR is the distinction of commands and queries in the mechanism responsible for operation dispatching. Having two separate interfaces allows for creating independent workflows for the read and write operations. Here are a few examples of actions that you want to apply to only one side:

- caching results of read operations
- restricting write operations based on the user claims or environment
- setup Unit Of Work in the read-only mode for query side and with write mode for commands
- audit of write operations
- automatic retries

In the MediatR, aspect operations can be implemented with Behaviors (`IPipelineBehavior<TRequest, TResponse>`) but as there's no distinction between Commands and Queries, you cannot create separate pipelines for `read` and `write` operations. If you want to have a specific behavior only for one side, you end up with a bunch of `if statements` in the behavior implementation:

```cs
class SampleQuerySpecificBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
{
    public async Task<TResponse> Handle(TRequest request, CancellationToken token, RequestHandlerDelegate<TResponse> next)
    {
        if (request is IQuery<TResponse>)
        {
            // Before operation stuff
        }

        var result = await next();
        
        if (request is IQuery<TResponse>)
        {
            // After operation stuff
        }

        return result;
    }
}
```

In our `Vanilla framework` we can implement all cross-cutting concerns by creating decorators for `ICommandDispatcher` and `IQueryDispatcher`:

```cs
class SampleQueryDispatcherDecorator: IQueryDispatcher
{
    private readonly IQueryDispatcher _queryDispatcher;

    public SampleQueryDispatcherDecorator(IQueryDispatcher queryDispatcher) 
            => _queryDispatcher = queryDispatcher;

    public async Task<TQueryResult> Dispatch<TQuery, TQueryResult>(TQuery query, CancellationToken token)
    {
        // Before operation stuff
        var result = await _queryDispatcher.Dispatch<TQuery, TQueryResult>(query, token);
        // After operation stuff
        return result;
    }
}
```

As you can see, it is less cluttered, much more readable, and easier to understand in comparison to the behavior created with `MediatR`.

## Final thoughts

`MediatR` seems to be a pretty decent implementation of [mediator patter](https://en.wikipedia.org/wiki/Mediator_pattern) which has its own area of application. However, `mediator patter` solves a totally different problem than the CQRS pattern. Of course, it can be used to implement CQRS but the cost of adjusting the `MediatR` library to play well with the CQRS guideline seems unjustified, considering the simplicity of CQRS pattern. My main objection against using `MediatR` for `CQRS` is the lack of clear distinction between the `read` and `write` sides. In my opinion, the popularity of `MediatR` in CQRS apps seems to be a cargo cult that might have roots in CQRS pattern misunderstanding or the lack of will to understand it. I wonder what are your thoughts on the subject?