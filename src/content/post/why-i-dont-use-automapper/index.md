---
title: "The reasons behind why I don't use AutoMapper."
description: "All the reasons behind I don't use autommaper. I used to but I quit."
date: 2018-01-29T00:05:18+02:00
tags : ["AutoMapper", "orm", "crud", "mapping"]
scripts : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js", "//cdnjs.cloudflare.com/ajax/libs/fitvids/1.2.0/jquery.fitvids.min.js"]
css : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css"]
image: "splashscreen.jpg"
isBlogpost: true
---
![splashscreen](splashscreen.jpg)

The idea behind this blog post is pretty old but I have not enough motivation to write this down so far. Recently, I came across  on a couple of new articles about AutoMapper and I've been struct when I saw how people utilize Autommaper in their projects. I've encounter the cases when Autommaper transform simple thing like mapping values from object to other into really complex problem which results with highly complicated code only for the price of not writing mappings explicitly. Finally I've found a provoking tweet on my timeline that definetely motivate me to materialize my reflections about Automapper into the form of this blog post.

![tweet](tweet.jpg)

Over a 5 years ago I participate in the project where there was a trial of using AutoMapper but happily we drown back from this idea in time. Bear with me and I explain you why this was a good decision.

## Misleading static analysis

The first problem is static analysis starts to report that some fields from my entity are never used. There is no reference in code because on one side ORM automatically maps those fields into database table columns and on the other side is AutoMapper. This issue is related to fields which are not involved in any business logic and they are simply  read from user input, saved into databse and read back for only raw presentation purpose (the business always wants to gather as much information as it is possible). So when we take advise from static analysis report and we drop these fields we simply break the system. We could mark these fields with [UsedImplicity] attributes (if you use Resharper static analysis) or disable this inspection completely but that only hides the problem. The same situation is with DTO objects. One side AutoMapper, on the other side some kind of serializer. And again if we rename or drop the field we silently break the system. We'll get feedback only when we run some kind of test during the runtime. 
For me the static analysis plays a really important role in managing the project's code quality  and when some library starts to undermine the credibility of this report I have to have a really good reason to choose that library. It's the same situation like in the story about building with broken window - when we have to ignore some set of errors caused by usage of given library, sooner or later we starts to ignore others errors because we are not be able distingwish which one is a real problem. If you are in situation where you are not burden with errors that you have to mentally ignore you can treat static analysis as a another type of test for your system. You can ran static analysis tool as a part of you continuous integration pipeline and treat all reported errors the same way as you treat failed unit tests. 

![Use inspection error as build failure condition](failure_condition.jpg)

This will definetely save your code from really sophisticated bugs. You can read more about problems that can be solved thanks to static analysis in my post devoted to [Resharep Solution Wide Analysis](/post/hunt-your-bugs-design-time/)

## Helpless code navigation
Another problem is it is not possible to find out which field from DTO map to which field in entity (or entities). When we use tools like "show usages" it shows us only this single occurrence because there is no explicit mapping in the codebase. The resolution is to write explicitly mapping configuration for all the fields we want to map, but do I really need heavy reflection mechanism to rewrite value from field in one object to another?

## Hard to debug

The next thing is about fluent configuration. I'm not a huge fan of this writing code approach, actually I don't like it at all. Why? It's very hard to debug this kind of code and sometimes it's even impossible. This is not a code which is evaluated, it's only a declarative description of expected behavior. Your "code" is processed by third party library which produce real code based on this description. Even if you provide mapping method with **MapFrom<>** method, you cannot put there breakpoint and expect that program invocation stop when you call  **Mapper.Map<>()** method. This is due the fact that **MapFrom<>()** is expecting **Expression\<Func\<TSource, TSourceMember\>\>** not **Func\<TSource, TSourceMember\>**.  And if you have a bug in your mapping code you don't get exception in the place where you could potentially expect it. Actually you don't get any exception at all. I observed that Automapper is somehow swallowing exception that occurs during the mapping. These reasons makes debugging ver hard.

```csharp
static void Main(string[] args)
{
    Mapper.Initialize(cfg =>
    {
        cfg.CreateMap<UserEntity, UserDTO>()
           .ForMember(x=>x.FullName, opt=> opt.MapFrom(x=> $"{x.FirstName} {x.LastName} ({x.Address.City})"));
    });

    var userEntity = new UserEntity()
    {
        FirstName = "Cezary",
        LastName = "Piątek",
        Address = null
    };
    var userDto = Mapper.Map<UserDTO>(userEntity);
    var serialized = JsonConvert.SerializeObject(userDto, Formatting.Indented);
    Console.WriteLine(serialized);
    Console.ReadKey();
}
```
In the example above I've been expecting *NullReferenceException* when I called *Mapper.Map<UserDTO>(userEntity)* (because x.Address in mapping code is null) but as the result I've got the following output on my console:

```javascript
{
    FullName : null
}
```


## Broken code organization

Some people say that AutoMapper is perfectly fine for simple projects, but believe me - there is no such thing like simple project. Even when this looks simple at the beginning - sooner or later it get complex. The change requests appear which require conditional mapping or additional formatting. This is the reason of introducing sophisticated logic or even the security (based on the permission set of current user you can sometimes map values to the transport object and vice versa). People tend to put this complex mapping logic inside the automapper configuration because this is the fastest way to achive expected effect. I think it's not a good practice to put your business and security logic inside some infrastructure tool configuration. You can say ok - If I've got a complex mapping then I write it explicitly. But then you have two ways of doing one thing - AutoMapper and explicit mapping. And there appears question when should I use which. And the answer is depend... And you introduce chaos into your codebase.

## How to organized mappings
Write your mapping explicitly. If you find this boring you can utilized some kind of snippets or scaffolding tools (such as T4 Scaffolding or something based on Roslyn) to generate this "dummy" code. You can encapsulate this code by introducing new component type responsible for mapping objects. We introduced a notion of *ServiceMapper components with a set of MapTo\* and MapFrom\* methods which serve the purpose of given endpoint service. Why not to use extension methods? The reason is again the complexity. Sometimes you need another dependencies to fulfil the mapping logic and the extension method make it hard to utilize dependency injection to provide this dependencies (you can use only service locator which is considered as an anti-pattern or ambient context)

## Final thought
AutoMapper is probably  good for really small, short-lived projects or proof of conceps, but when you starts to care about your code quality you should definetely rethink all pros and cons against using Automapper. When you observes problems like those described in this blogpost you should consider abandoning AutoMapper and start to write your mappings explicitly (it really doesn't hurt). If you encounter others problems which arise from using AutoMapper I would be really appreciate if you could share your experience in the comment section.



