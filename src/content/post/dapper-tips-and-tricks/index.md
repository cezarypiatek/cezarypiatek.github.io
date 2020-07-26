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
    public int Id {get; set;}
    public string FirstName { get; set; }
    public string LastName { get; set; }
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

We can introduce some sort of intermediate type for fetching result of the SQL query and then map it to the destination type in the memory. I call those intermediate types `DBO - DataBase Object`:


```cs
public class UserDBO
{
    public int Id {get; set;}
    public string FirstName { get;  }
    public string LastName { get; private set; }
    public string City { get; set; }
    public string ZipCode { get; set; }
    public string Street { get; set; }
    public string FlatNo { get; set; }
    public string BuildingNo { get; set; }
}

public class UserRepository
{
    static readonly string GetAllUserDataSqlQuery = ""; /*TODO: Here comes query for fetching user basic data*/
    
    public async Task<User> GetUser(IDbConnection connection, int id)
    {
        var userDBO = await connection.QueryFirstOrDefaultAsync<UserDBO>(GetAllUserDataSqlQuery, new {UserId = id});
        if(userDBO == null)
        {
            return null;
        }
        return new User
        {
            Id = userDBO.Id,
            FirstName = userDBO.FirstName,
            LastName = userDBO.LastName,
            //TODO: If the address is optional then we should check if all attributes are not empty before creating an instance of Address
            MainAddress = new Address
            {
                City = userDBO.City,
                ZipCode = userDBO.ZipCode,
                Street = userDBO.Street,
                FlatNo = userDBO.FlatNo,
                BuildingNo = userDBO.BuildingNo
            }
        };
    }
}
```

This solution has several disadvantages: 
- It requires intermediate DBO type.
- It requires additional mapping code to adjust fetched data to the desired structure
- If we change the relation between User and Address from one-to-one to one-to-many it will result w data duplication.

Another option is to fetch direct attributes (Id, FirstName, LastName) with one query, fetch address data with another one and merge user with address in memory:

```cs
public class UserRepository
{
    static readonly string GetUserBasicDataSqlQuery = ""; /*TODO: Here comes query for fetching user basic data*/
    static readonly string GetAddressDataSqlQuery = ""; /*TODO: Here comes query for fetching address data*/

    public async Task<User> GetUser(IDbConnection connection, int id)
    {
        var user = await connection.QueryFirstOrDefaultAsync<User>(GetUserBasicDataSqlQuery, new {UserId = id});
        if(user == null)
        {
            return null;
        }
        user.MainAddress = await connection.QueryFirstOrDefaultAsync<Address>(GetAddressDataSqlQuery, new {UserId = id});
        return user;
    }
}
```

This approach require two calls to database but it can be reduce by merging those two queries into a single string and executing it with `SqlMapper.GridReader`:

```cs
public class UserRepository
{
    static readonly string GetUserBasicDataSqlQuery = ""; /*TODO: Here comes query for fetching user basic data*/
    static readonly string GetAddressDataSqlQuery = ""; /*TODO: Here comes query for fetching address data*/

     static readonly string GetUserCompleteDataSqlQuery = @$"
        -- Fetch user basic data
        {GetUserBasicDataSqlQuery};
        -- Fetch address data
        {GetAddressDataSqlQuery};
    ";    

    public async Task<User> GetUser(IDbConnection connection, int id)
    {
        using var gridReader = await connection.QueryMultipleAsync(GetUserCompleteDataSqlQuery, new { UserId = id });
        var user = await gridReader.ReadFirstOrDefaultAsync<User>();
        if (user == null)
        {
            return null;
        }

        user.MainAddress = await gridReader.ReadFirstOrDefaultAsync<Address>();
        return user;
    }
}
```
Looks like this solution is much cleaner and requires less code than the option with the intermediate DBO object but things can get really messy when we want to fetch data for more than one user and the relation between user and address is one-to-many:

```cs
public async Task<IReadOnlyCollection<User>> GetAllUsers(IDbConnection connection)
{
    using var gridReader = await connection.QueryMultipleAsync(GetUserCompleteDataSqlQuery);
    var users = (await gridReader.ReadAsync<User>()).ToList();
    var addresses =  await gridReader.ReadAsync<Address>();
    //INFO: Address entity needs to be extended with UserId in order to merge the data correctly
    var addressesByUserId = addresses.GroupBy(x => x.UserId).ToDictionary(x => x.Key, x => x);
    foreach (var user in users)
    {
        if (addressesByUserId.TryGetValue(user.Id, out var userAddresses))
        {
            user.Addresses = userAddresses.ToList();
        }
    }
    return users;
}
```


We can simplify it by taking leverage of JSON support in SQL Server. For the relation 1-1 between the `User` and `Address` our sql query can look as follows:

```sql
SELECT
    u.UserId AS [UserId],
    u.FirstName AS [FirstName],
    u.LastName AS [LastName]
    a.City AS [MainAddress.City],
    a.ZipCode AS [MainAddress.ZipCode],
    a.Street AS [MainAddress.Street],
    a.FlatNo AS [MainAddress.FlatNo],
    a.BuildingNo AS [MainAddress.BuildingNo],
FROM
    Users u 
    LEFT JOIN Addresses a ON a.UserId = u.UserID
FOR JSON PATH
```

Are we can rewrite it to handle one-to-many relation using sub-query:

```sql
SELECT
    u.UserId as [UserId],
    u.FirstName as [FirstName],
    u.LastName as [LastName]
    (
        SELECT
            a.City AS [City],
            a.ZipCode AS [ZipCode],
            a.Street AS [Street],
            a.FlatNo AS [FlatNo],
            a.BuildingNo AS [BuildingNo]
        FROM 
            Addresses a
        WHERE
            a.UserId = u.UserID
        FOR JSON PATH
    )  AS [Addresses]
FROM
    Users u 
```

But how can we fetch this JSON sql query result using Dapper? The most common solution that we can come across in the internet is to create a custom type handler for our sql query result:

```cs
public class JsonTypeHandler<TResult>: SqlMapper.TypeHandler<TResult>
{
    public override void SetValue(IDbDataParameter parameter, TResult value) => 
        throw new NotSupportedException($"Sending '{typeof(TResult).FullName}' type to database is not supported");

    public override TResult Parse(object value)
    {
        var jsonPayload = value?.ToString();
        if (string.IsNullOrWhiteSpace(jsonPayload))
        {
            return default;
        }
        return JsonConvert.DeserializeObject<TResult>(jsonPayload);
    }
}
```

After registering type handler with:

```cs
SqlMapper.AddTypeHandler(new JsonTypeHandler<User>());
```
we can query our data with `Query<>()` method as usual. However this approach with custom type handler has two disadvantages:

- We need to register `JsonTypeHandler<>` for every most outer type which we are querying
- This won't work for larger objects because SQL server will split long JSON string across multiple rows. You can read more about that on MSDN in the section [Output of the FOR JSON clause](https://docs.microsoft.com/en-us/sql/relational-databases/json/format-query-results-as-json-with-for-json-sql-server?view=sql-server-ver15#output-of-the-for-json-clause)



We can solve both problem by executing sql queries with the following extension method:

```cs
public static class SqlQueryExtensions
{
    public static async Task<TResult> QueryFromJson<TResult>(this IDbConnection connection, string sqlQuery, object param)
    {
        var chunks = await connection.QueryAsync<string>(sqlQuery, param);
        var completeJsonPayload = string.Concat(chunks);
        return JsonConvert.DeserializeObject<TResult>(completeJsonPayload);
    }
}
```