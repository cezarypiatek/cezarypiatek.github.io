---
title: "No more StaleElementReferenceException"
description: "How to globally handle the problem of StaleElementReferenceException in UI tests"
date: 2018-08-12T00:21:18+02:00
tags : ["Selenium", "testing", "ui-tests", "webdriver"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
draft: false
---
`StaleElementReferenceException` can be definitely classified as the number 1 nightmare of people who write automated tests with Selenium framework. This exception occurs when given web element with which we are trying to interact is no longer present in DOM tree. This can be caused by multiple factors, the most common being:

- an element was removed in the meantime
- an element was replaced with newer content (for example by `Ajax`)
- an element was re-rendered by JavaScript view/template framework

In the first case, `StaleElementReferenceException` indicates the real issue - the app is broken or our automated test case is invalid - whereas the last two cases are mostly caused by UI framework and shouldn't affect our UI test. All of the solutions that I've found in the network are based on applying try-catch-retry pattern around the places where the problem occurs. However, this could degrade readability and maintainability. So how to get rid of `StaleElementReferenceException` without introducing technical debt and changing the way we interact with web elements?

## StableWebElement to the rescue!

I got the idea of `StableWebElement` – a wrapper for `IWebElement` which could detect the situation of stale reference and try to find a new reference to the original element (all this happening behind the scenes). The key element of this wrapper is memoization of searching context (parent element) and locator.  Let's see how it works on example. We have a user list which is a collection of list elements and each list element contains a button to deactivate the user. In order to perform user deactivation, we have to find user list, next find list element that represents given user and at the end, locate deactivation button inside the list element. The code for automating it with `Selenium` can look as follows:

```csharp
[Test]
publicv void should_be_able_to_deactivate_user(RemoteWebDriver webDriver)
{
    var userList = webDriver.FindElement(By.Id("UserList"));
    var userListElement = userList.FindElement(By.XPath("*[2]"));
    var deactivationButton = userListElement.FindElement(By.CssSelector(".deactivate-button"));
    deactivationButton.Click();
}
```

The mapping between UI elements and objects which represent them is showed in the diagram below:

![stable element relation diagram](stable_element_diagram.jpg)


The problem of stale reference can occur at any level of object hierarchy: our deactivate button can be re-rendered or either list element or the whole user list can be replaced with the newer version of HTML. No matter which element was refreshed, StableObjectElement should be able to restore all references necessary to perform intended action.

### Implementing StableWebElement 
I started with defining `IStableWebElement` that enriches `IWebElement` with two additional methods: `IsStale` which detects if the element is affected by stale reference and  `RegenerateElement` which restores the reference to the original element.

```csharp
public interface IStableWebElement : IWebElement, ILocatable, ITakesScreenshot, IWrapsElement, IWrapsDriver
{
    bool IsStale();
    void RegenerateElement();
}
```
At first, I thought that extending `IWebElement` would be enough, but after running my test suit I encountered a few methods from Selenium that accept `IWebElement` and perform casting to different interfaces that are not in the IWebElement inheritance hierarchy.

Now we can create an implementation of our `IStableWebElement` interface:

```csharp
public class StableWebElement: IStableWebElement
{
    private readonly ISearchContext parent;
    private IWebElement element;
    private readonly By locator;

    public StableWebElement(IWebElement elemen, ISearchContext parent, By locator)
    {
        this.parent = parent;
        this.element = element;
        this.locator = locator;
    }
}
```

All the methods and properties from the interfaces extended by `IStableWebElement` should be implemented as a proxy for original methods on the `element` object in the following manner:

```csharp
public void SendKeys(string text)
{
    Execute(() => element.SendKeys(text));
}

public void Click()
{
    Execute(() => element.Click());
}

public bool Displayed 
{ 
    get 
    { 
        return Execute(() => element.Displayed); 
    } 
}
```

All original methods were wrapped in the `Execute` method which is responsible for detecting of `StaleElementReferenceException` during original method invocation. When the exception occurs, we try to restore element reference by invoking `RegenerateElement` and retry the operation. There are two `Execute` methods because we have to wrap methods and functions with them (notice that one returns generic element and the second one returns void):

```cs
private T Execute<T>(Func<T> function)
{
    T result = default (T);
    Execute(() => { result = function(); });
    return result;
}

private void Execute(Action action)
{
    var success = RetryHelper.Retry(3, () =>
    {
        try
        {
            action();
            return true;
        }
        catch (StaleElementReferenceException)
        {
            RegenerateElement();
            return false;
        }
    });
    if (success == false)
    {
        throw new WebElementNotFoundException("Element is no longer accessible");
    }
}
```

And the most interesting part is the `RegenerateElement` method:

```csharp
public void RegenerateElement()
{
    var stableParent = parent as IStableWebElement;
    if (stableParent != null && stableParent.IsStale())
    {
        stableParent.RegenerateElement();
    }
    try
    {
        this.element = this.parent.FindElement(locator);
    }
    catch(Exception ex)
    {
        throw new CannotFindElementByException(locator, parent, ex);  
    }
}
```

At first, we check if our parent (which is our search context) is also affected by stale reference. If this is the case, we perform `RegenerateElement` method on the parent. This creates recursion call and we are able to restore references to the root element (no matter how many parents are in the dependency chain). After we retrieve the reference to the parent, we also need to find a fresh version of the current element using new parent and memorized locator. If any exception occurs during searching for the current element, that means the element truly disappeared and the StaleReferenceException was an indicator of the true problem. The last missing part is the method that detects if the element has a stale reference.


```cs
public bool IsStale()
{
    try
    {
        //INFO: If element is stale accessing any property should throw exception        
        var tagName = this.element.TagName;
        return false;
    }
    catch (StaleElementReferenceException )
    {
        return true;
    }
}
```

### Applying StableWebElement 

In order to use StableWebElement we need to add extension method for `ISearchContext` that searches for given element and wraps it into our StableWebElement proxy:


```csharp
static class StableElementExtensions
{
    public static IStableWebElement FindStableElement(this ISearchContext context, By locator)
    {
        var element = context.FindElement(locator);
        return new StableWebElement(context, element, locator);
    }    
}
```

Now we have to replace all invocation of `FindElement` with our new extension method. If we don't need to be explicit about using this new approach, we can tweak `FindElement` method from our `StableWebElement` wrapper to intercept the real result and wrap it into StableWebElement:

```cs
public IWebElement FindElement(By locator)
{
    var foundElement = Execute(() => element.FindElement(locator));
    return new StableWebElement(this.parent, foundElement, locator);
}
```

This little trick allows us to introduce `StableWebElement` almost transparently into existing codebase with minimal effort. I said "almost" because we still  need to use `FindStableElement` extension method on search context which is `WebDriver` (alternatively, we can create a wrapper for `WebDriver` that uses the same trick as StableWebElement).

> **UPDATE 2020-10-08:** I do not change the logic of `FindElements` method (the one that search for all elements that match a given locator because it could not guarantee the unambiguity during the "regeneration" process)


## Summary

After applying `StableWebElement` in my UI Test the problem of `StaleObjectReferenceException` was completely eliminated. Utilizing the proxy pattern allowed me to introduce the `StableWebElement` with minimal effort, preserving standard Selenium API and keeping the readability of my test code. An attempt of implementation of `StableWebElement` can be found in `Tellurium` project [here](https://github.com/cezarypiatek/Tellurium/blob/6f3754060f4386e115b40e13ffed5303bd98fc39/Src/MvcPages/SeleniumUtils/StableWebElement.cs).

