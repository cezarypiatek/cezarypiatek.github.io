---
title: "Reactive testing"
description: "Creating maintainable UI test with reactive approach"
date: 2018-07-21T00:21:18+02:00
tags : ["Selenium", "testing", "ui-tests"]
scripts : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js", "//cdnjs.cloudflare.com/ajax/libs/fitvids/1.2.0/jquery.fitvids.min.js"]
css : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css"]
image: "splashscreen.jpg"
isBlogpost: true
draft: true
---
![splashscreen](splashscreen.jpg)

```csharp
public class UserListPage()
{
  private readonly WebDriver driver;
  private readonly Lazy<Form> filterForm;
  private readonly Lazy<List> userList;
  private readonly new Lazy<List> listPagination;

  public UserListPage(WebDriver  driver){
    this.driver = driver;
    this.filterForm = new Lazy<Form>(x=> driver.FindFormWithId("UserFilterForm"));
    this.userList = new Lazy<List>(x=> driver.FindListWithId("UserList"));
    this.listPagination = new Lazy<List>(x=> driver.FindListWithId("UserListPagination"));
  }

  public void FilterWith(Action<Form> fillFilterFormAction)
  {
      fillFilterFormAction(this.filterForm);
      this.userList.Value.AffectWith(()=> this.filterForm.Value.ClickOnElementWithText("Filter"));
  }

  public void LoadPage(int pageNo){
    this.userList.Value.AffectWith(()=> this.listPagination.Value.ClickOnElementWithText($"{pageNo}"));
  }

  public int GetNumberOfUsers(){
    return this.userList.Value.Count;
  }

  public void OpenUserDetails(string userName)
  {
      var listItem =  this.userList.FindItemWithText(userName);
      this.driver.RealoadPageWith(()=> listItem.ClickOnElementWithText("Details"))
  }
}
```