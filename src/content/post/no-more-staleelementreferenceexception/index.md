---
title: "No more StaleElementReferenceException"
description: "How to globally handle problem of StaleElementReferenceException in UI tests"
date: 2018-08-08T00:21:18+02:00
tags : ["Selenium", "testing", "ui-tests"]
scripts : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js", "//cdnjs.cloudflare.com/ajax/libs/fitvids/1.2.0/jquery.fitvids.min.js"]
css : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css"]
image: "splashscreen.jpg"
isBlogpost: true
draft: false
---
![splashscreen](splashscreen.jpg)

`StaleElementReferenceException` can be definetely classified as the nightmare no 1 of people who write automated test with Selenium framework. This exception occures when given web element with which we are trying to interact is no longer present in DOM tree. This can be caused by multiple factors, the most often meet are:

- element was removed in the meantime
- element was replace with newer content (for example by `Ajax`)
- element was re-rendered by JavaScript view/template framework

In the first case `StaleElementReferenceException` indicate the real issue - the app is broken or our automated test case is invalid - whereas the last two cases are mostly cause by our UI framework and should't affect our UI test. All of the solution that I've found in the network are based on applying try-catch-retry pattern around the places that where the problem occures. This could degradate readability and maintability. So how to get rid of `StaleElementReferenceException` without introducing technical debt and changing the way we interact with web elements?



## StableWebElement to the rescue!

I got the idea of StableWebElement – a wrapper for `IWebElement` which could detect Stale reference situation and try to find a new reference to the original element. The key element of this wrapper is memoization of searching context (parent element) and locator.  All method for locating WebElement in my test always return StableWebElement wrapper and the problem with StaleObjectReferenceException disappeared.

![stable element relation diagram](stable_element_diagram.jpg)


```csharp
public interface IStableWebElement : IWebElement, ILocatable, ITakesScreenshot, IWrapsElement, IWrapsDriver
{
    void RegenerateElement();
    bool IsStale();
    string GetDescription();
}
```

At first I thought that extending `IWebElement` will be enought, but after running my test suit I encounter a few methods from Selenium that accepts `IWebElement` and perform casting to different interfaces that are not in IWebElement inheritance hierarchy.

The full implementation of `StableWebElement` can be found in `Tellurium` project [here](https://github.com/cezarypiatek/Tellurium/blob/6f3754060f4386e115b40e13ffed5303bd98fc39/Src/MvcPages/SeleniumUtils/StableWebElement.cs)

```csharp
static class StableElementExtensions
{
    public static IStableWebElement FindStableElement(this ISearchContext context, By by)
    {
        var element = context.FindElement(by);
        return new StableWebElement(context, element, by, SearchApproachType.First);
    }    
}
```