---
title: "The art of designing exceptions"
description: "Skip the boring part of the CQRS with Resharper snippets."
date: 2018-10-14T00:20:45+02:00
tags : ["exceptions", "architecture"]
scripts : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js", "//cdnjs.cloudflare.com/ajax/libs/fitvids/1.2.0/jquery.fitvids.min.js"]
css : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css"]
image: "splashscreen.jpg"
isBlogpost: true
---

Have you ever been in the situation when discovered in logs exception force you to spend the next couple of minutes or even hours figuring out what exactly went wrong? The message was very cryptic and the only useful information that guides you to the crime scene was a stack trace. But after arriving there you still have no idea what really happened and what is the culprit. And the most frustrating part is that in many cases the reason is very trivial and could be diagnosed immediately if the error message contains sufficient information. Sounds familiar? I was in this situation many times before, especially when I was working with 3rd party libraries. In this blog post, I would like to share with you my thoughts and experience related to designing exception.


## Official guideline

First of all, there is a chapter in [Framework Design Guideline](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/index) devoted to [Design Guidelines for Exceptions](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/exceptions) which every .net developer should get familiar with. There are three main sections which cover the subject of:

- [Exception Throwing](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/exception-throwing) 

- [Using Standard Exception Types](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/using-standard-exception-types)

- [Exceptions and Performance](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/exceptions-and-performance) 

Obeying this guideline should at some point make our life easier but there are also areas for more improvement especially in terms of information which should be included in the exception.


## ArgumentException
Let's take a look at `ArgumentException` which comes from the standard library and is used for notifying about invalid parameters.  We have the following constructors on our disposal:

```csharp
public ArgumentException()
public ArgumentException(string message, Exception innerException)
public ArgumentException(string message, string paramName)
public ArgumentException(string message, string paramName, Exception innerException)
```

and the most useful overloads are those which acceptes `parameterName`. When we try to throw this exception we've got the following message:

```plaintext
Here comes the 'message` parameter value
Parameter name: args
```
Despite the `message` parameter value (first line of the exception message) the first question that comes to our mind is `What was the value of invalid argument?`. Now it's our responsibility to provider comprehensive explanation and current value everytime when we throw exception for given validation. A better approach would be own in our codebase a helper function that accepts also argument value and produce exception that explain current situation:

```csharp
public class Fail
{
    [Pure]
    public static ArgumentException BecauseArgumentXXX<T>(string argumentName, T argumentValue)
    {        
        return new ArgumentException($"Here comes the explanation why the '{argumentName}' argument with value '{argumentValue}' is invalid");
    }
}
```

Where the `XXX` is the reason why the argument was invalid. This solution take off the burden of making up the exception message everytime and enforce the need of providing argument current value. If there is a requirement for internationalization you can easily move the exception message to the resource file (remember about converting string interpolation into `string.Format`);

### ArgumentOutOfRangeException - numeric values

One of the BCL exceptions that specify the reason for invalid parameter is `ArgumentOutOfRangeException`. The situation is a litte bit better than in `ArgumentException` case base as we see below there is a constructor overload that accept `parameterName` as well as `actualValue`:

```csharp
public ArgumentOutOfRangeException()
public ArgumentOutOfRangeException(string paramName)
public ArgumentOutOfRangeException(string paramName, string message)
public ArgumentOutOfRangeException(string message, Exception innerException)
public ArgumentOutOfRangeException(string paramName, object actualValue, string message)
```

The message produce by this overload looks as follows (the first line comes from `message` parameter):

```plaintext
Age out of allowed range
Parameter name: age
Actual value was 120.
```
Seeing this message we immediately start asking questions: "Why this age value is invalid?", "What are the limitation for this value"? Ofcouse I could provide all that information everytime would be a very tedious.
A better soulution would be a intoducing an interface that allows to check if given value falls into allowed range, Objects that implement this interface can be use to verify given value correctnes and also can be pass to exception factory in case when we want to inform about exceeding the allowed range:


```csharp

