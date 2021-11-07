---
title: "Disposable traps"
description: "TBA"
date: 2021-11-07T00:20:45+02:00
tags : ["csharp", "dotnet", "dotnetcore", "best practices"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---


.NET Framework allows writing `managed code` which means there's a mechanism called Garbage Collector responsible for automatic memory management. However, on the daily basis, we need to deal with a variety of resources - not only the memory. Some of them might require special treatment, especially they need to be cleaned up or released after they are no longer needed. This clean-up is very important because, like in the real world, the resources are limited and without proper management, they might run out. The C# language provides another mechanism that facilitates our work with this kind of resources - of course, I'm talking here about `disposable resources`.  Thanks to the `using` keyword we can ensure automatic resource disposal at the end of a given scope of everything that implements `IDisposable` interfaces (for asynchronous disposal there are `await using` and `IAsyncDisposable` counterparts). However, this simple mechanism when improperly use or without appropriate attention still might allow for resource leakage. In this blog post, I would like to discuss a few recurring anti-patterns that I came across while dealing with `IDisposable`. They are mostly a result of insufficient attention or the lack of proper understanding of how `IDisposable` works.


## Designing constructors of disposable objects

I would like to start from reminding how the `using` keyword works. It's actually a syntactic sugar which is translated into appropriate `try-finally` blocks. The following sample code:

```cs
class Program
{
    static void Main(string[] args)
    {
        using var x = new MyDisposable();
        Console.WriteLine("Hello World!");
    }
}
```

Is translated to:

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

The important thing to remember here is the fact, that the object creation takes places before the `try` block. If the constructor invocation throws an exception, then the `Dispose` method won't get invoked. We should take it under consideration while we implement the constructor of object that represent a disposable resource or is a decorator/wrapper/aggregator for other disposables. Let's take as an example the constructor of the following object:

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
        //TODO: Dispose all disposable members
    }
}
```

If the invocation of `DoSomethingToPrepare()` blows up, then we are at the risk of leading the already created resources. The best option is to do as little as possible in the constructors and move advance initialization logic that could possibly fail to a separate method like `Init` or `Setup`. Especially the allocation of the actual resources should be moved from the constructor to this dedicated method. Then we can initialize our object in a more safely fashion with a guarantee of proper disposal:

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

    public void Setup()
    {
        firstResource.DoSomethingToPrepare();
        secondResource.DoSomethingToPrepare();
    }

    public void Dispose()
    {
        //TODO: Dispose all disposable members
    }
}

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

## Designing factories for disposable objects

Take a look at `CA2000` rule

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


What if the factory composes an object that consists of multiple disposable objects?


```cs
public ResourceManager Create()
{
    var resources1 = new  DisposableResource1();
    var resources2 = new  DisposableResource2();
    var resources3 = new  DisposableResource3();
    return new ResourceManager(resources1, resources2, resources3)
}
```

There's a hazard that something blows up between creating first resource and creating `ResourceManager`, but we can't define those intermediate object with `using` because they get disposed at the moment of returning from this method.

```cs
public class ControlledScopeDisposable<T> : IDisposable where T : IDisposable
{
    public T UnderlyingResource { get; private set; }

    public ControlledScopeDisposable(T underlyingResource)
    {
        UnderlyingResource = underlyingResource;
    }

    public T Dispossess()
    {
        var dispossessed = UnderlyingResource;
        UnderlyingResource = default;
        return dispossessed;
    }

    public void Dispose()
    {
        UnderlyingResource?.Dispose();
    }
}

public static class ControlledScopeDisposableExtensions
{
    public static ControlledScopeDisposable<T> ToControlledScope<T>(this T resource) where T : IDisposable
    {
        return new ControlledScopeDisposable<T>(resource);
    }
}
```

Now we can increase our level of confidence as follows:

```cs
public ResourceManager Create()
{
    using var resources1 = new MyDisposable().ToControlledScope();
    using var resources2 = new MyDisposable().ToControlledScope();
    using var resources3 = new MyDisposable().ToControlledScope();
    return new ResourceManager(resources1.Dispossess(), resources2.Dispossess(), resources3.Dispossess());
}
```



Or to protect from situation when `ResourceManager` might throw an exception, we should actually do this in the following way:


```cs
public ResourceManager Create()
{
    using var resources1 = new MyDisposable().ToControlledScope();
    using var resources2 = new MyDisposable().ToControlledScope();
    using var resources3 = new MyDisposable().ToControlledScope();
    var resourceManager = new ResourceManager(resources1.UnderlyingResource, resources2.UnderlyingResource, resources3.UnderlyingResource);
    _ = resources1.Dispossess();
    _ = resources2.Dispossess();
    _ = resources3.Dispossess();
    return resourceManager;
}
```

I don't want you to use this decorator but I would like to remember a potential problems with instantiating multiple disposable resources in a factory methods and pay attention for it during writing and reviewing code.

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

Example from `StreamReader`


```cs
protected override void Dispose(bool disposing)
{
    if (_disposed)
    {
        return;
    }
    _disposed = true;

    // Dispose of our resources if this StreamReader is closable.
    if (_closable)
    {
        try
        {
            // Note that Stream.Close() can potentially throw here. So we need to 
            // ensure cleaning up internal resources, inside the finally block.  
            if (disposing)
            {
                _stream.Close();
            }
        }
        finally
        {
            _charPos = 0;
            _charLen = 0;
            base.Dispose(disposing);
        }
    }
}
```

Example from `BufferedStream`

```cs
protected override void Dispose(bool disposing)
{
    try
    {
        if (disposing && _stream != null)
        {
            try
            {
                Flush();
            }
            finally
            {
                _stream.Dispose();
            }
        }
    }
    finally
    {
        _stream = null;
        _buffer = null;

        // Call base.Dispose(bool) to cleanup async IO resources
        base.Dispose(disposing);
    }
}
```

There could be one more interesting case: what if the `_stream.Dispose()` throws an exception and the `base.Dispose()` throws as well?


The dispose method should be designed in a way that allows to call it safely multiple times. As you might see at the provided examples, `Stream` decorators calls `Dispose` on the underlying resources so in code like the one bellow, Dispose of the first stream might be called up to twice:

```cs
using (Stream netStream = new NetworkStream(clientSocket, true))
{
    using (Stream bufStream = new BufferedStream(netStream, streamBufferSize))
    {

    }
}
```

Here's the implementation of `NetworkStream`

```cs
private volatile bool _cleanedUp = false;

