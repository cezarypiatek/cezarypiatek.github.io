---
title: "The Magical Methods in C#"
description: "Methods with specific signature which have a special support in C#"
date: 2020-06-30T00:08:00+02:00
tags : ["c#", "protobuf", "linq"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---

There's a certain set of special method signatures in C# which have particular support on the language level.
Methods with those signatures allow for using a special syntax which has several benefits. For example, we can use them to simplify our code or create `DSL` to express a solution to our domain-specific problem in a much cleaner way. I came across those methods in different places, so I decided to create a blog post to summarize all my discoveries on this subject.

## Collection initialization syntax

[Collection initializer](https://docs.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/object-and-collection-initializers#collection-initializers) is a quite old feature, as it exists in the language since version 3 (released in late 2007). Just as a reminder, `Collection initializer` allows for pre-populating a list by providing elements inside the block statement:

```csharp
var list = new List<int> { 1, 2, 3};
```

This translates simply to the following list of statements:

```csharp
var list = new List<int>();
list.Add(1);
list.Add(2);
list.Add(3);
```

`Collection initializer` is not characteristic only for arrays and collection types from `BCL` but can be used with any type meeting the following conditions:

- Implements `IEnumerable` interface
- Declares method with `void Add(T item)` signature


```csharp
public class CustomList<T>: IEnumerable
{
    public IEnumerator GetEnumerator() => throw new NotImplementedException();
    public void Add(T item) => throw new NotImplementedException();
}
```

We can add support for `Collection initializer` to existing types by defining the `Add` method as an extension method:

```cs
public static class ExistingTypeExtensions
{
    public static void Add<T>(ExistingType @this, T item) => throw new NotImplementedException();
}
```

This syntax can be also used to insert elements into the collection field without accessible setter in initialization block:

```cs
class CustomType
{
    public List<string> CollectionField { get; private set; }  = new List<string>();
}

class Program
{
    static void Main(string[] args)
    {
        var obj = new CustomType
        {
            CollectionField = 
            {
                "item1",
                "item2"
            }
        };
    }
}

```

`Add` method can have more than one parameter:

```csharp
public class CustomList<T>: IEnumerable
{
    public IEnumerator GetEnumerator() => throw new NotImplementedException();
    public void Add(T item, string extraParam1, int extraParam1) => throw new NotImplementedException();
}
```

To use this overload inside the initialization block we need to wrap all parameters in extra pair of curly braces:

```cs
var obj = new CustomType
{
    CollectionField = 
    {
        {"item1", "extraParamVal1", 2 },
        {"item2", "extraParamVal2", 3 }
    }
};
```

`Collection initializer` is quite often used to initialize collection with a well known number of items, but we can utilize it to set up collection with a dynamic number of elements. In both cases the syntax is identical:

```cs
var obj = new CustomType
{
    CollectionField = 
    {
       existingItems
    }
};
```
This is possible for types which meet the following conditions:

- Implements `IEnumerable` interface
- Declares method with `void Add(IEnumerable<T> items)` signature

```csharp
public class CustomList<T>: IEnumerable
{
    public IEnumerator GetEnumerator() => throw new NotImplementedException();
    public void Add(IEnumerable<T> items) => throw new NotImplementedException();
}
```

Unfortunately, array type and collections from `BCL` don't implement `void Add(IEnumerable<T> items)` method, but we could easily change that by defining an extension method for the existing collection types:

```cs
public static class ListExtensions
{
    public static void Add<T>(this List<T> @this, IEnumerable<T> items) => @this.AddRange(items);
}

```

Thanks to this extension method it's now possible to write code which looks as follows:

```cs
var obj = new CustomType
{
    CollectionField = 
    {
        existingItems.Where(x => /*Filter items*/) .Select(x => /*Map items*/) 
    }
};
```

or even compose the resulting collection from the mix of individual elements and results of multiple `enumerables`:

```cs
var obj = new CustomType
{
    CollectionField = 
    {
        individualElement1,
        individualElement2,
        list1.Where(x => /*Filter items*/) .Select(x => /*Map items*/),
        list2.Where(x => /*Filter items*/) .Select(x => /*Map items*/)
    }
};
```
Without this syntax, it would be very hard to achieve a similar result inside the initialization block.


I've discovered this language feature by accident while working with mappings for types with collection fields generated from `protobuf` contracts. For those of you who are not familiar with `protobuf`, if you are using [grpctools](https://developers.google.com/protocol-buffers/docs/reference/csharp-generated) to generate dotnet types from `proto` files, all collection fields are generated as follows:

```cs
[DebuggerNonUserCode]
public RepeatableField<ItemType> SomeCollectionField
{
    get
    {
        return this.someCollectionField_;
    }
}
```

As you can see, collection fields in generated code don't have a setter, but a blessing in disguise, [RepeatableField<T>](https://developers.google.com/protocol-buffers/docs/reference/csharp/class/google/protobuf/collections/repeated-field-t-) implements [void Add(IEnumerable<T> items)](https://developers.google.com/protocol-buffers/docs/reference/csharp/class/google/protobuf/collections/repeated-field-t-#class_google_1_1_protobuf_1_1_collections_1_1_repeated_field_3_01_t_01_4_1a6d0e9efbac818182068afae48b8d4599) so we can still initialize them inside the initialization block:

```cs
/// <summary>
/// Adds all of the specified values into this collection. This method is present to
/// allow repeated fields to be constructed from queries within collection initializers.
/// Within non-collection-initializer code, consider using the equivalent <see cref="AddRange"/>
/// method instead for clarity.
/// </summary>
/// <param name="values">The values to add to this collection.</param>
public void Add(IEnumerable<T> values)
{
    AddRange(values);
}
```

## Dictionary initialization syntax

One of the cool features introduced in C# 6 was [Index initializers](https://docs.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-6#initialize-associative-collections-using-indexers) which simplified syntax for dictionary initialization. Thanks to that we can write dictionary init code in a much more readable way:

```cs
var errorCodes = new Dictionary<int, string>
{
    [404] = "Page not Found",
    [302] = "Page moved, but left a forwarding address.",
    [500] = "The web server can't come out to play today."
};
```
This code is translated to:

```cs
var errorCodes = new Dictionary<int, string>();
errorCodes[404] = "Page not Found";    
errorCodes[302] = "Page moved, but left a forwarding address.";    
errorCodes[500] = "The web server can't come out to play today.";    
```

It's not much but it definitely results with a better experience for writing and reading the code.

The best thing about `Index initializer` is that it is not limited only to `Dictionary<>` class, it can be used with any type which defines an `indexer`:


```cs
class HttpHeaders
{
    public string this[string key]
    {
        get => throw new NotImplementedException();
        set => throw new NotImplementedException();
    }
}

class Program
{
    static void Main(string[] args)
    {
        var headers = new HttpHeaders
        {
            ["access-control-allow-origin"] = "*",
            ["cache-control"] = "max-age=315360000, public, immutable"
        };
    }
}
```


## Deconstructors

In C# 7.0, together with tuples, a deconstructor mechanism has been introduced. Deconstructors allow for "decomposing" a tuple into a set of individual variables as follows:

```cs
var point = (5, 7);
// decomposing tuple into separated variables
var (x, y) = point;
```

which is equivalent to:

```cs
ValueTuple<int, int> point = new ValueTuple<int, int>(1, 4);
int x = point.Item1;
int y = point.Item2;
```

This syntax allows also for switching values of two variables without the need for an explicit declaration of the third variable:

```cs
int x = 5, y = 7;
//switch
(x, y) = (y,x);
```

... or for a more succinct way of member initialization:

```cs
class Point
{
    public int X { get; }
    public int Y { get; }

    public Point(int x, int y)  => (X, Y) = (x, y);
}
```

Deconstructors can be used not only with tuples but with custom types too. To allow for deconstructing custom type, it needs to implement a method that obeys the following rules:

- It's named `Deconstruct`
- Returns void
- Every parameter has to be defined with `out` modifier

For our type `Point` we can define deconstructor in the following way:

```cs
class Point
{
    public int X {get;}
    public int Y {get;}

    public Point(int x, int y) => (X, Y) = (x, y);
    
    public void Deconstruct(out int x, out int y) => (x, y) = (X, Y);
}
```

and sample usage can look as follows:


```cs
var point = new Point(2,4);
var (x, y)= point;        
```

which under the hood is translated to:

```cs
int x;
int y;
new Point(2, 4).Deconstruct(out x, out y);
```

Deconstructors can be added to types declared outside the source code by defining them as an extension method:

```cs
public static class PointExtensions
{
     public static void Deconstruct(this Point @this, out int x, out int y) => (x, y) = (@this.X, @this.Y);
}
```

One of the most useful examples of deconstructors is the one for `KeyValuePair<TKey,TValue>`, which allows for easy access to key and value while iterating over a dictionary:

```cs
foreach(var (key, value) in new Dictionary<int, string> { [1] = "val1", [2] = "val2" })
{
    //TODO: Do something
}
```

`KeyValuePair<TKey,TValue>.Deconstruct(TKey, TValue) ` is available only from `netstandard2.1`. For previous `netstandard` versions we need to add it manually using the approach with the extension method.



## Custom awaitable types

C# 5 (released together with Visual Studio 2012) introduced an `async/await` mechanism which was a real game-changer in the area of asynchronous programming. Before that, handling invocation of asynchronous methods resulted very often in quite a messy code, especially when there was more than one asynchronous invocation:

```cs
void DoSomething()
{
    DoSomethingAsync().ContinueWith((task1) => {
        if (task1.IsCompletedSuccessfully)
        {
            DoSomethingElse1Async(task1.Result).ContinueWith((task2) => {
                if (task2.IsCompletedSuccessfully)
                {
                    DoSomethingElse2Async(task2.Result).ContinueWith((task3) => {
                        //TODO: Do something
                    });
                }
            });
        }
    });
}

private Task<int> DoSomethingAsync() => throw new NotImplementedException();
private Task<int> DoSomethingElse1Async(int i) => throw new NotImplementedException();
private Task<int> DoSomethingElse2Async(int i) => throw new NotImplementedException();
```

With `async/await` syntax this can be written in a much cleaner way:

```cs
async Task DoSomething()
{
    var res1 = await DoSomethingAsync();
    var res2 = await DoSomethingElse1Async(res1);
    await DoSomethingElse2Async(res2);
}
```
This might be surprising, but the `await` keyword is not reserved to work only with the `Task` type. It can be used with any type which contains a method called `GetAwaiter` and  returns type that meets the following requirement:

- Implements the `System.Runtime.CompilerServices.INotifyCompletion` interface with `void OnCompleted(Action continuation)` method.
- Contains the `IsCompleted` boolean property.
- Contains the  parameter-less `GetResult` method .

To add support of `await` keyword to the custom type we need to define `GetAwaiter` method that returns an instance of `TaskAwaiter<TResult>` or a custom type that meets aforementioned conditions:

```cs
class CustomAwaitable
{
    public CustomAwaiter GetAwaiter() => throw new NotImplementedException();
}

class CustomAwaiter: INotifyCompletion
{
    public void OnCompleted(Action continuation) => throw new NotImplementedException();

    public bool IsCompleted => => throw new NotImplementedException();

    public void GetResult() => throw new NotImplementedException();
}
```

You may wonder what could be a possible scenario of using `await` syntax with custom awaitable type. If that's the case, I highly recommend reading the article from [Stephen Toub](https://devblogs.microsoft.com/pfxteam/author/toub/) entitled "[await anything](https://devblogs.microsoft.com/pfxteam/await-anything/)" which provides plenty of interesting examples.

## The query expression pattern

The best invention of C# 3.0 was definitely `Language-Integrated Query`, known as `LINQ`, which allows for collection manipulation using SQL-like syntax.`LINQ` comes in two variations: SQL-like syntax and Extension method syntax. I prefer the second one because in my opinion it is more readable, but it's probably because I'm accustomed to it. An interesting fact about the SQL-like syntax is that it is translated into the Extension method syntax during the compilation because it's a C#, not `CLR` feature. `LINQ` was invented in the first place to work with `IEnumerable`, `IEnumerable<T>` and `IQueryable<T>` types but it's not limited to them, we can use it with any type that meets requirements of [query expression pattern](https://github.com/dotnet/csharplang/blob/master/spec/expressions.md#the-query-expression-pattern). The complete set of method signatures used by `LINQ` looks as follows:

```csharp
class C
{
    public C<T> Cast<T>();
}

class C<T> : C
{
    public C<T> Where(Func<T,bool> predicate);

    public C<U> Select<U>(Func<T,U> selector);

    public C<V> SelectMany<U,V>(Func<T,C<U>> selector, Func<T,U,V> resultSelector);

    public C<V> Join<U,K,V>(C<U> inner, Func<T,K> outerKeySelector, Func<U,K> innerKeySelector, Func<T,U,V> resultSelector);

    public C<V> GroupJoin<U,K,V>(C<U> inner, Func<T,K> outerKeySelector, Func<U,K> innerKeySelector, Func<T,C<U>,V> resultSelector);

    public O<T> OrderBy<K>(Func<T,K> keySelector);

    public O<T> OrderByDescending<K>(Func<T,K> keySelector);

    public C<G<K,T>> GroupBy<K>(Func<T,K> keySelector);

    public C<G<K,E>> GroupBy<K,E>(Func<T,K> keySelector, Func<T,E> elementSelector);
}

class O<T> : C<T>
{
    public O<T> ThenBy<K>(Func<T,K> keySelector);

    public O<T> ThenByDescending<K>(Func<T,K> keySelector);
}

class G<K,T> : C<T>
{
    public K Key { get; }
}
```

Of course, we don't need to implement all of those methods to use `LINQ` syntax with our custom type. The list of `LINQ` operators and methods required for them can be found [here](https://docs.microsoft.com/en-us/dotnet/csharp/programming-guide/concepts/linq/query-expression-syntax-for-standard-query-operators). `LINQ` syntax with custom types is very often used to implement monads. A really good explanation how to do it can be found in the article [Understand monads with LINQ](https://codewithstyle.info/understand-monads-linq/) by [Miłosz Piechocki](http://miloszpiechocki.com/)



## Summary

The purpose of this article was not to encourage you to abuse those syntax tricks but rather to demystify them. On the other hand, they should not be completely avoided. They were invented to be used, and sometimes they can make your code much cleaner. If you are afraid that the resulting code might not be so obvious to your teammates, you should find a way to share your knowledge or at least link to this article ;)
I'm not sure if it's a complete set of those "magical methods" - if you know any others, I would appreciate you sharing that in the comment section below.