public interface IRange<in T>
{
    bool Contains(T value);
    string GetDescription();
}

public class Fail
{
    [Pure]
    public static ArgumentOutOfRangeException BecauseArgumentOutOfRange<T>(
        T value,
        string argumentName, 
        IRange<T> allowedRange
    )
    {
        var rangeDescription = allowedRange.GetDescription();
        return new ArgumentOutOfRangeException($"Parameter '{argumentName}' with value '{value}' was outside the allowed range '{rangeDescription}'");
    }
}
```

A sample implementation and usage of `IRange<>` can looks as follows:

```csharp
public class OpenRange<T>:IRange<T> where T:IComparable<T>
{
    private readonly T min;
    private readonly T max;

    public OpenRange(T min, T max)
    {
        this.min = min;
        this.max = max;
    }

    public bool Contains(T value) => value.CompareTo(min) > 0 && value.CompareTo(max) < 0;

    public string GetDescription() => $"({min}) - {max})"
}


public class BonusCalculator{
    
    private static IRange<int> allowedAgeRange = new  OpenRange<int>(20, 60);

    public int CalculatePointsForAge(int age){
        if(allowedAgeRange.Contains(age) == false)
        {
            throw Fail.BecauseArgumentOutOfRange(age, nameof(age), allowedAgeRange);
        }
        //TODO: Implement calculation logic
    }
}

```

As we see `IRange<>` help us improve code readibility, reduce the duplication of information about the allowed range and facilitate throwing exception.
Actually this solution is not limited to the classical numeric ranges. You can have a class that implements `IRange<string>` and verify if given value belogs to predefined set of strings. Just remember to compose appropiate description in `GetDescription()` method.


## ArgumentOutOfRange - enum values

The special situation when we what to use `ArgumentOutOfRange` is `default` case in `switch` statement for enum values. Here is the default code generated by Resharper for `switch` over a enum variable:

```csharp
private void DoSomething(SampleEnum option)
{
    switch (option)
    {
        case SampleEnum.Option1:
            break;
        case SampleEnum.Option2:
            break;
        default:
            throw new ArgumentOutOfRangeException(nameof(option), option, null);
    }
}
```

When we run this function with enum value that is not covered in `case` section we got the exception with following message:

```plaintext
Exception of type 'System.ArgumentOutOfRangeException' was thrown.
Parameter name: option
Actual value was Option3.
```

At first glance, it is not so obvious what went wrong. It could be even more cryptic when the value was a nullable type:

```plaintext
Exception of type 'System.ArgumentOutOfRangeException' was thrown.
Parameter name: option
Actual value was null.
```

In order to make it much easier to diagnose we can add a dedicated helper that construct exception explaining what really happend:


```csharp
public class Fail
{
    [Pure]
    public static ArgumentOutOfRangeException BecauseEnumOutOfRange<T>(string argumentName, T value)
    {
        var enumType = typeof(T);
        var message = $"Unsupported '{argumentName}' enum value: {value} ({enumType.Name})";
        return new ArgumentOutOfRangeException(argumentName, value, message);
    }
}
```


```csharp
private void DoSomething(SampleEnum option)
{
    switch (option)
    {
        case SampleEnum.Option1:
            break;
        case SampleEnum.Option2:
            break;
        default:
            throw Fail.BecauseEnumOutOfRange(nameof(option), option);
    }
}
```


## DateTime example

```csharp
public DateTime(int year, int month, int day, int hour, int minute, int second, int millisecond, DateTimeKind kind)
{
    if (millisecond < 0 || millisecond >= 1000)
    throw new ArgumentOutOfRangeException(nameof (millisecond), Environment.GetResourceString("ArgumentOutOfRange_Range", (object) 0, (object) 999));
    switch (kind)
    {
    case DateTimeKind.Unspecified:
    case DateTimeKind.Utc:
    case DateTimeKind.Local:
        long num = DateTime.DateToTicks(year, month, day) + DateTime.TimeToTicks(hour, minute, second) + (long) millisecond * 10000L;
        if (num < 0L || num > 3155378975999999999L)
        throw new ArgumentException(Environment.GetResourceString("Arg_DateTimeRange"));
        this.dateData = (ulong) (num | (long) kind << 62);
        break;
    default:
        throw new ArgumentException(Environment.GetResourceString("Argument_InvalidDateTimeKind"), nameof (kind));
    }
}
```

```csharp

