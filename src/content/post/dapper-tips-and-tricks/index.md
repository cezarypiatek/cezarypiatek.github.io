---
title: "Working efficiently with legacy database using Dapper"
description: "A couple of tricks which simplify database access code while using Dapper library"
date: 2020-07-25T00:11:45+02:00
tags : ["Dapper", "SqlServer", "C#", "clean code", "dotnet"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---
A year ago I started working on a set of projects which requires accessing data from the huge legacy database. There was a decision to use [Dapper](https://github.com/StackExchange/Dapper) to facilitate database access code. For those of you who are not familiar with Dapper, it's a set of extension methods to [IDbConnection](https://docs.microsoft.com/en-us/dotnet/api/system.data.idbconnection?view=netcore-3.1) which allows to easily map C# object to sql query parameters as well as sql query result to C# objects. I was quite skeptical to use library which requires from me to write `SQL queries` directly in the C# code because I got used to relay always on ORMs (especially `NHibernate`). Over a course of the year `Dapper` turned to be the right tool for the job. In the meantime I also discovered a couple of features and tricks which allows me to write quite concise and easy to maintain database access code and I thinks it's worth to share them here.

## Resilient to refactoring

Dapper allows easily map sql query result to C# objects base on the naming convention. There's no problem if the database table columns' names match object fields's name - if there's a discrepancy you can deal with it by adding aliases:

```sql
SELECT 
    UserID AS [Id], 
    UserName AS [Name]
FROM 
    Users
```

However, naming convention approach is fragile to rename refactoring. Changing object field's name will break your code and it can be hard to detect without appropriate test suite. Fortunately there's a way to shorten this feedback loop and solve this issue in the design time. We can make our code more resilient by defining aliases using `string interpolation` and `nameof()` operator:

```cs
private static readonly string GetUsersListQuery = @$"
SELECT 
    UserID AS [{nameof(UserDBO.Id)}], 
    UserName AS [{nameof(UserDBO.Name)}]
FROM 
    Users
"
```

This not only takes away the threat of breaking the code while renaming `DBO` fields but also gives us a better discoverability and navigability in the code. Using `find usage` option, we can also find where a given field is used in the SQL queries. And there's no performance penalty because compilator is able to evaluate this string interpolation during the compilation because all of the parameters are const. You can verify it by yourself with this [Sharplab.io example](https://sharplab.io/#v2:EYLgZgpghgLgrgJwgZwLQAdYwggdsgZgB8ABAJgEYBYAKHIAIBVZHAEQCEB5Wgb1voH0SBegEtcMegEkAJvR70A5hBgBueizX0Avv0HCxE+gDkoAWwjylK9ZvW6aD2gYYAlCOgD2yUTE8IAT3k9enQEUQA3WEsSCgA2eiQoGU9cABsg2IAGegBxFWYcZAAZUWQYAEU4HCCAXiESABIAIloAZQBRYo6AYQAVehCmFgQpVnoAQTb6AG0eXHMITzAACkKEDk4AOlkASm0AXQAaQZpBYZxTC0npuYWLZbWRza2riH2D2gAxV04AWVO53WyFozVUtG0QA)

But what if we want to get there result of the string interpolation without the need to run the whole program in debug mode? This often need when there's a bug in the query and we want to copy it and test in the `Management Studio`. This can be easily archive with `Immediate window` - yes, that's right, you can use `Immediate window` to evaluate the code in the design time. To evaluate the string just enter fully qualified field name that holds the query into the `Immediate window`:

![](evaluated_string_interpolation.jpg)

Unfortunately, the output is not well formatted and contains additional characters for line endings. We can fix it by adding `nq` (no quote) suffix:

![](evaluated_string_interpolation_with_nq.jpg)

If you are using `Resharper` then you can avoid typing long FQN and copy it with a special option for that purpose:

![](resharper_copy_FQN.jpg)

## No magic numbers

Sometimes there is a need to use some sort of constant values in the sql query (especially in the conditions). Queries with those cryptic values are very hard to review or even can cause problem with understanding for the author when she/he get back after a while to them:

```cs
public class Repository {
   private static readonly string GetActiveUsersListQuery = @$"
SELECT 
    UserID, 
    UserName
FROM 
    Users
WHERE
    UserType = 135
";
}
```

This is a classical example of well know code smell called `magic numbers`. We can solved this problem again with string interpolation. __It's tempting to introduce an enum that represents a set of available values but unfortunately using enum as a parameter for interpolated string will prevent compiler from evaluating expression during the compilation. Evaluation will occur in the runtime and will result creating a new string in the memory every time when the code is executed.__ This can have negative impact on the application performance especially when you define sql queries as local variables. You can check it on this [Sharplab.io example](https://sharplab.io/#v2:EYLgZgpghgLgrgJwgZwLQAdYwggdsgZgB8ABAJgEYBYAKHIAIBVZHAEQCEB5Wgb1voH0SBegEtcMegEkAJvR70A5hBgBueizX0Avv0HCxE+gDkoAWwjylK9ZvW6ag+rQe0IuOGaYsEAFQCe6BC8egIAggDGMKIAbpYAvPQUBACsADSh0rhQUbEJSQQAbC60tAYMAEoQ6AD2yKIwNQj+8qHoCLGwliQUhfRIUDI1uAA2LT0ADPQA4irMOMgAMqLIMACKcDgtiSQkACQARLQAygCii6cAwr7OjoLzCFKsabdOD6YWtABiFZwAsq97j5kLQAOoACVOFVOmQeASC9ESPDhgQgADpItE4g4DqoXEA) In order to avoid it, it's better to defined those magic values as const and they must be a string even if they are numeric values, otherwise compiler generates invocation of `System.String.Format()` instead of creating single string:

```cs
public class Repository {
    
    static class UserType
    {
        public const string Active = "135";
        public const string Inactive = "136";
    }
    
   private static readonly string GetActiveUsersListQuery = @$"
SELECT 
    UserID, 
    UserName
FROM 
    Users
WHERE
    UserType = {UserType.Active}
";
}
```

## Bridge the gap between relational and object-oriented models 
Very often posts advertising micro ORMs presents fairly simple examples where database data structures match almost 1-1 the C# structures. However, the reality is quite different and the discrepancy between relational and object-oriented model might be expensive and results with large amount of code responsible for fetching and transforming 
data.

```cs
public class User
{
    public override int Id {get; set;}
    public string FirstName { get;  }
    public string LastName { get; private set; }
    public Address MainAddress { get; set; }
}

public class Address
{
    public string City { get; set; }
    public string ZipCode { get; set; }
    public string Street { get; set; }
    public string FlatNo { get; set; }
    public string BuildingNo { get; set; }
}
```

In order to fetch complete user data we can use one of the following approaches:

We can fetch direct attributes (Id, FirstName, LastName) with one query, fetch address data with another one and merge user with address in memory:

```cs
public class UserRepository
{
    public static readonly string GetUserBasicDataSqlQuery = ""; /*TODO: Here comes query for fetching user basic data*/
    public static readonly string GetAddressDataSqlQuery = ""; /*TODO: Here comes query for fetching address data*/

    public async Task<User> GetUser(IDbConnection connection, int id, CancellationToken cancellationToken)
    {
        var user = await connection.QueryFirstOrDefaultAsync<User>(GetUserBasicDataSqlQuery, new {UserId = id}, cancellationToken);
        if(user == null)
        {
            return null
        }
        user.MainAddress = await connection.QueryFirstOrDefaultAsync<Address>(GetAddressDataSqlQuery, new {UserId = id}, cancellationToken);
        return user;
    }
}
```
We can reduce the number of roundtrips to database by merging those two queries and executing then with `SqlMapper.GridReader`:

```cs
public class UserRepository
{
    public static readonly string GetUserCompleteDataSqlQuery = @"
        -- Fetch user basic data
        -- Fetch address data
    ";
    

    public async Task<User> GetUser(IDbConnection connection, int id, CancellationToken cancellationToken)
    {
        using var gridReader = await connection.QueryMultipleAsync(GetUserCompleteDataSqlQuery,  new {UserId = id});
        var user = await gridReader.ReadFirstOrDefault<Address>();
        if(user == null)
        {
            return null
        }

        user.MainAddress = await gridReader.ReadFirstOrDefault<User>();
        return user;
    }
}
```

Things can get really messy when we want to fetch data for more than one user and the relation between user and address is one-to-many:

```cs
Here comes complicated example
```

