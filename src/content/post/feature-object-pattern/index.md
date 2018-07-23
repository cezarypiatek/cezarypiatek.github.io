---
title: "Feature Object Pattern"
description: "Creating maintainable UI test with Feature Object Pattern"
date: 2018-08-05T00:21:18+02:00
tags : ["Selenium", "testing", "ui-tests"]
scripts : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js", "//cdnjs.cloudflare.com/ajax/libs/fitvids/1.2.0/jquery.fitvids.min.js"]
css : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css"]
image: "splashscreen.jpg"
isBlogpost: true
draft: false
---
![splashscreen](splashscreen.jpg)

When it comes to writing maintainable UI test there always appears the term of `Page Object Pattern`. For those who are not familiar with `Page Object`, it's the approach to building UI test that focuses on creating high-level abstraction over low-level details related to interaction with a tested application. This testing interface encapsulate all the noise related to technology and allows to clearly express intention of tests cases. This concept is very well described by Martin Fowler [here](https://martinfowler.com/bliki/PageObject.html) 

Page Objects can be prepared by programmers who participate in the development of a tested application. This approach is very efficient because the programmer knows best the implementation details, how particular elements were built and how to interact with them. This ready Page Object can be followingly used by testers to automate test cases. I think this is the most effective way of preparing automatic UI tests because everybody does what knows the best. A testing person is excused from the need of getting to know how the tested app is built, how the used technology works and he can entirely focus on automatig test cases using hight level testing api. 

## Introduction of Feature Object

> A page object wraps an HTML page, or fragment, with an application-specific API, allowing you to manipulate page elements without digging around in the HTML.

This is a quote from Martin Fowler Page Object description. We can take it a little further by applying `divide and conquer` rule and introduce a new kind of object that represents a single type of building element that repeatedly appears in the tested application. These can be objects such as lists, tables, trees, forms etc. I call this kind of wrapper a `Feature Object Pattern`. This approach has a few benefits. It allows to program interaction with given type of element only once and reuses it everywhere in tests. We can use `Feature Object` to compose Page Object of them by adding contextual integration. When a given type of element change it requires only change in single place. One of the positive side effects is that it enforces on the programmers to build the application in the consistent way (all list, tables, forms etc should be constructed and behave consistently). This is a counterpart of the component approach in application development. Each component (or composition) should be reflected by `Feature Object`. Before we start writing UI test we should perform analysis by identifying the application building elements and prepare the appropriate `Feature Object` for them. As with Page Object, to make the process more efficient, they should be prepared by the developer. 

## Implementing Feature Objects

I've made an attempt of implementing generic `Feature Objects` for elements such as forms, lists, tables and trees in my Selenium wrapper called [Tellurium](https://github.com/cezarypiatek/Tellurium) which is available on Github.  A sample usage of these `Feature Objects` is described on the project's wiki in the following sections:

