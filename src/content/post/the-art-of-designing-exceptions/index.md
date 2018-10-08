---
title: "The art of designing exceptions"
description: "Skip the boring part of the CQRS with Resharper snippets."
date: 2018-10-06T00:20:45+02:00
tags : ["exceptions", "architecture"]
scripts : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js", "//cdnjs.cloudflare.com/ajax/libs/fitvids/1.2.0/jquery.fitvids.min.js"]
css : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css"]
image: "splashscreen.jpg"
isBlogpost: true
---

Have you ever been in the situation when discovered in logs exception force you to spend the next couple of minutes or even hours figuring out what exactly went wrong? The message was very cryptic and the only useful information that guides you to the crime scene was a stack trace. But after arriving there you still have no idea what really happened and what is the culprit. And the most frustrating part is that in many cases the reason is very trivial and could be diagnosed immediately if the error message contains sufficient information. Sounds familiar? I was in this situation many times before, especially when I was working with 3rd party libraries. In this blog post, I would like to share with you my thoughts and experience related to designing exception.


First of all, there is a chapter in [Framework Design Guideline](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/index) devoted to [Design Guidelines for Exceptions](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/exceptions) which every .net developer should get familiar with. There are three main sections which cover the subject of:

- [Exception Throwing](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/exception-throwing) 

- [Using Standard Exception Types](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/using-standard-exception-types)

- [Exceptions and Performance](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/exceptions-and-performance) 

Obeying this guideline should at some point make our life easier but there are also areas for more improvement especially in terms of information which should be included in the exception.

Let's take a look at `ArgumentException` which comes from the standard library and is used for notifying about invalid parameters.  We have the following constructors:

```csharp
public ArgumentException()
public ArgumentException(string message, Exception innerException)
public ArgumentException(string message, string paramName, Exception innerException)
public ArgumentException(string message, string paramName)
```

and the most useful version are those which acceptes `parameterName`. When we throw this exception we've got the following message

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
TODO
- argument exception
- enum exception
- argument out of range exception

### ArgumentOutOfRangeException

```csharp
public ArgumentOutOfRangeException()
public ArgumentOutOfRangeException(string paramName)
public ArgumentOutOfRangeException(string paramName, string message)
public ArgumentOutOfRangeException(string message, Exception innerException)
public ArgumentOutOfRangeException(string paramName, object actualValue, string message)
```

```csharp

public interface IRange<in T>
{
    bool Contains(T value);
}

public class Fail
{
    public ArgumentOutOfRangeException BecauseArgumentOutOfRange<T>(string argumentName, T value, IRange<T> allowedRange)
    {
        return new ArgumentOutOfRangeException($"Parameter '{argumentName}' with value '{value}' was outside the allowed range '{allowedRange}'");
    }
}
```


```csharp

private static IRange<int> miliseondAllowedRange = new LeftClosedRightOpenRange<int>(0, 1000);
private static IRange<long> magicNumAllowedRange = new ClosedRange<long>(0L, 3155378975999999999L);

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
            throw new ArgumentException(Environment.GetResourceString("Argument_InvalidDateTimeKind"), nameof (kind));
    }
}
```




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

    public bool Contains(T value)
    {
        return value.CompareTo(min) > 0 && value.CompareTo(max) < 0;
    }

    public override string ToString()
    {
        return $"({min}) - {max})";
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


- passing context - catching and rethrow


Of courcse there are situation when we can not reveal in exception too much information for example for security reasons or we don't want to overhelm user with technical details.


## Summary
Everytime when you are writing `throw` statement think about people who could find this exception in logs and what question they could ask. The good exception message is the one that explain in comprehensinve way what exactly conditions took place which cause this exceptional situation. There is no need to ask any question to figure out what happend.