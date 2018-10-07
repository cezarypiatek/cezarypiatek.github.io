---
title: "The art of designing exceptions"
description: "Skip the boring part of the CQRS with Resharper snippets."
date: 2018-10-06T00:20:45+02:00
tags : ["exceptions", "architecture"]
scripts : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js", "//cdnjs.cloudflare.com/ajax/libs/fitvids/1.2.0/jquery.fitvids.min.js"]
css : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css"]
image: "splashscreen.jpg"
isBlogpost: true
---

Have you ever been in the situation when discovered in logs exception force you to spend the next couple of minutes or even hours figuring out what exactly went wrong? The message was very cryptic and the only useful information that guides you to the crime scene was a stack trace. But after arriving there you still have no idea what really happened and what is the culprit. And the most frustrating part is that in many cases the reason is very trivial and could be diagnosed immediately if the error message contains sufficient information. Sounds familiar? I was in this situation many times before, especially when I was working with 3rd party libraries. In this blog post, I would like to share with you my thoughts and experience related to designing exception.


First of all, there is a chapter in [Framework Design Guideline](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/index) devoted to [Design Guidelines for Exceptions](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/exceptions) which every .net developer should get familiar with. There are three main sections which cover the subject of:

- [Exception Throwing](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/exception-throwing) 

- [Using Standard Exception Types](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/using-standard-exception-types)

- [Exceptions and Performance](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/exceptions-and-performance) 

Obeying this guideline should at some point make our life easier but there are also areas for more improvement especially in terms of information which should be included in the exception.