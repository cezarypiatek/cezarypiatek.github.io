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

The purpose of this article is not to criticize the MediatR library. MediatR is a tool, and as every tool, it has its own scope of application and used incorrectly might do more harm than good.

## On the way to understand the CQRS

I heard for the very first time about CQRS pattern in 2015 on one of the software development conference (Here's [the recording](https://www.youtube.com/watch?v=Emr4jkhW9L4&ab_channel=PROIDEAEvents) - only in Polish). However, I took me 3 more years, to gain enough experience with building applications, to finally understand what problem does it solved and how this approach makes software much easier to create and maintain. The thing that finally convinced me to start using CQRS in practice was a great keynote from Greg Young entitled [8 Lines of Code](https://www.infoq.com/presentations/8-lines-code-refactoring/). If you haven't seen it yet, then I highly recommend spending those 45 minutes as it might be a turning point in your software development career. The main message of that presentation is that the key to good architected is the simplicity and it can be achieve without any frameworks. It turned out that the CQRS pattern is pretty simple to implement and you actually need ony those 4 interfaces.

 in which he explain in very neat way how to refactor towards the CQRS. This 1h long video is not only about CQRS, because the pattern is straight forward, it can be implemented in those 8 lines, but this is about refactoring that changes the mindset and approach toward designing app internal architecture. It's about removing magic and glorifying simplicity. I saw a lot of articles how to implement CQRS with MediatR (some of them eve still use Repository pattern 0.0) but all of that smells like a cargo cult to me. Arguments like let's use something that is well-know and have a lot of stars on github....  
 
 ## Implementing "Vanilla" CQRS

The CQRS pattern is a strategic patter, it's a general rule that says that `read` and `write` operation should be somehow `separated`. This rule can be implemented in the code using different tactical patterns. The first step that you can take when you are refactoring existing system with classical n-layer architecture towards the CQRS is to split existing application services into read and write services. For example if you have a `UserService` that performs all operations related to the `User` area, you can move the existing operations appropriately based on the responsibility into one of the following services: `UserReadService` and `UserWriteService`. Those `Read` and `Write` services should be independent of each other - you should not use Read service inside the Write service or in the other way. This is the easier way to start using CQRS in the existing system. However, from my experience, the better approach is to use pattern presented by Greg Young and implement every operation as a separate type. You can do it as a next step after you split your services into `read` and `write`, or use it from the beginning when you are developing a new system. To implement it in C# you just need those 4 interfaces:

```cs
interface IQueryHandler<in TQuery, TQueryResult>
{
    Task<TQueryResult> Handle(TQuery query, CancellationToken cancellationToken);
}

interface IQueryDispatcher
{
    Task<TQueryResult> Dispatch<TQuery, TQueryResult>(TQuery query);
}

interface ICommandHandler<in TCommand, TCommandResult>
{
    Task<TCommandResult> Handle(TCommand query, CancellationToken cancellationToken);
}

interface ICommandDispatcher
{
    Task<TCommandResult> Dispatch<TCommand, TCommandResult>(TCommand command);
}
```
If we want to keep strictly with the pattern, the `Handle` method of `ICommandHandler` should not return anything, but in real world application, there's always a need to return something, like validation result or the identifier of newly created resource so it's much easier when this method return an object.

We also need to provide an implementation of dispatcher's interfaces. For ASP.NET core with default DI container it might look as follows:

```cs
class CommandDispatcher : ICommandDispatcher
{
    private readonly IServiceProvider _serviceProvider;

    public CommandDispatcher(IServiceProvider serviceProvider) => _serviceProvider = serviceProvider;

    public Task<TCommandResult> Dispatch<TCommand, TCommandResult>(TCommand command)
    {
        var handler = _serviceProvider.GetRequiredService<ICommandHandler<TCommand, TCommandResult>>();
        var httpContextAccessor = _serviceProvider.GetRequiredService<IHttpContextAccessor>();
        return handler.Handle(command, httpContextAccessor.HttpContext?.RequestAborted ?? default);
    }
}

class QueryDispatcher : IQueryDispatcher
{
    private readonly IServiceProvider _serviceProvider;

    public QueryDispatcher(IServiceProvider serviceProvider) => _serviceProvider = serviceProvider;

    public Task<TQueryResult> Dispatch<TQuery, TQueryResult>(TQuery query)
    {
        var handler = _serviceProvider.GetRequiredService<ICommandHandler<TQuery, TQueryResult>>();
        var httpContextAccessor = _serviceProvider.GetRequiredService<IHttpContextAccessor>();
        return handler.Handle(query, httpContextAccessor.HttpContext?.RequestAborted ?? default);
    }
}

```
The last thing to make everything work is a little bit of plumbing code to register all necessary components in DI container:

```cs
public class Startup
{

  // This method gets called by the runtime. Use this method to add services to the container.
  public void ConfigureServices(IServiceCollection services)
  {
      services.AddHttpContextAccessor();
      services.TryAddSingleton<ICommandDispatcher, CommandDispatcher>();
      services.TryAddSingleton<IQueryDispatcher, QueryDispatcher>();
      
      // INFO: Using https://www.nuget.org/packages/Scrutor for registering all Query and command handlers by convention
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

I've registered everything with singleton lifetime but some developers prefers to work with scoped lifetime components. I like singleton because it simplifies things a lot. If you start mixing different lifecycle then it's easy to make a mistake.


And that's basically everything what you need to start using CQRS in your project. As you can see there are only 4 interfaces and a few lines of code that depends on your DI container of choice.

## What about MediatR

Implementing all that stuff by myself really help me to understand how the whole concept works. As everything seems to be a very straightforward I started using this implementation in my applications without looking for any library or framework that implements this concept. The fact, that CQRS is so simple that you don't need any library for it, was emphasize in the presentation that I saw in 2015. However, I started hearing questions from other developers: "Why don't you use MediatR for CQRS?" and I saw that there's a lot of blog post presenting how to implement CQRS with MediatR library. My response was always "Why do I need library for something that can be achieve with four interfaces" but then they replies with things like: MediatR is well known in the community, it has a lot of stars on the github, blah, blah, blah.... So I decided to take a look at this famous library and I went through the documentation. I read it all and I didn't change my mind. Let me explain why.

Let's start from the definition taken from the [MSDN article about CQRS](https://docs.microsoft.com/en-us/azure/architecture/patterns/cqrs):

> CQRS stands for Command and Query Responsibility __Segregation__, a pattern that __separates read and update__ operations for a data store.

I intentionally highlighted `segregation` and `separates` words in the CQRS definition as it's the most important part of this pattern and this should be a starting point for the discussion "should I use MediatR for CQRS?". In MediatR we don't have concepts like `Commands` and `Queries`. There's more generic things called the `Request` (represented by `IRequest<T>` and `IRequestHandler<TRequest TRequestResult>`)  as well as `Notification` (`INotification` and `INotificationHandler<TNotification>`). So there's no concepts of `Queries` and `Commands` but we can implemented them using only `Request` or with `Requests` and `Notification`. But this is more like with the nail and hammer - "if you have a hammer everything looks like a nail". If the pattern consists of four interfaces and we need to create them anyway to used a library that should provide them, what is the benefit?

Let's talk about this famous separation and why is that important. Keeping a separate interfaces for commands and queries have the following benefits:
- it's easier to verify and enforce if a given operation obeys the rules of the category to which it belongs. If you see that a given handler implements ICommandHandler or IQueryHandler it's easier to spot problems like
- modifying data in query handler
- committing transaction in query handler
- returning modified data from the command handler.

Keeping a separate interfaces for commands and queries dispatcher have the following benefits:
- you can add very easily caching to queries
- you can block commands based on the user claims or environments
- you can enforce readonly UOW for query sides and with write mode for commands.

Ofc you can achieve all of that by adding some extra code when you are using MediatR but this will end up in fighting with library. When you have a separated interfaces for each side, implementing this kind of behavior is much easier and natural.



- People know libraries without understanding the problem which they solved. I would rather have a developer which understand the patterns and architecture.


You might accuse me that I stated that I don't use libraries but I used Scrutor. Scrutor solves the problem that I have - registering components by convention - and it allows to achieve that in a pretty neat way..