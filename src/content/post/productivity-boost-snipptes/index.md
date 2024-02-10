---
title: "C# code snippets for Resharper and Rider"
description: "My private collection of convention-based code snippets"
date: 2024-02-10T00:10:45+02:00
tags : ["csharp", "snippets", "LiveTemplates", "dotnet", "Rider", "Resharper"]
highlight: true
highlightLang: ["cs", "json"]
image: "splashscreen.jpg"
isBlogpost: true
---

10 years ago I published my first blog post entitled ["Don't write dull code"](/post/livetemplates/) which was dedicated to a Resharper feature called LiveTemplates. It's a code snippet engine that was originally introduced in Resharper, but is now also available in Rider. LiveTemplate comes with a set of predefined snippets for basic coding scenarios such as conditions, loops, exception handling, etc. However, the real power lies in the ability to create custom snippets with placeholders that can be completed manually or automatically by macros. What's more, unlike the original Visual Studio snippets feature, adding new snippets is super easy. 

I've been using Live Templates for over a decade, both in my day job and after hours, and I think it's one of Resharper's best features. However, from my personal observation, it hasn't been very popular among the developers I've worked with so far. Which is very surprising. If you haven't used Live Templates before, it's definitely worth a try.


## Too many shortcuts

Each LiveTemplate snippet has assigned a shortcut - a sequence of characters that needs to be typed in order to trigger snippet insertion. For example when you type `prop` the LiveTemplates will automatically insert `public $type$ $name$ {get; set;}` and move the cursors appropriately to allow you easily replace the `$type$` and `$name$` with desired values. As your collection of custom snippets starts growing, a new problem occurs - how to remember all of those shortcuts. 

## Concept Driven Typing
A long time ago I came across a blog post that suggested the idea of creating shortcuts for snippets based on conventions. The convention could be, for example, an acronym of the concepts we want to insert, or an acronym of the actual content of the snippet. Such a convention could be a "prop" prefix plus a first letter representing the type of property we want to insert:

| Concept | Shortcut | Snippet |
| -- | -- | -- |
|property string| props | `public string $name$ { get; set; }`|
|property int| propi |`public string $name$ { get; set; }`|
|property decimal  | propd |`public decimal $name$ { get; set; }`|

We can make it even shorter by using just `p` instead of `prop`. This is a really nice upgrade of the old well-known "prop" snippets. It's shorter and gives me the more specific result I need.

Another example of using the acronym convention could be a set of snippets for the most common throw exceptions:

| Concept | Shortcut | Snippet |
| -- | -- | -- |
|Throw InvalidOperationException| tio | `throw new InvalidOperationException("$message$);`|
|Throw NotImplementedException| tni |`throw new NotImplementedException("$message$);`|
|Throw ArgumentException  | ta |`throw new ArgumentException("$message$, nameof($param$));`|


I started creating my own code snippets based on this idea, and it makes them very easy to remember - actually I don't have to remember them at all. I just write the first letters of the construction or concept I want to enter. This makes coding more enjoyable. I like to call it `Concept Driven Typing` - by using a shortcut you tell your IDE what you need instead of typing everything manually.

## Snippets in the era of AI assistants

Why do I still find it useful in the age of copilots and AI assistants? Many of these AI IDE plugins try to predict what we want to write - not always offering the best choice, which slows us down instead of moving us forward. Code snippets allow us to write exactly what we want very quickly, and our attention is not distracted and stays on track. I'm not saying one approach is better than the other. I think both tools are complementary. If you know exactly what you want to type, use snippets; if you don't know how to implement something, go with the AI assistant.

## Snippets for a cup of coffee
For over a decade I have been creating lots of code snippets and they allow me to focus more on what I want to write rather than how to write it, saving time and making me more productive.

Some time ago I started to organise my snippets and I got the idea that it would be great to share them with others. It took me a couple of weeks to get all my snippets into a single collection, fixing formatting, descriptions, adding missing namespaces and categorising them. I even made a really nice cheat sheet showing all the shortcuts along with the content of the snippets. It took me a long time to organise them, so I decided to make them available for the price of a cup of coffee. All snippets along with the cheat sheet are available to download [here](https://store.mappinggenerator.net/b/productivity-boost-snippets)

The collection contains about 150 code snippets. It seems a lot and I don't expect you to use all of them, but I bet you will find a subset that will definitely improve your productivity a little. The cheat sheet included in the package should make it easier to discover all the snippets, and its mnemonic character should make it easier to remember them.

This collection should also serve as an inspiration. You can easily adapt these snippets to your needs or create a whole new one based on what you find in my collection. Enjoy!

