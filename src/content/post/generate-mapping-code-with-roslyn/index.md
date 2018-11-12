---
title: "Generate mapping code with Roslyn code fix provider."
description: "How to substitute AutoMapper with Roslyn code fix provider that generates code in design time."
date: 2018-02-27T00:23:45+02:00
tags : ["AutoMapper", "Roslyn", "mapping", "code generating"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---
A few weeks ago I posted about [negative aspects of applying AutoMapper](/post/why-i-dont-use-automapper/). As an alternative I suggested typing all mapping code by hand or utilize some kind of generator like [T4Scaffoling](https://www.nuget.org/packages/T4Scaffolding/) or something Roslyn based. In the past I experimented with T4Scaffoling but it was quite tedious. It requires preparation of templates in [T4](https://msdn.microsoft.com/en-us/library/bb126445.aspx) syntax, referencing it to the project and writing some PowerShell code to provide data for templates. There also was an issue with assembly locking. Then I tried to generate code with PowerShell and [EnvDTE](https://docs.microsoft.com/en-us/dotnet/api/envdte). It worked but it had some limitations and it wasn't convenient enough to start using it on a daily basis. I gave it one more try and after publication of mentioned post I started looking for an existing Roslyn-based solution that could be a really nice substitution for AutoMapper. That's how I found [ObjectMapper](https://github.com/nejcskofic/ObjectMapper) project. 

At first it looked promising but after some analysis I found few things I didn't like about it. For instance, it requires referencing additional library which contains attributes and interfaces used to mark mapping methods. In practice it means that I need to install additional nuget package to every project in which I want to use mapping generation feature which is quite uncomfortable. So I've tried to create my own version which will be distributed in the form of Visual Studio Extension and will use conventions to locate candidates for potential mapping methods. I was interested in generating implementation for the following kinds of methods:

- Pure mapping method - non-void method that takes single parameter

  ```csharp
  public UserDTO Map(UserEntity entity)
  {
      throw new NotImplementedException();
  }
  ```
- Updating method - void method that takes two parameters

  ```csharp
  public void Update(UserDTO source, UserEntity target)
  {
      throw new NotImplementedException();
  }
  ```
- Mapping Constructor - constructor that takes single parameter

  ```csharp
  public UserDTO(UserEntity user)
  {
      
  }
  ```
- Updating member method - void member method that takes single parameter

  ```csharp
  public void UpdateWith(UserEntity en)
  {
      throw new NotImplementedException();
  }
  ```
Thanks to the abilities Roslyn gives, I could quite easily create code fix provider that generates implementation for the types of mapping methods mentioned above. A sample code generation in action looks as follows:

![mapping code generation](https://github.com/cezarypiatek/MappingGenerator/raw/master/doc/pure_mapping_method.gif)

I've publish source code on [github](https://github.com/cezarypiatek/MappingGenerator) and if you are interested in testing it in action you can install it as Visual Studio Extension from [Visual Studio Marketplace](https://marketplace.visualstudio.com/items?itemName=54748ff9-45fc-43c2-8ec5-cf7912bc3b84.mappinggenerator). For now it covers a few basic scenarios (you can read more about it on github) and there is a lot of things that could be improved such as:

- extracting method for mapping complex properties
- reusing existing mapping method to map complex properties
- using initialization block to create new objects
- updating collection instead of replacing content completely
- improving local variables names generating to avoid collisions

With a new asset in my developer toolbox now I'm able to quickly generate this boring mapping code and focus enirely on the real coding problems. There is also another positive side effect that comes from the convention-based mappings - it enforces the cohesion of naming. If you have different names for the same thing on both mapping sides you have more code to write manually ;)