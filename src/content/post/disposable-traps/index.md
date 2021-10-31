---
title: "Disposable traps"
description: "TBA"
date: 2019-07-30T00:20:45+02:00
tags : ["csharp", "dotnet", "dotnetcore", "best practices"]
highlight: true

image: "splashscreen.jpg"
isBlogpost: true
---




## Constructing Disposable objects

```cs
class Program
{
    static void Main(string[] args)
    {
        using var x = new MyDisposable();
        Console.WriteLine("Hello World!");
    }
}

class MyDisposable: IDisposable
{
    public void Dispose()
    {
        Console.WriteLine("Disposing");
    }
}
```


Is translated to

```cs
internal class Program
{
    private static void Main(string[] args)
    {
        MyDisposable myDisposable = new MyDisposable();
        try
        {
            Console.WriteLine("Hello World!");
        }
        finally
        {
            if (myDisposable != null)
            {
                ((IDisposable)myDisposable).Dispose();
            }
        }
    }
}
```

As you might see, the instance of `MyDisposable` is created before `try-finally` block. What happens when `MyDisposable` constructor throws an exception? Do you know or do you guess? That's right, the `finally` block won't get executed and the `Dispose` will not be invoked in this case. One can say, ok, the constructor blow up so thing was constructed so there's nothing to clean up. But what if our object manage with other disposable objects?

```cs
internal class MyDisposable : IDisposable
{
    private readonly IDisposable firstResource;
    private readonly IDisposable secondResource;


    public MyDisposable()
    {
        firstResource = new SomeDisposable();
        firstResource.DoSomethingToPrepare(); //This might blow up
        secondResource = new SomeDisposable();
        secondResource.DoSomethingToPrepare(); //This might blow up
    }

    public void Dispose()
    {
        Console.WriteLine("Disposing");
        firstResource.Dispose();
        secondResource.Dispose();
        Console.WriteLine("Disposed");
    }
}
```

The best option is to do as little as possible in the constructors and factory methods as move advance initialization logic that could possibly fail to a separate method like `Init` or `Setup`. Then we can initialize our object in a more safely fashion:

```cs
class Program
{
    static void Main(string[] args)
    {
        using var x = new MyDisposable();
        x.Setup();
        Console.WriteLine("Hello World!");
    }
}

```

Now we have guarantee that the object will be correctly clean up when the `extended initialization` fails:

```cs
internal class Program
{
    private static void Main(string[] args)
    {
        MyDisposable myDisposable = new MyDisposable();
        try
        {
            myDisposable.Setup();
            Console.WriteLine("Hello World!");
        }
        finally
        {
            if (myDisposable != null)
            {
                ((IDisposable)myDisposable).Dispose();
            }
        }
    }
}
```

## Disposing multiple objects

Another problem with disposing multiple resources in a single `Dispose()` method of the owner:


```cs
internal class MyDisposable : IDisposable
{
    private readonly IDisposable firstResource;
    private readonly IDisposable secondResource;


    public MyDisposable()
    {
        firstResource = new SomeDisposable();        
        secondResource = new SomeDisposable();
    }

    public void Dispose()
    {
        Console.WriteLine("Disposing");
        firstResource.Dispose(); // BOOOOOM!!!
        secondResource.Dispose();
        Console.WriteLine("Disposed");
    }
}
```


## Disposable object ownership