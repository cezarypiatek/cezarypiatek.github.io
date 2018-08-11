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

In the first case `StaleElementReferenceException` indicate the real issue - the app is broken or our automated test case is invalid - whereas the last two cases are mostly cause by our UI framework and should't affect our UI test. All of the solution that I've found in the network are based on applying try-catch-retry pattern around the places that where the problem occures. However this could degradate readability and maintability. So how to get rid of `StaleElementReferenceException` without introducing technical debt and changing the way we interact with web elements?



## StableWebElement to the rescue!

I got the idea of `StableWebElement` – a wrapper for `IWebElement` which could detect situation of stale reference and try to find a new reference to the original element. (all this happend behind the scene) The key element of this wrapper is memoization of searching context (parent element) and locator.  Let's see how it works on example. We have an users list, which is collection of list elements and each list element contains a button to deactivate the user. In order to perform user deactivation we have to find users list, next we have to find list element that represents given user and at the end we need to located deactivation button inside the list element. The code for automating it with Selenium can looks as follows:

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

Mapping between UI elements and object that represents them is showed on the diagram below:

![stable element relation diagram](stable_element_diagram.jpg)


The problem of stale reference can occure on any level of our object hirerchy: our deactive button could be re-rendered, it's containing list element or the whole user list was replace with the newer version of html.

All method for locating WebElement in my test always return StableWebElement wrapper and the problem with StaleObjectReferenceException disappeared.


### Implementing StableWebElement 


```csharp
public interface IStableWebElement : IWebElement, ILocatable, ITakesScreenshot, IWrapsElement, IWrapsDriver
{
    void RegenerateElement();
    bool IsStale();
    string GetDescription();
}
```

At first I thought that extending `IWebElement` will be enought, but after running my test suit I encounter a few methods from Selenium that accepts `IWebElement` and perform casting to different interfaces that are not in IWebElement inheritance hierarchy.

Now we create and implementation of our `IStableWebElement` interface:

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

All of the methos from the interface should be implemented as a proxy for original methods on the `element` object in the following manner:

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

All original methods were wrapped in `Execute` method which is responsible for detecting of `StaleElementReferenceException` during original method invocation. When the exception occures we try to restore element refrerence by invoking `RegenerateElement` and retry the operation. There are two `Execute` methods because we have to wrap with them methods and functions (notice that one return generic element and the second one return void):

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

At first we check if our parent (which is our search context) is also affected by stale reference. If so we perform `RegenerateElement` method on parent. This creates recursion and we are able to restore reference to the root element (no matter how many parents are on the relation chain). After we retrieve reference to the parent we also need to find fresh version of current element using new parent and memorized locator. If any exception occures during searching current element that means the element truly disappear and the StaleReferenceException was indicator of the true problem. The last missing part is the method that detect if element has stale reference.


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

//TODO: wrap FindElement method


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