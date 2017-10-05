---
title: "Why clicking with Selenium is so hard."
date: 2017-10-05T17:38:18+02:00
tags : ["selenium", "uitests", "webdriver", "ElementNotInteractableException"]
scripts : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js"]
css : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css"]
---
When I browse StackOverflow question tagged with selenium label, a lot of them are related to the problem of clicking on page elements.
It seems to be most trivial task, but cause a lot of problems. Very often invoking Click() action on webelement ends with exceptions (there is a wide range of them). The main reason is that element on which we try to click is not in  "Interactable" state. There is a lot different factors that can cause that situation:

1. Element has zero dimension (width or height is equals to zero).
2. Element is invisible (transparent or hidden).
3. Element is outside the viewport.
4. Element is behind other.
5. ...


There is **ExpectedConditions.ElementToBeClickable** method in Selenium.Support library which at the first glance should solved the problem. So we wait for certain condition to be met before we perform click action.

```cs
internal static void ClickOn(this RemoteWebDriver driver, IWebElement expectedElement)
{
    driver.WaitUntil((d) => ExpectedConditions.ElementToBeClickable(expectedElement));
    expectedElement.Click();
}
```

But sometimes we still get the exception. So let check how ExpectedConditions.ElementToBeClickable method works:

```cs
public static Func<IWebDriver, IWebElement> ElementToBeClickable(IWebElement element)
{
	return (driver) =>
	{
		try
		{
			if (element != null && element.Displayed && element.Enabled)
			{
				return element;
			}
			else
			{
				return null;
			}
		}
		catch (StaleElementReferenceException)
		{
			return null;
		}
	};
}
```
https://github.com/SeleniumHQ/selenium/blob/master/dotnet/src/support/UI/ExpectedConditions.cs