private static IRange<int> miliseondAllowedRange = new LeftOpenRightClosedRange<int>(0, 1000);
private static IRange<long> magicNumAllowedRange = new OpenRange<long>(0L, 3155378975999999999L);

public DateTime(int year, int month, int day, int hour, int minute, int second, int millisecond, DateTimeKind kind)
{
    if (miliseondAllowedRange.Contains(millisecond) == false)
    {
        throw Fail.BecauseArgumentOutOfRange(nameof(millisecond), millisecond, miliseondAllowedRange)       
    }
    switch (kind)
    {
        case DateTimeKind.Unspecified:
        case DateTimeKind.Utc:
        case DateTimeKind.Local:
            long num = DateTime.DateToTicks(year, month, day) + DateTime.TimeToTicks(hour, minute, second) + (long) millisecond * 10000L;
            if (magicNumAllowedRange.Contains(num) == false)
            {
                throw Fail.BecauseArgumentOutOfRange(nameof(num), num, magicNumAllowedRange);
            }
            
            this.dateData = (ulong) (num | (long) kind << 62);
            break;
        default:
           throw Fail.BecauseEnumOutOfRange(nameof(option), option);;
    }
}
```

### FileNotFoundException



```csharp
public FileNotFoundException()
public FileNotFoundException(string message)
public FileNotFoundException(string message, Exception innerException)
public FileNotFoundException(string message, string fileName)
public FileNotFoundException(string message, string fileName, Exception innerException)
```

Thoses are the public constructor for `FileNotFoundException`. The three first should be forbidden. The only useful versions are these ones which accepts `fileName` parameter but there is still missing crucial information - "Where the file was looking for?". In order make diagnostic less painful we can introduce a helper which accepts `fileName` as well as list of potential locations and produce exception with comprehensive message:


```csharp
public static class Fail
{
    [Pure]
    public static FileNotFoundException BecauseMissingFile(string fileName, params string[] locations)
    {
        var combinedLocations = string.Join(",", locations);
        return new FileNotFoundException($"Cannot find file '{fileName}' at locations: {combinedLocations}")
    }
}
```

## Missing context information

//TODO: Passing context - catching and rethrow

Of courcse there are situation when we cannot reveal in exception too much information for example for security reasons or we don't want to overhelm user with technical details.

## [Pure] attribute

All of my exception factory methods were decorated with `[Pure]` attribute. This attribute comes from [JetBrains.Annotations](https://www.nuget.org/packages/JetBrains.Annotations/) nuget package and it is intendent to mark [pure functions](https://en.wikipedia.org/wiki/Pure_function) - the functions which have no side effects. If you are using `Resharper` and have enabled `Solution wide analysis` this attribute can save you a lot of troubles when you forget to add `throw` keyword before exception factory method invocation:

![missing throw keyword example](missing_throw.jpg)

You can read more about `Resharper code annotations` in my "[Hunt your bugs in design time](post/hunt-your-bugs-design-time/)" article.


## Summary
Everytime when you are writing `throw` statement think about people who could find this exception in logs and what question they could ask. The good exception message is the one that explain in comprehensinve way what exactly conditions took place which cause this exceptional situation. There is no need to ask any question to figure out what happend. An appropiate exception design allows to save a lot of time consumers of your libraries, people who take over the support or even you too. 

### Call for action
I am curious **what was the most misterious exception that you have ever encounter** and how much time did it take to solve the riddle? Please share your experience in the comment section down below.