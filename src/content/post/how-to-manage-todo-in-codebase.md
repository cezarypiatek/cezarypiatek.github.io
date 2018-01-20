---
title: "How to manage TODO in your codebase."
date: 2017-12-03T10:38:18+02:00
tags : ["TODO", "resharper", "livetemplates", "TodoExplorer"]
scripts : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js"]
css : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css"]
isBlogpost: true
---
It's a good practice to make all things done at the first approach. But in the real world it's not always possible - for example we need to ask customer for clarification and it will take some time, or worst - we don't have enough time right now to implement things in the right way. In order to adress this issue, a TODO was invented to mark all those places in code requiring additional work. But the main disadvantage of TODO is that we mark code with it, commit it and forget about it. Sometimes somebody accidentally discovers some of those places in code but nobody is able to explain why this wasn't fixed yet. How can we use TODOs effectively? Fortunately Resharper comes to the rescue with To-do-Explorer.

![Resharper menu To-Do-Explorer](resharper_menu_todoexplorer.jpg)

This window allows to discover all TODOs in the whole solution.

![To-Do-Explorer](todo_explorer_window.jpg)

By default To-do-Explorer has three predefined filters which allow us to spot places marked as: TODO, NotImplemented and BUG.

![To-Do-Explorer Filters](todo_explorer_filters.jpg)

There is an option to extend this predefined filters set. For example we would like to find all TODOs assigned to specific developer (all TODOs should have owner). It is possible to configure it from "Tools -> To-do Explorer" position inside Resharper Options.

![To-Do-Explorer options](resharper_options_todoexplorer.jpg)

Click "Add" button in "Pattern" section to create new filter definition. I used to configure search patterns for particular user as follows:

![To-Do-Explorer Pattern definition](todo_explorer_pattern_definition.jpg)


This is the regular expression to detect CEZARYPIATEK user TODOs:

```plaintext
(?<=\W|^)(?<TAG>TODO(:)?(\s*?)CEZARYPIATEK)(\W|$)(.*)
```

After adding new pattern we should be able to use it from filter menu in To-do-Explorer

![To-Do-Explorer Pattern definition](todo_explorer_new_filter.jpg)

Alright, now we are able to list all TODO assigned to given developer, but this works only when people type TODO in specific format. Even if we inform all team members what is our codding standard for TODO, there is always a chance that somebody types this accidently in the wrong format. How can we enforce the right pattern? Once again - Resharper helps to solve the issue. I used Resharper LiveTemplates to define snipped that will be applied every time when somebody needs to add TODO. I blogged before about [LiveTemplates configuration](/post/livetemplates/) My TODO snippet configuration looks like follows:

![To-Do-Explorer Pattern definition](live_templates_todo_pattern.jpg)

```plaintext
// TODO:$to$:$task$ ($autor$:$date$) $description$ $END$
```

I've enriched the basic pattern with additional information such as: issue tracker task identifier (for my project JIRA Id), author and inserting date. This data is mandatory (we should pay attention to it during code review) and helps to manage TODO. The complete set of information represents the following rules:
1) Every TODO should have an owner. It should be clear who is responsible for completing this task.
2) Every TODO should be correlated with given task in issue tracker. If we are not able to complete this work in current task, another one should be created and appropriately scheduled. 
3) If the description is not clear we should know who to ask for more details.
4) The Insertion Date reminds us how long this has been neglected. If it's too long maybe we should decide to drop it (or convert it into //WARNING ).

Thanks to LiveTemplates macros values of $to$, $author$ and $date$ variables are automatically filled with default values. I've set "td" shortcut for this templates so every time I type "td" in my code Resharper helps me to insert TODO in appropriate format. This is really convenient and helps to enforce common pattern for TODO.

A full TODO message could look as follows:
 ```csharp
 // TODO:CEZARYPIATEK:TELL-1234 (JOHNDOE:2017-12-03) Release this event handler in dispose method
 ```