The interesting part is checking element.Displayed flag. What does "Displayed" really mean? Reading webdriver specification (https://w3c.github.io/webdriver/webdriver-spec.html#dfn-element-displayed) we can find this definition

```plaintext
The element displayed algorithm is a boolean state where true signifies that the element is displayed and false signifies that the element is not displayed. To compute the state on element, invoke the Call(bot.dom.isShown, null, element). If doing so does not produce an error, return the return value from this function call. Otherwise return an error with error code unknown error.
```

This doesn't explain exactly what "Displayed" means, but gives us another clue. We have to check **bot.dom.isShown** implementation.
https://github.com/SeleniumHQ/selenium/blob/e09e28f016c9f53196cf68d6f71991c5af4a35d4/javascript/atoms/dom.js#L437

Even thought the code is pretty clear, there is a lot of comments which can help us understand how complex the problem is.
The method documentation comment explain general rules of testing if element is "Displayed"
```plaintext
/**
 * Determines whether an element is what a user would call "shown". This means
 * that the element is shown in the viewport of the browser, and only has
 * height and width greater than 0px, and that its visibility is not "hidden"
 * and its display property is not "none".
 * Options and Optgroup elements are treated as special cases: they are
 * considered shown iff they have a enclosing select element that is shown.
 *
 * Elements in Shadow DOMs with younger shadow roots are not visible, and
 * elements distributed into shadow DOMs check the visibility of the
 * ancestors in the Composed DOM, rather than their ancestors in the logical
 * DOM.
 *
 * @param {!Element} elem The element to consider.
 * @param {boolean=} opt_ignoreOpacity Whether to ignore the element's opacity
 *     when determining whether it is shown; defaults to false.
 * @return {boolean} Whether or not the element is visible.
 */
 bot.dom.isShown = function(elem, opt_ignoreOpacity)
 ```

 And everything seems so true, except that I was unable to find code which is responsible for checking if element is inside current viewport (maybe there another layer of proxy methods specific to given driver implementation). Another problem is that this code doesn't cover scenario when our click target element is behind the others. This could be easily detected with javascript
 
 ```cs
static bool IsElementInteractable(this RemoteWebDriver driver, IWebElement element)
{
	return (bool)driver.ExecuteScript(@"
		return (function(element)
		{
			function belongsToElement(subElement)
			{
				return element == subElement || element.contains(subElement);
			}
			var rec = element.getBoundingClientRect();                        
			var elementAtPosition = document.elementFromPoint(rec.left+rec.width/2, rec.top+rec.height/2);                        
			return belongsToElement(elementAtPosition);
		})(arguments[0]);                    
	", element);
}
 ```
 
Unfortunately some drivers has problem with **document.elementFromPoint** and inline elements so I've added checks of additional two points
 
 
```cs
static bool IsElementInteractable(this RemoteWebDriver driver, IWebElement element)
{
	return (bool)driver.ExecuteScript(@"
		return (function(element)
		{
			function belongsToElement(subElement)
			{
				return element == subElement || element.contains(subElement);
			}
			var elementAtPosition1 = document.elementFromPoint(rec.left, rec.top);
			var elementAtPosition2 = document.elementFromPoint(rec.left+rec.width/2, rec.top+rec.height/2);
			var elementAtPosition3 = document.elementFromPoint(rec.left+rec.width/3, rec.top+rec.height/3);
			return belongsToElement(elementAtPosition1) || belongsToElement(elementAtPosition2) || belongsToElement(elementAtPosition3);
		})(arguments[0]);                    
	", element);
}
 ```
It seems that *document.elementFromPoint(rec.left, rec.top)* should solve the problem by itself, but it doesn't work when element has rounded corners. This implementation is not perfect but gives a high level of confidence.

O right, when we puts this all together and handle also the scenario when element is outside the viewport (some browser can handle this automatically) we can ends up with implementation as follows

 
```cs
static void ClickOn(this RemoteWebDriver driver, IWebElement expectedElement)
{
	try
	{
		driver.WaitUntil((d) => ExpectedConditions.ElementToBeClickable(expectedElement));
		expectedElement.Click();
	}
	catch (Exception ex)
	{
		if (IsTerminatingException(ex))
		{
			throw;
		}

		var originalViewportPosition = driver.ScrollViewportToElement(expectedElement);
	   
		try
		{
			driver.WaitUntil((d) => driver.IsElementInteractable(expectedElement));
		}
		catch (WebDriverTimeoutException)
		{
			throw new ElementIsNotClickableException(expectedElement);
		}
		
		expectedElement.Click();
		originalViewportPosition.Restore();
	}
}
```
 
 ... and the supporting methods
 
 
```csharp
 
public static TResult WaitUntil<TResult>(this RemoteWebDriver driver, Func<IWebDriver, TResult> waitPredictor, int timeout=SeleniumFinderExtensions.SearchElementDefaultTimeout)
{
	var waiter = new WebDriverWait(driver, TimeSpan.FromSeconds(timeout));
	return waiter.Until(waitPredictor);
}
 
private static bool IsTerminatingException(Exception ex)
{
	return ex is InvalidOperationException == false  && ex is WebDriverException == false;
}

private static ViewPortPosition ScrollViewportToElement(this RemoteWebDriver driver, IWebElement expectedElement)
{
	int? originalScrollPosition = null;
	if (expectedElement.Location.Y > driver.GetWindowHeight())
	{
		originalScrollPosition = driver.GetScrollY();
		driver.ScrollToY(expectedElement.Location.Y + expectedElement.Size.Height);
	}
	return new ViewPortPosition(originalScrollPosition, driver);
}

private static int GetWindowHeight(this RemoteWebDriver driver)
{
	return (int)(long)driver.ExecuteScript("return window.innerHeight");
} 

private static int GetScrollY(this RemoteWebDriver driver)
{
	return (int)(long)driver.ExecuteScript(@"
		if(typeof window.scrollY != 'undefined'){
			return window.scrollY;
		}else if(typeof document.documentElement.scrollTop != 'undefined'){
			return document.documentElement.scrollTop;
		}
		return 0;
");
}

public class ViewPortPosition
{
	private readonly int? scrollPositionY;
	private readonly RemoteWebDriver webDriver;

	public ViewPortPosition(int? scrollPositionY, RemoteWebDriver webDriver)
	{
		this.scrollPositionY = scrollPositionY;
		this.webDriver = webDriver;
	}

	public void Restore()
	{
		if (scrollPositionY != null)
		{
			webDriver.ScrollToY(scrollPositionY.Value);
		}
	}
}
 ```