---
title: "Best practices for using PowerShell with TeamCity"
date: 2019-03-22T10:34:18+02:00
tags : ["PowerShell", "TeamCity", "continuous integration", "VSCode"]
isBlogpost: true
image: "splashscreen.jpg"
highlight: true
highlightLang: ["powershell"]
---


In the last few projects that I've attended I was deeply involved in continuous integration. What I mean I was fully in charge of setting up, configuring and maintaining CI or I was a consultant helping other teams to deal with different problems related to this subject as well. All projects have been using TeamCity as a platform for continuous integration. It has a lot of predefined jobs that facilitate most common activities necessary to build pipelines as well as rich UI that helps to easily configure it and examinee pipeline results. For the more complicated and non-standard activities I've been using `PowerShell` scripts. TeamCity has a really good support for running `PowerShell` thanks to dedicated build step, however it can cause some troubles if it's not configured correctly. After coming across many times at the same mistakes and issues I finally decided to write this article that shows how to use properly `PowerShell` together with `TeamCity`. I hope you will find it useful.


## Proper error handling

The most common problem is that TeamCity disallows Powershell errors, at least with the default configuration. Event if PowerShell script fails, it's still considered as successful by TeamCity. This can has a serious ramification because the errors can occur unnoticed for months and can cost you a lot when you finally spot them. This is caused by default setting for `Format stderr output as` in PowerShell build step template, which is set to `warning`.  In order to propagate PowerShell errors to the TeamCity UI (mark the build step as failed) this should be set to `error` as shows the following screenshot.

![](error_handling_for_ps.jpg)

However, after changing `Format stderr output as` option we can still observe strange effect that can ne a kind of surprise: event if the PowerShell build failed, the whole pipeline is reported as successful. To fix that and make it works according to expectation we need to adjust the build `Failure Conditions` by checking `an error message is logged by build runner` option as follows: 

![](teamcity_failure_condition.jpg)


Since know all PowerShell errors will be properly reported and affect build status. Besides these two configuration options in TeamCity there is one more thing related to the PowerShell errors to keep in mind - PowerShell error model. Powershell errors can be dived into two categories: terminating (mostly syntax errors) and non-terminating. The latter are not obvious and cause a lot of troubles for people without strong PowerShell foundations. Even if the `non-terminating` error occurs the script execution is continued. This effect can be highly unwanted for scripts performing interlinked and dependent on each other operations. Of course, we can change this behavior and turn all 'non-terminating' errors into 'terminating' ones by setting `$ErrorActionPreference` variable at the begging of our scripts:

```powershell
#Error Action Preference:
#
#PowerShell halts execution on terminating errors, as mentioned before. For non-terminating errors we have the option to tell PowerShell how to handle these situations. 
#This is where the error action preference comes in. Error Action Preference allows us to specify the desired behavior for a non-terminating error; it can be scoped at the command level or all the way up to the script level.
#
#Available choices for error action preference:
#
# SilentlyContinue – error messages are suppressed and execution continues.
# Stop – forces execution to stop, behaving like a terminating error.
# Continue - the default option. Errors will display and execution will continue.
# Inquire – prompt the user for input to see if we should proceed.
# Ignore – (new in v3) – the error is ignored and not logged to the error stream. Has very restricted usage scenarios.
# Example: Set the preference at the script scope to Stop, place the following near the top of the script file:
$ErrorActionPreference = "Stop"
```

This can also be configured for each CmdLet separately without the need to setup it globally. You can read more about CmdLet common parameters [here](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters?view=powershell-6)

## Protect yourself from accidental errors

Besides the error handling it's good to write your scripts in a manner that protects you from accidental errors that can be very hard to detect. At first you should turn all you functions into real `Cmdlets`. In order to do that you should always define parameters with `param()` block and decorate it with `[CmdletBinding()]` parameter:

```powershell
function Verb-Noun {
    [CmdletBinding()]
    param (
     #parameters go here   
    )    
}
```

`[CmdletBinding()]` parameter protects your methods from invoking them with undefined parameter. Every time when somebody use undefined (or deleted) parameter or make a typo in parameter name this fact will be reported as PowerShell error.  If the method is not CmdLet the parameter names are not validated making the problem hard to detect.

We can also detect potential errors caused by violation of best-practices and coding rules by enabling strict mode by adding at the begging of our scrips code:

```powershell
Set-StrictMode -Version Latest
```

After turning on strict mode PowerShell will report all uninitialized variables and properties with terminating error. You can read about all consequences of using strict mode [here](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode?view=powershell-6)



And the last my advice that should help you to avoid dummy mistakes is: 

> Always use a decent IDE to create and edit your powershell scripts. 

I'm currently working with VSCode  with PowerShell plugin which seems to be more powerful than `PowerShell ISE`. It ships with a rich set of snippets, is able to detect unused variables, allows to track method usages and provides a really nice experience in terms of debugging scripts. It also has integrated `PSScriptAnalyzer` module which helps to detect many issues related to the code correctness and quality. You can read about all features [here](https://code.visualstudio.com/docs/languages/powershell).


## Using scrips

TeamCity PowerShell build step allows to run PowerShell scripts provided as an inline source code as well as script files. For project specific scripts you should always use script file options. This allows you to keep your script under version control system together with the project source code and make it easier to edit your scripts (any IDE is better than textarea on the build configuration step page). Of course you can keep your 'inline-scripts' versioned when you are using [Versioned settings](https://confluence.jetbrains.com/display/TCD10/Storing+Project+Settings+in+Version+Control) but it's very tedious to edit PowerShell scripts embedded inside the `XML files`.

For project non-specific scripts, when you want to re-use scripts between different projects you can have at least two options:

- put common scripts in separate repository and shared them via git sub-modules
- use inline script and extract common meta-runner

The second option allows you to create a nice configuration UI for your scripts, however versioning will be not possible anymore (as far as I know). You can find an example how to create meta-runner in my [previous article](/post/integrating-teamcity-with-msteams/).


## Always remember about Clean Code
- clean code
- use named parameters (makes code more readable and easier to changed)
- best practices and style guide https://github.com/PoshCode/PowerShellPracticeAndStyle


## Review and Testing