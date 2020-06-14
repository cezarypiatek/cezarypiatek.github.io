---
title: "Twin types - properties synchronization without inheritance"
description: "How to keep two different types in synchronization using roslyn analyzers "
date: 2020-06-13T00:11:45+02:00
tags : ["roslyn", "productivity", "C#", "LiveTemplates","code generation"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---

A couple of months ago I've started working on simple `CRUD` application. A mix of `ASP Core` for `REST` Api with `Dapper` for Database access - probably one of the most popular stack for this kind of services. Very quickly it turned out that it's more complex than I expected and this "simple-boring" `CRUD` became more interesting and challenging. 

## The Problem 

One of the fist problems that I came across was that I have a lot of types that looks very similar but have some differences and serve different purposes like:

- `DBO` - `Data Base Object` - types for mapping SQL query result to C# object
- `DTO` - `Data Transfer Object` for read side - quite similar to `DBO` but very often has more complex shape, aggregate results from more than one DBO, contains additional metadata or pre-formatted data.
- `DTO` - `Data Transfer Object` for write side - similar to this one of the read side but without metadata required for UI and without readonly fields.

Those types require synchronization - when I add a new field to `DBO` then it's very likely that I need to add its counterpart to both types of `DTO` as well (or at least to one of them). Similar situation in case if field renaming - it's a obvious expectation to keep the names consistent across all those types. This cause a need for some sort of mechanism that could help enforce those synchronization somehow automatically. First thing that comes to mind is `inheritance` but it has some significant downsides:

- It introduces direct dependencies between types that we would like to avoid. It could be very strange that `DTO` inherits from `DBO` or other way.
- Sometimes types have fields with the same names but different types. This could be solved with generic types parameters but with a lof of such fields we would end up with very messy code.

The most important thing about inheritance, that programmers very often forget, that it was invented to share behaviors not a code (more precisely a state). Those `POCO` types has no common behaviors - only similar shape. We can also try to address this issue with introducing an interface with common fields but it has similar downsides as inheritance and we end up with even more amount of places that require synchronization. When I add a new field to any of my `POCO` types then I need to remember to add this field to common interface to make this synchronization work - and property declaration needs to me repeated in all types that implements an interface which results with even more amount of code.

I didn't find a good solution for this problem using standard C# mechanisms so I came up with the idea of `TwinTypes`.

## The Solution - Extending C# rules with custom analyzer

Because standard C# mechanisms don't provide satisfying solution, I tried once again to take benefits of the Roslyn analyzers and extends language possibilities. The idea of `TwinType` is to introduce a marker that will express some sort of `"soft dependency"` between types. The whole solution consists of three parts:

- `[TwinType]` attribute to define this `"soft dependency"` or `"shape similarity"` with other type.
- Dedicated Roslyn analyzer that keeps track of related type changes and it's able to report missing fields and properties.
- Additional code fix which is able to generate code of missing members.

Talk is cheap so let's see how it works in code: