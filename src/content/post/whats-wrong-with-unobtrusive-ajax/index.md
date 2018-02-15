---
title: "Whtat's wrong with jquery.unobtrusive-ajax and how to fix it."
description: ""
date: 2018-02-15T00:22:00+02:00
tags : ["Content-Security-Policy", "csp", "ASP.NET MVC", "ajax", "cleancode"]
scripts : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js", "//cdnjs.cloudflare.com/ajax/libs/fitvids/1.2.0/jquery.fitvids.min.js"]
css : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css"]
image: "splashscreen.jpg"
isBlogpost: true
---
![splashscreen](splashscreen.jpg)

jquery.unobtrusive-ajax is the javascript library that every ASP.NET MVC developer certenely know. It shipped with MVC boostrapping template and it's responsible for providing plubbing code which helps to add ajax functionality to rendered forms and links. Unfortunately it has a few design drowback which could have negative impact on our system architecture. In this post I'm going to show you all jquery.unobtrusive-ajax.js related problems which I encountered in my 5 years journey as a ASP.NET MVC fronted developer and how to fix it.

## How it works.

```razor
@using (Ajax.BeginForm("SaveData", new AjaxOptions { OnSuccess = "alert(\"Data successfuly saved!\");" }))
{
    <h1>This is sample form</h1>
    @*Sample form content*@
    <input type="submit" value="Submit"/>
}
```

```html
<form action="/Home/SaveData" data-ajax="true" data-ajax-success="alert(&quot;Data successfuly saved!&quot;);" id="form0" method="post">
    <h1>This is sample form</h1>
    <input type="submit" value="Submit">
</form>
```
If you switch in web.config **UnobtrusiveJavaScriptEnabled"** flag to false you get the code as below which is some kind of fallback in case you don't have jquery (it requires another Microsoft JavaScript library).

```html
<form action="/Home/SaveData" id="form0" method="post" onclick="Sys.Mvc.AsyncForm.handleClick(this, new Sys.UI.DomEvent(event));" onsubmit="Sys.Mvc.AsyncForm.handleSubmit(this, new Sys.UI.DomEvent(event), { insertionMode: Sys.Mvc.InsertionMode.replace, onSuccess: Function.createDelegate(this, alert(&quot;Data successfuly saved!&quot;);) });">    
	<h1>This is sample form</h1>
    <input type="submit" value="Submit"/>
</form>
<script type="text/javascript">
//<![CDATA[
if (!window.mvcClientValidationMetadata) { window.mvcClientValidationMetadata = []; }
window.mvcClientValidationMetadata.push({"Fields":[],"FormId":"form0","ReplaceValidationSummary":false});
//]]>
</script>
```

## Is it truly unobtrusive?

I think te root of all problems is laying in the (miss)understanding of "unobtrusive javascript" term. According to [Wikipedia](https://en.wikipedia.org/wiki/Unobtrusive_JavaScript) the concept of unobtrusive javascript appeared for the very first time in  Stuart Langridge's article [Unobtrusive DHTML, and the power of unordered lists](https://kryogenix.org/code/browser/aqlists/) from 2002. A really good explanation we can find in David Flanagan's book "JavaScript: The Definitive Guide" which looks as follows:


> A programming philosophy known as unobtrusive JavaScript argues that content (HTML) and behavior (JavaScript code) should as much as possible be kept separate. According to this programming philosophy, JavaScript is best embedded in HTML documents using \<script> elements with src attributes.

The are few other postulates of this paradigm (such as Graceful degradation) but this one is especially important from the clean code perspective. According to this definition jquery.unobtrusive-ajax.js is not even a close to unobtrusive javascript complience because it requires providing javascript callbacks inside the html attributes.

I think the author(s) of this library was mainly focus on the aspect of Graceful degradation, which has in nowadays marginal meaning and totally forgot about separation of concerns between Javascript and HTML code.

![mem](is_it_truly_unobtrusive.jpg)

## Implications

The main issue is not the compliance with the definition but this programming style (I mean messing javascript code with html markup) has some serious ramification. First of all this code is really hard to maintain. If you put javascript code inside html atttributes you won't be able to refactor it, debug or verify syntax correctness. This is also sometimes abused to build your javascript dynamically (by concatenating strings) which could results with the potential XSS atack.
Another disavantage is that when you need to invoke function inside this "inline" code it requires global accessability of this function. This means  you can't put your function definition inside private context (for example wrapping inside immediate invocation of anonymous function). Exposing function globally can have negative effects such as name collisions (which cause method overriding) amd it makes harder to keep context separation. And the most serious drowback, which can even prevent releasing our software to the production due the security reasons, is lack of Content-Security-Policy compliance. I've been developing software for financial sector so the security audits were mandatory and CSP compliance was also veryfied. For those who don't know CSP is another security mechanism which prevents against XSS attacks. This is preety easity to implement - you have to only add "Content-Security-Policy" header to http response. However, enabling CSP has impact onto how javascript and css is interpreted. Since now you can't use inline scripts and styles and can't evaluate javascript dynamically (expressions such as "eval()" and "new Function()" are forbidden). So when you add CSP header all your javascript code which is wired by jquery.unobtrusive-ajax stop working.

![CSP Error](csp_error.jpg)

## How to fix it?


```js
(function(){
	$("#SampleForm").on("ajax:begin", function (event, ajaxData) {
    console.log("Begin");
	});

	$("#SampleForm").on("ajax:complete", function (event, ajaxData) {
		console.log("Complete");
	});

	$("#SampleForm").on("ajax:success", function (event, ajaxData) {
		console.log("Success");
	});

	$("#SampleForm").on("ajax:failure", function (event, ajaxData) {
		console.log("Failure");
	});
})();
```