protected override void Dispose(bool disposing)
{
#if DEBUG
    using (DebugThreadTracking.SetThreadKind(ThreadKinds.User))
    {
#endif
        // Mark this as disposed before changing anything else.
        bool cleanedUp = _cleanedUp;
        _cleanedUp = true;
        if (!cleanedUp && disposing)
        {
            // The only resource we need to free is the network stream, since this
            // is based on the client socket, closing the stream will cause us
            // to flush the data to the network, close the stream and (in the
            // NetoworkStream code) close the socket as well.
            _readable = false;
            _writeable = false;
            if (_ownsSocket)
            {
                // If we own the Socket (false by default), close it
                // ignoring possible exceptions (eg: the user told us
                // that we own the Socket but it closed at some point of time,
                // here we would get an ObjectDisposedException)
                _streamSocket.InternalShutdown(SocketShutdown.Both);
                _streamSocket.Close(_closeTimeout);
            }
        }
#if DEBUG
    }
#endif
```

The `_cleanedUp` variable guarantee that the `Dispose` can be called safely multiple times.



## How to instantiate disposable resource


Option 1

```cs
using (Stream netStream = new NetworkStream(clientSocket, true))
{
    using (Stream bufStream = new BufferedStream(netStream, streamBufferSize))
    {

    }
}
```

The first pair of `{}` can be omitted:

```cs
using (Stream netStream = new NetworkStream(clientSocket, true)) 
using (Stream bufStream = new BufferedStream(netStream, streamBufferSize))
{

} 
```

Or it's valid to define multiple resources within a single `using`

```cs
using (Stream netStream = new NetworkStream(clientSocket, true),
       bufStream = new BufferedStream(netStream, streamBufferSize))
{

} 
```

Sometimes we can across the code why somebody tried to simplified the code and instantiate the first stream inline withing the constructor invocation of the second stream:

```cs
using (Stream bufStream = new BufferedStream(new NetworkStream(clientSocket, true), streamBufferSize))
{

} 
```

But this simplification can be dangerous. WHen the constructor invocation blows up, then the first resource won't get disposed.

Example from `NetworkStream` constructor

```cs
public NetworkStream(Socket socket, FileAccess access, bool ownsSocket)
{
#if DEBUG
    using (DebugThreadTracking.SetThreadKind(ThreadKinds.User))
    {
#endif
        if (socket == null)
        {
            throw new ArgumentNullException(nameof(socket));
        }
        if (!socket.Blocking)
        {
            throw new IOException(SR.net_sockets_blocking);
        }
        if (!socket.Connected)
        {
            throw new IOException(SR.net_notconnected);
        }
        if (socket.SocketType != SocketType.Stream)
        {
            throw new IOException(SR.net_notstream);
        }

        _streamSocket = socket;
        _ownsSocket = ownsSocket;

        switch (access)
        {
            case FileAccess.Read:
                _readable = true;
                break;
            case FileAccess.Write:
                _writeable = true;
                break;
            case FileAccess.ReadWrite:
            default: // assume FileAccess.ReadWrite
                _readable = true;
                _writeable = true;
                break;
        }
#if DEBUG
    }
#endif
}
```

As you can see, based on the state of the provided `Socket` instance, the constructor might throw an exception.



## Disposable object ownership

Who's responsible for the object when

- it's passed to method
- it's passed to the constructor
- it's returned from the factory method

By default `StreamReader` is disposing underlying stream. This might be obvious/expected behavior or not but it's not clearly express by the constructor signature. There's a constructor overload allowing to override this behavior but the one that accepts only stream doeasn't manifaste this behavior in any way

```cs
public StreamReader(Stream stream, Encoding? encoding = null, bool detectEncodingFromByteOrderMarks = true, int bufferSize = -1, bool leaveOpen = false)
```