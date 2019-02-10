---
title: "Renovate your .NET solution"
description: "Why you should definitely convert your C# projects to VS2017 format."
date: 2019-02-09T00:20:45+02:00
tags : ["C#", "dotnet", "visual studio"]
highlight: true
highlightLang: ["powershell"]
image: "splashscreen.jpg"
isBlogpost: true
---


In the early days of dotnet core there was an attempt of changing c# project file format. The old "csproj" based on `xml` format was replaced with  `.xproj/project.json`. However after releasing `dotnet core 1.0` the authors decided to get back to `xml` file.  The format stayed the same but the specification has been totally changed. With the new schema a lot of improvements comes into .net development and they are not restricted only to dotnet core projects.

## Changes

### Files information diet
In `VS2007` format the `csproj` is not a ledger of all projects files anymore. This decision has few benefits. The first one is that we have much less conflict situations during committing changes into VCS. Two peoples can simultaneously add files into the same project and don't worry about the need of merging conflicts.  The second one is related to the order in the codebase. I used to work with people who have a bad habit of excluding files from the project instead of deleting them completely. This results with polluting codebase with unnecessary files and caused a lot of confusion (a lot of questions: "Is it still necessary?", "Why this is not included into the project?") With the new csproj format this problem disappeared almost completely. Of course there is a still an option of excluding files from project but this result with additional entry in csproj and thanks to that is much easier to detect it during code review.


### Nuget

With the new `csproj` format a few changes comes also to the nuget. At first, the  `packages.config` has been abandoned and the information about references nuget packages were moved into `csproj` file - all nuget dependencies are now listed as `PackageReference` nodes. The next change is related to creating own nuget packages. You don't need `nuspec` file anymore to generate nuget package from your project - all the package metadata are inside project file. And the most important information: working with nuget is much more nicer because it's finally fast. There is tremendous difference in nuget performance between projects in old and new format. In the old format even the simplest actions such as install or update a single package were painfully slow. The issue is described here: [Why is everything related to nuget package restore/upgrade so slow](https://github.com/NuGet/Home/issues/5805) and the only working solution is a migration to new csproj format. 


### Other changes
- edit project file without the need of unloading it
- project references (no more references from the bin)


## Benefits for everyone
I encountered many that the new c# project format is uniquely associated with dotnet core. This is probably caused by the fact that the Visual Studio template `Class Library (.NET Framework)` is still based on the old csproj format. The truth is that the new format can be used not only for dotnet core and dotnet standard but for the .NET Framework projects too. If you are using Visual Studio 2017 you can even migrate existing projects into the new format. In order to create a c# project with .NET Framework that utilize the new format you have to select `Class Library (.NET standard)` template and after that change manually the value of `<TargetFramework>` node inside the csproj file to the appropriate [Target Framework Moniker (TFM)](https://docs.microsoft.com/en-us/dotnet/standard/frameworks) For example for `.NET Framework 4.7.2` you have to use `<TargetFramework>net472</TargetFramework>`. The video below shows hot to do that correctly:


<div class="video-container">
<iframe width="853" height="480" src="https://www.youtube.com/embed/QlIZ056vYjw?rel=0" frameborder="0" allow="autoplay; encrypted-media" allowfullscreen></iframe>
</div>

## Migration

As I've mentioned before you can migrate existing .NET solution into the new csproj format and take the advantage of the all new features. The migration is very easy thanks to the [CsprojToVs2017](https://github.com/hvanbakel/CsprojToVs2017) command line tool. You just need to only download and run the tool with the path to the `sln` file as the parameter. However if your codebase is polluted with a unnecessary `cs` files that has been detached from the project you have to perform a cleanup before you make a migration. For that occasion I've prepared a couple of `powershell` cmdlets that help to spot all unused files with the sourcecode.  This code should be run directly from the `Package Manager Console` int the Visual Studio.


```powershell
function Search-ItemsRecursive{
  [CmdletBinding()]
  param($ProjectItems, $Filter, [switch]$Recurse=$false)
  foreach ($item in $ProjectItems) {
    if($(. $Filter $item))
    {
        $item
    }else{
        if(($item.ProjectItems -ne $null) -and $Recurse){
            Search-ItemsRecursive -ProjectItems $item.ProjectItems -Filter $Filter -Recurse:$Recurse
        }
    }
  }
}

function Find-OrphanFilesInSolution([switch]$IgnoreObj=$true){
    Get-Project -All | Find-OrphanFilesInProject -IgnoreObj:$IgnoreObj
}    

function Find-OrphanFilesInProject{    
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline=$true)]$Projects, [switch]$IgnoreObj=$true)
    process{
        $toProcess = if($Projects){$Projects}else{Get-Project}    
        foreach($p in $toProcess){
            $projectPath = Split-Path $p.FullName -Parent
            $csFilesInProject = Search-ItemsRecursive -ProjectItems $p.ProjectItems -Filter {param($item)$item.Name -like "*.cs"} -Recurse |% {$_.Properties.Item("FullPath").Value}
            dir $projectPath -Filter "*.cs" -Recurse |? { $csFilesInProject -notcontains $_.FullName } |? {(-not $IgnoreObj) -or ($_.Directory -notlike "*\obj*")} |select FullName 
        }
    }    
}
```

In order to perform cleanup you have to execute the following steps:

1. Paste the code of cmdlets into `Package Manager Console`
2. Invoke `Find-OrphanFilesInSolution` to get the complete list of unused C# files
3. Invoke `Find-OrphanFilesInSolution | Remove-Item` in order to delete unused C# files

The only thing that cause an issue for me during the migration were the resource files because they are still need to be explicitly referenced inside the csproj file. The time when I was performing migration on my solution (over a year ago) this scenario was not supported by the `CsprojToVs2017` tool so if you have `resx` files in your project you have to pay attention on them and fix them manually in case this is still an issue.


## Reusing project configuration
After migrating projects into the new format it's good to extract common projects configuration into `Directory.Build.props` file and put into the solution root directory. This will save you a lot of time in the future when there will be a need to change common properties for all projects such as framework or C# language version. This mechanism is very well described by [Thomas Levesque](https://www.thomaslevesque.com/) in his article  [COMMON MSBUILD PROPERTIES AND ITEMS WITH DIRECTORY.BUILD.PROPS](https://www.thomaslevesque.com/2017/09/18/common-msbuild-properties-and-items-with-directory-build-props/).  My ``Directory.Build.props` file looks as follows:

```xml
<Project>
	<PropertyGroup>
		<TargetFramework>netstandard2.0</TargetFramework>
		 <Platforms>x64</Platforms>
		 <RunCodeAnalysis>false</RunCodeAnalysis>
		 <LangVersion>7.2</LangVersion>
	</PropertyGroup>
</Project>
```



## Summary
The new csproj format comes with a lot of benefits. The project file is much cleaner than before and a lot of well know issues related to dotnet development was solved with the new schema. And The most important information: this new format is not reserved only to dotnet core - you can utilize it no matter what kind of .net framework you are using - it works event with Full .NET Framework. You should definitely start using it if it didn't happened so far.
