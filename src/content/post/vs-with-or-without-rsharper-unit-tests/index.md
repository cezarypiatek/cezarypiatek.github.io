---
title: "Visual Studio with or without Resharper: Unit Testing"
description: ""
date: 2019-01-26T00:21:45+02:00
tags : ["VisualStudio", "Resharper", "unit test"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---

For many years Resharper was the most essential plugin for VisualStudio that makes this IDE very powerful.  Most people who tried Reshaper cannot work in VS without it anymore. If you ever been in a situation when you have to work without R# after trying it (for example you are just after system reinstall or forgot to renew your licence) you probable feel like disable and hitting well know shortcuts without response ends up with frustration. However, recently the situation starts changing, especially after introducing Roslyn as the integral part of the VisualStudio. Visual Studio is getting more and more feature becoming really powerful IDE itself.  And the question that appears recently: do I still need R# to work efficiently with C# projects? I heard it many times so I decide to make a blog post series that try to answer this question. This is the first episode in with I will check the possibilities of Visual Studio with and without Resharper in terms of Unit Testing.


## How to run UT
A few years ago, when I was starting my C# journey, Visual Studio was able to natively run only unit tests based on `MSTest`. If your Unit Test framework of choice was different (for example `NUnit` or `xUnit`) you have use some kind of plugin or external runner to work with your unit tests. Of course, the `Jetbrains` company has spot this market need and enriched R# with NUnit test runner (and later the xUnit too). It certainly helped to popularize the habit of writing unit tests because it made it very convenient without the need of switching to external tools. However, in the meantime `NUnit` and `xUnit` developed adapters which allows you to managed and run your unit test with Visual Studio `Test Explorer`. This adapters are distributed via nuget packages which should be installed to your test projects.


[Running xUnit Test in Visual Studio](https://xunit.github.io/docs/getting-started/netfx/visual-studio)
[NUnit Visual Studio test adapter](https://github.com/nunit/docs/wiki/Visual-Studio-Test-Adapter)


+ net core ??
## Discoverity 
(no code lens on TestFixture)
## Performance
## Code Coverage
## Continous Testing
## Load tests
https://docs.microsoft.com/en-us/visualstudio/test/quickstart-create-a-load-test-project?view=vs-2017
## Profiling

## Summary