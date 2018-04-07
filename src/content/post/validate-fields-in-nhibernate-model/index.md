---
title: "Validating fields of NHibernate model"
description: "How to detect invalid fields before commiting changes to database"
date: 2018-02-27T00:23:45+02:00
tags : ["data model", "NHibernate", "SQLite", "SQL Server"]
scripts : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js", "//cdnjs.cloudflare.com/ajax/libs/fitvids/1.2.0/jquery.fitvids.min.js"]
css : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css"]
image: "splashscreen.jpg"
isBlogpost: true
---
![splashscreen](splashscreen.jpg)


```plaintext
NHibernate.Exceptions.GenericADOException: could not execute batch command.[SQL: SQL not available] ---> System.Data.SqlClient.SqlException: String or binary data would be truncated.
The statement has been terminated.
```
Investigating this kind of error is very hard because the message is very criptic. It only says that some data exceeded given length constraints. We have no clue which field or even entity is the source of problem. I tried to search for some debugging advices in the google but I found only suggestion to use [NHibernate Validator](https://github.com/darioquintana/NHibernate-Validator) or implement [Nhibernate listeners](http://nhibernate.info/doc/nhibernate-reference/events.html) that performs appropiate validation. NHibernate-Validator seems to be overhelming for my requirement (and I don't want to polute my data model with additional fancy validation attributes) so I've decided do implement `IPreUpdateEventListener` and `IPreInsertEventListener` listeners which will be checking if values used in SQL query don't exceed the maximum length declared in NHibernate mappings.


### Implementation

The problem concers only string and binary fields so there are only to cases that should be handled (if I'm missing something please correct me). In order to implement validation I needed to figure out the following things:

1. How to extract fields which will be used in SQL query
2. How to access the length limits from NHibernate model definition

Having this information I need to check if the field value doesn't exceed the limit and the limit is not infinitive.

Checking if value exceeds the limit which is infinitive seems to be redundant but it make clear when we know how the infinitive length constains are defined in NHibernate. Default NHibernate string length limit is 4000 characters. If we need to create column that holds 'infinitive' string we have to set the length to 4001.

```csharp
public static class MappingExtensions
{
    internal const int MaxNhibernateStringLength = 4001;

    public static PropertyPart InfinitiveString([NotNull] this PropertyPart property)
    {
        return property.Length(MaxNhibernateStringLength);
    }
}
```
This results in creating column of type `nvarchar(max)` (in SQL Server).
For binary fields in order to create column that holds any size data we simply need to set the length to `int.MaxValue` which results with `varbinary(max)` column type.
These values should be consulted during field length validation.


My final implementation looks as follows:

```csharp
public class LengthValidatorListener: IPreUpdateEventListener, IPreInsertEventListener
{
  private const int InfinityBinaryLength = int.MaxValue;
  private const int InfinityStringLength = MappingExtensions.MaxNhibernateStringLength;

  [NotNull] 
  public Task<bool> OnPreUpdateAsync([NotNull] PreUpdateEvent @event, CancellationToken cancellationToken)
  {
      cancellationToken.ThrowIfCancellationRequested();
      var result = OnPreUpdate(@event);
      return Task.FromResult(result);
  }

  public bool OnPreUpdate([NotNull] PreUpdateEvent @event)
  {
      ValidateLength(@event.Session, @event.Entity, @event.Persister, @event.State);
      return false;
  }

  [NotNull] 
  public Task<bool> OnPreInsertAsync([NotNull] PreInsertEvent @event, CancellationToken cancellationToken)
  {
      cancellationToken.ThrowIfCancellationRequested();
      var result = OnPreInsert(@event);
      return Task.FromResult(result);
  }

  public bool OnPreInsert([NotNull] PreInsertEvent @event)
  {
      ValidateLength(@event.Session, @event.Entity, @event.Persister, @event.State);
      return false;
  }

  private static void ValidateLength([NotNull] ISession session,  [NotNull] object entity, [NotNull] IEntityPersister eventPersister, [NotNull] object[] state)
  {
      var entityName = entity.GetType().Name;
      var entityMetadata = GetMetadataForEntity(session, entity);

      for (int porpertyIndex = 0; porpertyIndex < eventPersister.PropertyNames.Length; porpertyIndex++)
      {
          var propertyValue = state[porpertyIndex];
          if (propertyValue == null)
          {
              continue;
          }
          var propertyName = eventPersister.PropertyNames[porpertyIndex];
          var propertyType = entityMetadata.GetPropertyType(propertyName);
          if (propertyType is StringType stringPropertyType)
          {
              if (stringPropertyType.SqlType.Length != InfinityStringLength)
              {
                  if (propertyValue is string value)
                  {
                      if (value.Length > stringPropertyType.SqlType.Length)
                      {
                          throw DataModelValidationException.StringFieldLengthExceeded(propertyName, entityName, value, stringPropertyType);
                      }
                  }
              }
          }
          else if (propertyType is BinaryType binaryPropertyType)
          {
              if (binaryPropertyType.SqlType.Length != InfinityBinaryLength)
              {
                  if (propertyValue is byte[] value)
                  {
                      if (value.Length > binaryPropertyType.SqlType.Length)
                      {
                          throw DataModelValidationException.BinaryFieldLengthExceeded(propertyName, entityName, value, binaryPropertyType);
                      }
                  }
              }
          }
      }
  }

  private static IClassMetadata GetMetadataForEntity([NotNull] ISession session, [NotNull] object entity)
  {
      var entityType = entity.GetType();
      var factory = session.SessionFactory.CastOrFail<ISessionFactoryImplementor>();
      return factory.GetAllClassMetadata().First(x => x.Value.MappedClass == entityType).Value;
  }
}
```


### Exception design

After detecting invalid situation I need to throw exception that contains as much information as is required to efficiently spot the issue source. For this problem class we need the following information

1. The name of the class and the field that contains value exceeding the limit
2. What is the value that exceed the limit
3. What is the length of the value that exceed the limit
3. What is the limit

The string that exceed the limit can be very long and could make the error message hard to analyze so instead of merging it into error message I decided to put it in Exception field for the debugging purpose (for binary data it's only reasonably solution). I've also added two factory methods that create exceptions for issue with string and binary data.

```csharp
public class DataModelValidationException:Exception
{
    [NotNull, Pure]
    public static DataModelValidationException BinaryFieldLengthExceeded(
        [NotNull] string propertyName,
        [NotNull] string entityName,
        [NotNull] byte[] value,
        [NotNull] BinaryType propertyType)
    {
        var message = $"Binary field '{propertyName}' of '{entityName}' entity with [length={value.Length}] exceeded the limitation of {propertyType.SqlType.Length} length";
        return new DataModelValidationException(message, value);
    }

    [NotNull, Pure]
    public static DataModelValidationException StringFieldLengthExceeded(
        [NotNull] string propertyName,
        [NotNull] string entityName,
        [NotNull] string value,
        [NotNull] StringType propertyType)
    {
        var message = $"String field '{propertyName}' of '{entityName}' entity with [length={value.Length}] exceeded the limitation of {propertyType.SqlType.Length} characters.";
        return new DataModelValidationException(message, value);
    }

    private DataModelValidationException(string message, object propertyValue) 
    : base(message)
    {
        PropertyValue = propertyValue;
    }

    public object PropertyValue { get; }
}
```

I'm using Resharper code annotation to enrich static code analisys. The `[Pure]` attribute save from situation when somebody invoke exception factory method and by mistake forget to add `throw` keyword (believe me, this happends).

### Listener registration
The last thing we need is to register our `LengthValidatorListener` in Nhibernate configuration.

```csharp
protected override Configuration GetConfiguration()
{
    var configuration = new NHibernate.Cfg.Configuration().Configure();
    var lengthValidatorListener = new LengthValidatorListener();
    configuration.SetListener(ListenerType.PreUpdate, lengthValidatorListener);
    configuration.SetListener(ListenerType.PreInsert, lengthValidatorListener);
    return configuration;
}
```

Since now every time when some field value exceeds the length limitation we get very descriptive exception that allows us immiediately locate the culprit. And there is one additional positive side effect of this solution - it works independly of database provider. Even if we run our test on SQLite (which don't obey the length constraints from NHibernate mappings) we should be able to detect length limit violation.