- [Working with lists](https://github.com/cezarypiatek/Tellurium/wiki/Working-with-lists)
- [Working with tables](https://github.com/cezarypiatek/Tellurium/wiki/Working-with-tables)
- [Working with trees](https://github.com/cezarypiatek/Tellurium/wiki/Working-with-trees)
- [Working with forms](https://github.com/cezarypiatek/Tellurium/wiki/Working-with-forms)

If you are interested in implementation details, please inspect source code of the following classes: [WebTree](https://github.com/cezarypiatek/Tellurium/blob/6bd0673a04464f67ea6a41700c5d3419a9e028ce/Src/MvcPages/WebPages/WebTree.cs), [WebList](https://github.com/cezarypiatek/Tellurium/blob/4b3e8188f65d39a996621538823f876a68b8d4a3/Src/MvcPages/WebPages/WebList.cs), [WebTable](https://github.com/cezarypiatek/Tellurium/blob/4b3e8188f65d39a996621538823f876a68b8d4a3/Src/MvcPages/WebPages/WebTable.cs) and [WebForm](https://github.com/cezarypiatek/Tellurium/blob/4b3e8188f65d39a996621538823f876a68b8d4a3/Src/MvcPages/WebPages/WebForms/WebForm.cs). This project is written in C#, but I'm pretty sure that these classes can be easily ported to your programming language of choice.

Let's look how we can handle tables using `WebTable` wrapper from `Tellurium` project:

```csharp
var table = browserAdapter.GetTableWithId("SampleTable");
table[1] //access second row
table[1][0].Text //access second row, first column
table[1][0].Text //access second row, first column cell's text
table[0]["Column Name"].Text //access first row, column with caption  "Column Name" 

table.First() //access first row
table.First().First() //access first row, first column
table.Last().Last() //access last row, last column
table.FindItemWithText("Example row")[1] //access row with text "Example row", second colum
```

As wee see, this is a very simple, elegant, intuitive and readable way of interacting with tables. We don't need to know how the table was built, what the underlying markup looks like and what the particular tags mean. Another interesting example shows how easily we can work with forms using `WebForm` wrapper:

```csharp
var loginForm = browserAdapter.GetForm("RegistrationForm");
loginForm.SetFieldValueByLabel("First name", "John");
loginForm.SetFieldValueByLabel("Last name", "Doe");
loginForm.ClickOnElementWithText("Register");
```

## Building Page Object from Feature Objects

Having `Feature Objects`representing forms and list we can use them to build `Page Object` for user list with filters:

```csharp
public class UserListPage()
{
  private readonly Lazy<WebForm> filterForm;
  private readonly Lazy<WebList> userList;
  private readonly new Lazy<WebList> listPagination;

  public UserListPage(WebDriver  driver){    
    this.filterForm = new Lazy<WebForm>(x => driver.FindFormWithId("UserFilterForm"));
    this.userList = new Lazy<WebList>(x => driver.FindListWithId("UserList"));
    this.listPagination = new Lazy<WebList>(x => driver.FindListWithId("UserListPagination"));
  }

  public void FilterWith(Action<Form> fillFilterFormAction)
  {
      fillFilterFormAction(this.filterForm);
      this.filterForm.Value.ClickOnElementWithText("Filter");
  }

  public void LoadPage(int pageNo){
      this.listPagination.Value.ClickOnElementWithText($"{pageNo}");
  }

  public int GetNumberOfUsers(){
    return this.userList.Value.Count;
  }

  public void OpenUserDetails(string userName)
  {
      var listItem =  this.userList.Value.FindItemWithText(userName);
      listItem.ClickOnElementWithText("Details");
  }
}
```

In this example `Feature Objects` were used to handle the following page elements: 

 - filter form 
 - list of users
 - pagination bar (list of page numbers). 
 

With our `Page Object` we can very easily create a test that is very concise and readable:

```csharp
[Test]
public void should_be_able_to_filter_users()
{  
  //ARRANGE
  var driver = this.GetDriver();
  var userList = driver.GoToUserList();

  //ACT
  userList.FilterWith(filter => {
    filter.SetFieldValueByLabel("Department", "Security");
    filter.SetFieldValueByLabel("Severity", "Senior");
  });

  //ASSERT
  Assert.AreEquals(5, userList.GetNumberOfUsers())
}
```

## Summary
If you want to create maintainable UI Tests you should definitely utilize `Page Object Pattern` in conjunction with `Feature Object Pattern`. In order to make the process of preparing UI Tests more effective, the people responsible for automating test cases should be supported by programmers developing tested application who should build appropriate Page Object and Feature Objects. If you don't know how to start building Feature Object you can check the implementations of [WebTree](https://github.com/cezarypiatek/Tellurium/blob/6bd0673a04464f67ea6a41700c5d3419a9e028ce/Src/MvcPages/WebPages/WebTree.cs), [WebList](https://github.com/cezarypiatek/Tellurium/blob/4b3e8188f65d39a996621538823f876a68b8d4a3/Src/MvcPages/WebPages/WebList.cs), [WebTable](https://github.com/cezarypiatek/Tellurium/blob/4b3e8188f65d39a996621538823f876a68b8d4a3/Src/MvcPages/WebPages/WebTable.cs) and [WebForm](https://github.com/cezarypiatek/Tellurium/blob/4b3e8188f65d39a996621538823f876a68b8d4a3/Src/MvcPages/WebPages/WebForms/WebForm.cs) from [Tellurium](https://github.com/cezarypiatek/Tellurium) Project. I used it to automate tests for the application that consist of 100+ forms and it works like a charm.