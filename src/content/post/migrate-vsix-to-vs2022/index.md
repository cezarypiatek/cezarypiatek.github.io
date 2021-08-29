---
title: "Adding support for VisualStudio 2022 to your extension"
description: "Taking leverage of MsBuild to support multiple versions of VisualStudio"
date: 2021-08-29T00:21:45+02:00
tags : ["vsix", "GithubActions", "VisualStudio", "extensibility"]
highlight: true
highlightLang: ["xml", "yaml"]
image: "splashscreen.jpg"
isBlogpost: true
---


I published my first VisualStudio extension on 26th February 2018. It was initially created for Visual Studio 2017, but a few months later Visual Studio 2019 came out and I needed to support it as I was one of the beneficent. The migration was straightforward: it required only to extend `InstallationTarget` range to `[15.0,17.0)` in `vsixmanifest`, re-compile, and of course, re-publish the extension to the Visual Studio marketplace. Recently, the Visual Studio 2022 Preview was published. After quick scanning of [migration guideline](https://docs.microsoft.com/en-us/visualstudio/extensibility/migration/update-visual-studio-extension?view=vs-2022) it turned out that changing `InstallationTarget` was not enough and more work was required to support VS2022. I wanted to postpone the migration a little bit more but I got an email from one of my paid customers, that the need for constant switching between VS2022 and V2019 to use my [MappingGenerator](https://mappinggenerator.net) extension is killing his productivity - and I couldn't allow for that to happen.

## What needs to be changed

Basically, two things need to be changed to migrate your extension to VS2022. First of all, you need to adjust `vsixmanifest` by adding the new attribute `ProductArchitecture` to `InstallationTarget` configuration:

```xml
<Installation>   
   <InstallationTarget Id="Microsoft.VisualStudio.Community" Version="[17.0,18.0)">
      <ProductArchitecture>amd64</ProductArchitecture>
   </InstallationTarget>
</Installation>
```

The next thing that needs to be done is upgrading `SDK` NuGet package to a version appropriate for VS2022:

```xml
<ItemGroup>
    <PackageReference Include="Microsoft.VisualStudio.SDK" Version="17.0.0-previews-1-31410-273" ExcludeAssets="runtime">
        <IncludeAssets>compile; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
    <PackageReference Include="Microsoft.VSSDK.BuildTools" Version="17.0.3177-preview3">
        <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
        <PrivateAssets>all</PrivateAssets>
    </PackageReference>
</ItemGroup>
```
 
Additionally, you need to change the dotnet framework version to `v4.7.2`, if you still have an older version:

```xml
<PropertyGroup>
    <TargetFrameworkVersion>v4.7.2</TargetFrameworkVersion>
</PropertyGroup>
```

Ok, that's all - it doesn't seem to be a lot of work as I said before. However, those changes are not backward compatible and our extension can't be installed on an older version of VisualStudio anymore (adjusting `InstallationTarget.Version` won't help). So what can we do about that? According to the migration guideline on MSDN, the recommended approach is to move all extension code to [Shared Project](https://docs.microsoft.com/en-us/xamarin/cross-platform/app-fundamentals/shared-projects?tabs=windows) and reference it from two separate `VSIX` projects - one for VS2019 (and older) and one for VS2022 (and newer). Each `VSIX` project has its own `vsixmanifest` file and references appropriate nuget packages. 

I tried this approach and lost 4 hours of my life. After moving the extension code to Shared Project all my XAML files seemed to be broken and XAML Visual Designer couldn't load them correctly to display preview. Besides the design-time experience, after compiling the extension, it turned out that the images from the Resources couldn't load - for some unknown reason that magical `tres comas` path notation `"pack://application:,,,/Resources/` stopped working.

![](tres_comas.jpg)

## Migration in a smart way

After a couple of hours of struggling with `Shared Project`, I decided to change the approach. The new idea was to tweak a little bit the `csproj` file to load appropriate project configuration based on the value of input property called `VsTargetVersion`. This solution requires a separate compilation for each Visual Studio version (one for VS2019 and older and one for VS2022 and newer) but it allows for keeping a single VSIX project that supports all Visual Studio versions. The final working `MsBuild` script looks as follows:


```xml
<PropertyGroup>
    <!-- STEP 1 -->
    <VsTargetVersion Condition="'$(VsTargetVersion)' == '' and '$(VisualStudioVersion)' == '17.0' ">VS2022</VsTargetVersion>
    <VsTargetVersion Condition="'$(VsTargetVersion)' == '' and '$(VisualStudioVersion)' == '16.0' ">VS2019</VsTargetVersion>
    <!-- STEP 2 -->
    <OutputPath>bin\$(VsTargetVersion)\$(Configuration)\</OutputPath>
    <IntermediateOutputPath>obj\$(VsTargetVersion)\$(Configuration)\</IntermediateOutputPath>
  </PropertyGroup>
  <!-- STEP 3 -->
  <Choose>
    <When Condition="'$(VsTargetVersion)' == 'VS2022'">
      <PropertyGroup>
        <TargetFrameworkVersion>v4.7.2</TargetFrameworkVersion>
        <AssemblyName>MappingGeneratorProVS2022</AssemblyName>
      </PropertyGroup>
      <ItemGroup>
        <None Include="..\Manifests\VS2022\source.extension.vsixmanifest" Link="source.extension.vsixmanifest">
          <SubType>Designer</SubType>
        </None>
        <PackageReference Include="Microsoft.VisualStudio.SDK" Version="17.0.0-previews-1-31410-273" ExcludeAssets="runtime">
          <IncludeAssets>compile; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
        </PackageReference>
        <PackageReference Include="Microsoft.VSSDK.BuildTools" Version="17.0.3177-preview3">
          <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
          <PrivateAssets>all</PrivateAssets>
        </PackageReference>     
        <PackageReference Include="System.ComponentModel.Composition" Version="5.0.0" />
      </ItemGroup>
    </When>
    <Otherwise>
      <PropertyGroup>
        <TargetFrameworkVersion>v4.6.1</TargetFrameworkVersion>
        <AssemblyName>MappingGeneratorProVS2019</AssemblyName>
      </PropertyGroup>
      <ItemGroup>
        <None Include="..\Manifests\VS2019\source.extension.vsixmanifest" Link="source.extension.vsixmanifest">
          <SubType>Designer</SubType>
        </None>
        <PackageReference Include="Microsoft.VisualStudio.SDK" Version="15.0.1" ExcludeAssets="runtime">
          <IncludeAssets>compile; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
        </PackageReference>
        <PackageReference Include="Microsoft.VSSDK.BuildTools" Version="15.9.3039">
          <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
          <PrivateAssets>all</PrivateAssets>
        </PackageReference>
      </ItemGroup>
    </Otherwise>
  </Choose>
```

Explanation:

- **STEP 1:** If the `VsTargetVersion` is not defined (it's not passed explicitly as a compilation parameter), then I'm assigning a default value based on the current version of VisualStudio that loaded the project. For some unknown reason, it's not possible to build VS2019 extension with VS2022, so this approach fixes two issues here.
- **STEP 2:** In order to avoid any collisions, I'm adding value of `VsTargetVersion` attribute to `OutputPath` and `IntermediateOutputPath`. The artifacts and temporary build files will be in separate directories for each version. This also allows for avoiding any unnecessary confusion in the future. Please make sure that those attributes are not defined in other parts of your `csproj` file.
- **STEP 3:** I'm using `Choose-When-Otherwise` syntax for defining different project setting for each Visual Studio target version. In each branch we are allowed to have only a single `PropertyGroup` and a single `ItemGroup` definition. In `PropertyGroup` I'm setting `TargetFrameworkVersion` and `AssemblyName` appropriately for each `VsTargetVersion` value. 
In the `ItemGroup`, I'm defining separate sets of required nuget packages and I'm also importing an appropriate variation of `vsixmanifest` file.

When I load my solution in `VS2019`, it automatically switches everything to VS2019 setup and when I open it with VS2022 everything is ready to build and debug the extension under VS2022.

## Automated release

For `Continuous Integration` I used [strategy.matrix](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions#jobsjob_idstrategymatrix) to build `VS2019` and `VS2022` versions simultaneously as a part of the same pipeline. This mechanism allows me for branching the pipeline and setting `VsTargetVersion` environment variable (which is automatically used by MsBuild) differently for each branch. My workflow for releasing extension for `VS2019` and `VS2022` looks as follows:

![](workflow.jpg)

Here's a complete Github Actions script for releasing an extension that supports VS2019 and VS2022:


```yml
name: release
on:
  push:
    branches:
      - master
    paths:
      - 'src/**'
env: 
  DOTNET_NOLOGO: true
  DOTNET_CLI_TELEMETRY_OPTOUT: true
  RepositoryUrl: 'https://github.com/${{ github.repository }}'
  RepositoryBranch: '${{ github.ref }}'
  SourceRevisionId: '${{ github.sha }}'
  Configuration: Release
  Version: '2021.8.${{ github.run_number }}'
  SolutionPath: src\MappingGenerator.sln    
jobs:
  build-extension:
    runs-on: windows-latest
    strategy:
      matrix:
        VsTargetVersion: ['VS2019', 'VS2022']
    env: 
        VsixManifestPath: src\Manifests\${{ matrix.VsTargetVersion }}\source.extension.vsixmanifest
        VsTargetVersion: '${{ matrix.VsTargetVersion }}'
    steps:
    - name: Checkout repository
      uses: actions/checkout@v2   
    - name: Setup .NET Core 5
      uses: actions/setup-dotnet@v1
      with:
        dotnet-version: '5.0'   
    - name: Setup MSBuild.exe
      uses: microsoft/setup-msbuild@v1.0.2
    - name: Restore NuGet Packages
      run: nuget restore $env:SolutionPath
    - name: Set version for Visual Studio Extension
      uses: cezarypiatek/VsixVersionAction@1.0
      with:
        version: ${{ env.Version }} 
        vsix-manifest-file: ${{ env.VsixManifestPath }}
    - name: Build extension
      run: msbuild $env:SolutionPath /t:Rebuild
      env: 
        DeployExtension: False
    - name: Test extension
      run: dotnet test --no-build --verbosity normal $env:SolutionPath
    - name: Upload VSIX artifact
      uses: actions/upload-artifact@master
      with:
        name: VSIX-${{ matrix.VsTargetVersion }}
        path: 'src\MappingGenerator.Vsix\bin\${{ matrix.VsTargetVersion }}\Release\MappingGeneratorPro${{ matrix.VsTargetVersion }}.vsix'    
  release-extension:
    needs: build-extension  
    runs-on: windows-latest
    steps:
    - name: Support longpaths
      run: git config --system core.longpaths true
    - name: Checkout repository
      uses: actions/checkout@v2   
    - name: Generate release note
      run: |
        git fetch --prune --unshallow
        $commitLog = git log "$(git describe --tags --abbrev=0)..HEAD" --pretty=format:"- %s"
        "What's new: `r`n`r`n$([string]::Join("`r`n",$commitLog))" | Out-File release_note.md -Encoding utf8
    - uses: actions/download-artifact@master
      with:
        name: VSIX-VS2019
        path: dist/
    - uses: actions/download-artifact@master
      with:
        name: VSIX-VS2022
        path: dist/
    - name: Create Github Release
      id: create_release
      uses: actions/create-release@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        tag_name: ${{ env.Version }}
        release_name:  ${{ env.Version }}
        body_path: release_note.md
        draft: false
        prerelease: false
    - name: Upload Release Asset - MappingGenerator.vsix for VS2019
      uses: actions/upload-release-asset@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        upload_url: ${{ steps.create_release.outputs.upload_url }}
        asset_path: 'dist/MappingGeneratorProVS2019.vsix'
        asset_name: 'MappingGeneratorProVS2019.vsix'
        asset_content_type: binary/octet-stream
        prerelease: false
    - name: Upload Release Asset - MappingGenerator.vsix for VS2022
      uses: actions/upload-release-asset@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        upload_url: ${{ steps.create_release.outputs.upload_url }}
        asset_path: 'dist/MappingGeneratorProVS2022.vsix'
        asset_name: 'MappingGeneratorProVS2022.vsix'
        asset_content_type: binary/octet-stream       
    - name: Publish extension to Marketplace for VS2019
      uses: cezarypiatek/VsixPublisherAction@0.1
      with:
        extension-file: 'dist/MappingGeneratorProVS2019.vsix'
        publish-manifest-file: 'src\Manifests\VS2019\publishManifest.json'
        personal-access-code: ${{ secrets.VS_PUBLISHER_ACCESS_TOKEN }}
    - name: Publish extension to Marketplace for VS2022
      uses: cezarypiatek/VsixPublisherAction@0.1
      with:
        extension-file: 'dist/MappingGeneratorProVS2022.vsix'
        publish-manifest-file: 'src\Manifests\VS2022\publishManifest.json'
        personal-access-code: ${{ secrets.VS_PUBLISHER_ACCESS_TOKEN }}  
```

As a result of the `build-extension` job, we have two `vsix` files but the Visual Studio marketplace doesn't have an option of uploading multiple files for a single extension. According to MSDN ([more details here](https://docs.microsoft.com/en-us/visualstudio/extensibility/migration/update-visual-studio-extension?view=vs-2022#visual-studio-marketplace)), this should be possible in the future, but right now we are forced to publish a version for VS2022 as an extension with a different identity. As you might notice, that's the reason why I have two  `publishManifest.json` files for each version of VisualStudio.