---
title: "Setting assembly and nuget package metadata in .NET Core"
description: "How to properly manage artifacts metadata in SDK projects"
date: 2019-12-06T00:09:00+02:00
tags : ["dotnet", "C#",  "dotnet core", "nuget"]
highlight: true
image: "splashscreen.jpg"
isBlogpost: true
---

I don't know what was the original reason of moving these attributes to project file, but this helps to share the same values between nuget metadata and assembly metadata as well as simplify how these values can be overridden during the build process. However, it's still a common thing that tools like `regex` and `string replace` are used for this purpose, which is definitely against the original intentions. In this blog post I will show you how the metadata are calculated, which of them it's worth to set and how to do it correctly.


# Version, VersionPrefix and VersionSuffix

`Microsoft.NET.DefaultAssemblyInfo.targets`:

```xml
<PropertyGroup Condition=" '$(Version)' == '' ">
    <VersionPrefix Condition=" '$(VersionPrefix)' == '' ">1.0.0</VersionPrefix>
    <Version Condition=" '$(VersionSuffix)' != '' ">$(VersionPrefix)-$(VersionSuffix)</Version>
    <Version Condition=" '$(Version)' == '' ">$(VersionPrefix)</Version>
  </PropertyGroup>
```

which can be depicted in pseudo code as follows:

```plaintext
if(Version == '')
{
    if(VersionPrefix == '')
    {
        VersionPrefix = '1.0.0'
    }
    
    if(VersionSuffix != '')
    {
        Version = VersionPrefix + '-' + VersionSuffix
    }
    else
    {
        Version = VersionPrefix
    }
}
```

If the `Version` property is hardcoded in project's file, then passing `VersionPrefix` and `VersionSuffix` has no effect.

The `Version` attribute is used for nuget package. If the version contains `VersionSuffix` then the package is treated as `pre-release` package. `Version` property is also use in `Microsoft.NET.GenerateAssemblyInfo.targets` to generate `AssemblyVersion` attribute if not defined :

```xml
<!--
    ==================================================================
                                            GetAssemblyVersion

    Parses the nuget package version set in $(Version) and returns
    the implied $(AssemblyVersion) and $(FileVersion).

    e.g.:
        <Version>1.2.3-beta.4</Version>

    implies:
        <AssemblyVersion>1.2.3</AssemblyVersion>
        <FileVersion>1.2.3</FileVersion>

    Note that if $(AssemblyVersion) or $(FileVersion) are are already set, it
    is considered an override of the default inference from $(Version) and they
    are left unchanged by this target.
    ==================================================================
  -->
  <Target Name="GetAssemblyVersion">
    <GetAssemblyVersion Condition="'$(AssemblyVersion)' == ''" NuGetVersion="$(Version)">
      <Output TaskParameter="AssemblyVersion" PropertyName="AssemblyVersion" />
    </GetAssemblyVersion>
    
    <PropertyGroup>
      <FileVersion Condition="'$(FileVersion)' == ''">$(AssemblyVersion)</FileVersion>
      <InformationalVersion Condition="'$(InformationalVersion)' == ''">$(Version)</InformationalVersion>
    </PropertyGroup>
  </Target>
```

Later on, in `CreateGeneratedAssemblyInfoInputsCacheFile` target, `AssemblyVersion` and couple of other attributes are used to generate `cs` file that contains assembly related attributes. The definitions of generated attributes are defined in `GetAssemblyAttributes` target. Here's a complete list of Msbuild property and affected assembly attributes

|MsBuild property | Assembly attribute|
|------------------|-------------------|
| Company | System.Reflection.AssemblyCompanyAttribute|
| Configuration | System.Reflection.AssemblyConfigurationAttribute|
| Copyright | System.Reflection.AssemblyCopyrightAttribute|
| Description| System.Reflection.AssemblyDescriptionAttribute|
| FileVersion | System.Reflection.AssemblyFileVersionAttribute|
| InformationalVersion | System.Reflection.AssemblyInformationalVersionAttribute |
| Product | System.Reflection.AssemblyProductAttribute|
| AssemblyTitle | System.Reflection.AssemblyTitleAttribute |
| AssemblyVersion | System.Reflection.AssemblyVersionAttribute |
| NeutralLanguage | System.Resources.NeutralResourcesLanguageAttribute |

You can disable generating code of specific assembly attribute by defining corresponding  `GenerateAssembly*Attribute` msbuild property. For example, if you want to use explicitly `GenerateAssemblyVersionAttribute` in your codebase, you have to add the following entry in project file:

```xml
<PropertyGroup>
    <GenerateAssemblyVersionAttribute>false</GenerateAssemblyVersionAttribute>
</PropertyGroup>
```



TODO: short it numbers, overflows and invalid windows representation

# Repository info
