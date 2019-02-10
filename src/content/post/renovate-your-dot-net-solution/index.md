---
title: "Renovate your .NET solution"
description: "Why you should definitely convert your C# projects to VS2017 format."
date: 2019-02-09T00:20:45+02:00
tags : ["C#", "dotnet", "visual studio"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---


In the early days of dotnet core there was an attempt of changing c# project file format. The old "csproj" based on `xml` format was replaced with  `.xproj/project.json`. However after releasing `dotnet core 1.0` the authors decided to get back to `xml` file.  The format stayed the same but the specification has been totally changed. With the new schema a lot of improvements comes into .net development and they are not restricted only to dotnet core projects.

## Changes

### Files information diet
In `VS2007` format the `csproj` is not a ledger of all projects files anymore. This decision has few benefits. The first one is that we have much less conflict situations during committing changes into VCS. Two peoples can simultaneously add files into the same project and don't worry about the need of merging conflicts.  The second one is related to the order in the codebase. I used to work with people who have a bad habit of excluding files from the project instead of deleting them completely. This results with polluting codebase with unnecessary files and caused a lot of confusion (a lot of questions: "Is it still necessary?", "Why this is not included into the project?") With the new csproj format this problem disappeared almost completely. Of course there is a still an option of excluding files from project but this result with additional entry in csproj and thanks to that is much easier to detect it during code review.


### Nuget

With the new `csproj` format a few changes comes also to the nuget. At first, the  `packages.config` has been abandoned and the information about references nuget packages were moved into `csproj` file - all nuget dependencies are now listed as `PackageReference` nodes. The next change is related to creating own nuget packages. You don't need `nuspec` file anymore to generate nuget package from your project - all the package metadata are inside project file. And the most important information: working with nuget is much more nicer because it's finally fast. There is tremendous difference in nuget performance between projects in old and new format. In the old format even the simplest actions such as install or update a single package were painfully slow. The issue is described here: [Why is everything related to nuget package restore/upgrade so slow](https://github.com/NuGet/Home/issues/5805) and the only working solution is a migration to new csproj format.



## Benefits for everyone


## Migration

TODO
- automated migration
- perparing for the migration
- using new format with full dotnet framework