---
title: "Scavenging overlooked disposables with code analyzers"
description: "Which analyzer package should I use and how to configure it to avoid most common problems related to disposables."
date: 2020-11-07T16:00:45+02:00
tags : ["dotnet", "csharp", "disposable", "roslyn", "analyzers"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---

TODO: Does it handle new `using var` syntax?
TODO: Handle Async Disposable
TODO: http://joeduffyblog.com/2005/04/08/dg-update-dispose-finalization-and-resource-management/
TODO: https://docs.microsoft.com/en-us/dotnet/standard/garbage-collection/unmanaged
TODO: Other disposable code smells (split init logic from constructor)


FXCop
https://github.com/dotnet/roslyn-analyzers/blob/master/src/Microsoft.CodeAnalysis.FxCopAnalyzers/Microsoft.CodeAnalysis.FxCopAnalyzers.md

CA1001: Types that own disposable fields should be disposable
CA1063: Implement IDisposable Correctly
CA1816: Dispose methods should call SuppressFinalize
CA2000: Dispose objects before losing scope
CA2213: Disposable fields should be disposed
CA2215: Dispose methods should call base class dispose
CA2216: Disposable types should declare finalizer

Roslynator:

RCS1133	Remove redundant Dispose/Close call


CodeCracker

https://code-cracker.github.io/diagnostics.html

CC0029	DisposablesShouldCallSuppressFinalizeAnalyzer
CC0022	DisposableVariableNotDisposedAnalyzer
CC0032	DisposableFieldNotDisposedAnalyzer (Info - method call)
CC0033	DisposableFieldNotDisposedAnalyzer (Warning - object creation)