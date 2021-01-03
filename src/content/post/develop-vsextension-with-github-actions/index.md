---
title: "Github Actions for Visual Studio Extension developers"
description: "How to completely automate continuous integration and release management of visual studio extensions."
date: 2021-01-24T10:00:45+02:00
tags : ["dotnet", "dotnetcore", "VisualStudio", "Github", "GithubActions"]
highlight: true
highlightLang: ["yaml", "powershell"]
image: "splashscreen.jpg"
isBlogpost: true
---

I discovered the power of Roslyn over three years ago and since then I've developed [three Visual Studio extensions](https://marketplace.visualstudio.com/publishers/54748ff9-45fc-43c2-8ec5-cf7912bc3b84) and [a couple of code analyzers](https://github.com/cezarypiatek?tab=repositories&q=analyzer&type=source&language=). Because I work on those tools only in my free time, the word "time" is a key here, so automation really matters. So far I've been using [AppVeyor](https://www.appveyor.com/) for building and testing my extensions. However, I'm a huge fan of integrated solutions because they require much less work for setup, and since GithubActions became generally available I wanted to give it a try.

## Automate CI/CD for VSIX 

The official [GithubActions documentation](https://docs.github.com/en/free-pro-team@latest/actions) together with [actions/starter-workflows](https://github.com/actions/starter-workflows/) repository are really good starting points. Unfortunately, I didn't find there a complete example workflow for building an publishing Visual Studio extensions. After around 10 hours of googling and experimenting, I managed to assemble two complete workflows: one for Pull Request verification and one for automatic release.


## Problems

### You can't build with `dotnet build`

After a few hours of struggling with the compilation, I discovered that you can't build a solution that contains VSIX project with `dotnet build` even if all your projects are in the new `csproj2017` format ([Issue#12421](https://github.com/dotnet/sdk/issues/12421)). This kind of solution needs to be built with the `msbuild` directly. The windows based virtual environment for Github Actions has pre-installed msbuild. Unfortunately, the path to `msbuild` is not added automatically to the PATH environment variable and we need to somehow figure out where it is installed. This can be solved with a little bit of scripting and [vswhere](https://docs.microsoft.com/en-us/visualstudio/install/tools-for-managing-visual-studio-instances?view=vs-2019) or we can use a dedicated Github Action for that:

```yml
- name: Setup MSBuild.exe
  uses: microsoft/setup-msbuild@v1.0.2
  with:
    vs-version: '[16.8,16.9)'
```

After that you can invoke `msbuild` without providing a path for it:

```yml
- name: Build extension
  run: msbuild $env:SolutionPath /t:Rebuild
  env: 
    DeployExtension: False
```

I also passed `DeployExtension` environment variable to the build step. Without it, the build might take quite long or even timeout while executing `DeployVsixExtensionFiles` build task.

### What's the next version
When I was building my extension using `AppVeyor` service, I hardcoded extension version in the build script using the `{Major}.{Minor}.{BuildNumber}` format. So my first approach was to move that mechanism to GithubActions and it was quite easy to implement by taking leverage of environment variables (you can read more about in [Setting assembly and nuget package metadata in .NET Core](/post/setting-assembly-and-package-metadata/)):

```yml
build-extension:
  runs-on: windows-latest
  env: 
    Version: '1.21.${{ github.run_number }}'
```

However, this approach has a few disadvantages. Every time before releasing a version with new features I needed to manually modify build script by updating `{Major}.{Minor}` part, which resulted with additional commit. It was required every single time (yes, I forgot about it a couple of times) and this unnecessarily pollutes the git history. Such disadvantage requires more attention and work during releases, so I started looking for a better solution. There's plenty of different tools that allow bumping up version based on the git tag, but I got a really good inspiration when I discovered the [semantic-release](https://github.com/semantic-release/semantic-release) project. Those tools allow for generating next version which obeys [semantic versioning specification](https://semver.org/) based on the [Angular convention commits](https://github.com/angular/angular.js/blob/master/DEVELOPERS.md#-git-commit-guidelines). I didn't use that notation - and not sure if I want to - but this gave me an idea for a new Github Action that could read the latest version tag from the repository and bump it up based on the predefined message patterns. The outcome is available as [NextVersionGeneratorAction](https://github.com/cezarypiatek/NextVersionGeneratorAction) project and it can be easily used and adjusted to our own message conventions as follows:

```yml
- name: Calculate next version
  uses: cezarypiatek/NextVersionGeneratorAction@0.4
  with:
    major-pattern: 'BREAKING CHANGES:'
    minor-pattern: 'FEATURE:'
    patch-pattern: '.*'
    output-to-env-variable: 'Version'
```

### How to set the version for VSIX file

The version of VSIX file is not taken from the build configuration because it is defined in external file `source.extension.vsixmanifest` and it must be set separately. We can update version number in manifest file using `PowerShell` script step:

```yml
- name: Set version for VSIX
  run: |
    $manifestPath = 'src\MappingGenerator.Vsix\bin\Release\MappingGenerator.vsix'
    $manifestXml = [xml](Get-Content $manifestPath -Raw)
    $manifestXml.PackageManifest.Metadata.Identity.Version = $env:Version
    $manifestXml.save($manifestPath)
```
However, repeating this script in every repository might be quite tedious, so I created a Github Action dedicated for that job and it can be used as follows:

```yml
- name: Set version for Visual Studio Extension
  uses: cezarypiatek/VsixVersionAction@1.0
  with:
    version: ${{ env.Version }}
    vsix-manifest-file: 'src\MappingGenerator.Vsix\source.extension.vsixmanifest'
```

The source code for the action is available on Github [cezarypiatek/VsixVersionAction](https://github.com/cezarypiatek/VsixVersionAction)

### How to publish extension to the Marketplace

So far I was publishing my extensions by manually downloading artifact with VSIX file from the build server to my disc and then uploading it to the Marketplace via [marketplace.visualstudio.com](https://marketplace.visualstudio.com/) website. That operation is also time-consuming and may raise security concerns. Happily, this can be automated with [VsixPublisher](https://docs.microsoft.com/en-us/visualstudio/extensibility/walkthrough-publishing-a-visual-studio-extension-via-command-line?view=vs-2019) which is also pre-installed on the Windows based virtual environment for Github Actions. However, with `VsixPublisher` we have the same problem as with `msbuild` - the tool's executable path is not available in the `PATH` environment variable and we need to hardcode it or write a script that would be able to automatically locate it. To simplify things, I created [VsixPublisherAction](https://github.com/cezarypiatek/VsixPublisherAction) which makes the publishing super easy:

```yml
- name: Publish extension to Marketplace
  uses: cezarypiatek/VsixPublisherAction@0.1
  with:
    extension-file: 'src\MappingGenerator.Vsix\bin\Release\MappingGenerator.vsix'
    publish-manifest-file: 'src\MappingGenerator.Vsix\publishManifest.json'
    personal-access-code: ${{ secrets.VS_PUBLISHER_ACCESS_TOKEN }}
```
Beside the `*.vsix` file, we need also the [publishManifest file](https://docs.microsoft.com/en-us/visualstudio/extensibility/walkthrough-publishing-a-visual-studio-extension-via-command-line?view=vs-2019#publishmanifest-file) and [Personal Access Token](https://code.visualstudio.com/api/working-with-extensions/publishing-extension#get-a-personal-access-token) which should be stored in [Repository Encrypted Secrets](https://docs.github.com/en/actions/reference/encrypted-secrets).

## PR Workflow

This workflow is responsible for verifying Pull Request. It should build and test code with changes introduced by PR and should produce artifacts that can be used for manual testing - I very often ask the issue reporter to verify if a new proposed version is working according to the expectations. This workflow should be triggered every time a new PR is created, or the existing one is updated with newer changes. My typical workflow for PR looks as follows:

1. Set up the build environment
    - Setup .NET Core
    - Setup MsBuild
2. Calculate next version number
3. Build the extension
    - Restore NuGet packages
    - Set version for VSIX
    - Invoke the `msbuild` to build the solution
4. Execute Test suite
5. Collect artifacts to allow manual verification

This workflow can be automated with Github Actions using the following script:

```yml
name: pr-verification
on:
  pull_request:
    types: [opened, synchronize, reopened]
jobs:
  build-extension:
    runs-on: windows-latest
    env: 
        DOTNET_NOLOGO: true
        DOTNET_CLI_TELEMETRY_OPTOUT: true
        RepositoryUrl: 'https://github.com/${{ github.repository }}'
        RepositoryBranch: '${{ github.ref }}'
        SourceRevisionId: '${{ github.sha }}'
        VersionSuffix: 'pr-${{github.event.number}}.${{ github.run_number }}'
        Configuration: Release
        SolutionPath: src\MappingGenerator.sln
        VsixManifestPath: src\MappingGenerator.Vsix\source.extension.vsixmanifest
    steps:
    - uses: actions/checkout@v2   
    - name: Setup .NET Core
      uses: actions/setup-dotnet@v1
      with:
        dotnet-version: '3.1.x'
    - name: Setup MSBuild.exe
      uses: microsoft/setup-msbuild@v1.0.2
      with:
        vs-version: '[16.8,16.9)'
    - name: Restore NuGet Packages
      run: nuget restore $env:SolutionPath
    - name: Calculate next version
      uses: cezarypiatek/NextVersionGeneratorAction@0.4
      with:
        minor-pattern: '\bAdd\b'
        patch-pattern: '.*'
        output-to-env-variable: 'VersionPrefix'
    - name: Set version for Visual Studio Extension
      uses: cezarypiatek/VsixVersionAction@1.0
      with:
        version: '${{env.VersionPrefix}}+${{env.VersionSuffix}}'
        vsix-manifest-file: ${{ env.VsixManifestPath }}
    - name: Build extension
      run: msbuild $env:SolutionPath /t:Rebuild
      env: 
        DeployExtension: False
    - name: Test extension
      run: dotnet test --no-build --verbosity normal $env:SolutionPath
    - name: Collect artifacts - VSIX
      uses: actions/upload-artifact@v2
      with:
        name: MappingGenerator-VSIX
        path: src\MappingGenerator.Vsix\bin\Release\MappingGenerator.vsix
    - name: Collect artifacts - nugets
      uses: actions/upload-artifact@v2
      with:
        name: MappingGenerator-Nugets
        path: '**/MappingGenerator*.nupkg'
```
**REMARKS**: 

1. Packages generated by the PR builds should be marked as `pre-release`, so I'm storing the next version number in `VersionPrefix` environment variable, and there's also `VersionSuffix` variable defined as `pr-${{github.event.number}}.${{ github.run_number }}`. An example version produced with this approach can be `1.22.1-pr-163.55`. The `msbuild` can handle the `VersionPrefix` and `VersionSuffix` variables, however in the build step for setting `VSIX` version we need to define it explicitly `'${{env.VersionPrefix}}+${{env.VersionSuffix}}'`.

2. At the beginning of the build script I defined `RepositoryUrl`, `RepositoryUrl`, and `SourceRevisionId`environment variables. Thanks to that `NuGet package` and `dotnet assemblies` will contain information about the repository address, branch name, and commit identifier which was used to produce those artifacts.

To make it work correctly, the project files can't contain the definition of any of those variables. You can read more about that in [Setting assembly and NuGet package metadata in .NET Core](/post/setting-assembly-and-package-metadata/).

## Release Workflow 

I needed another workflow that would be triggered when the PR is merged, or the commit is directly pushed to the `master` branch. Release workflow is an extended version of the PR-Verification, and beside building and testing my extension, it should also publish the extension to the Visual Studio Marketplace and the Nuget feed:

1. Set up the build environment
    - Setup .NET Core
    - Setup MsBuild
2. Calculate next version number
3. Build the extension
    - Restore NuGet packages
    - Set version for VSIX
    - Invoke the `msbuild` to build the solution
4. Execute Test suite
5. Generate release note
6. Create github release
    - Create the new release with git tag
    - Upload artifacts (`vsix` and `nupkg` files) to the newly create release
7. Upload the Visual Studio Extension to Visual Studio Marketplace
8. Upload NuGet packages

This workflow can be automated with Github Actions using the following script:

```yml
name: release
on:
  push:
    branches:
      - master
    paths:
      - 'src/**'
      - '!src/.editorconfig'
jobs:
  build-extension:
    runs-on: windows-latest
    env: 
        DOTNET_NOLOGO: true
        DOTNET_CLI_TELEMETRY_OPTOUT: true
        RepositoryUrl: 'https://github.com/${{ github.repository }}'
        RepositoryBranch: '${{ github.ref }}'
        SourceRevisionId: '${{ github.sha }}'
        Configuration: Release
        SolutionPath: src\MappingGenerator.sln
        VsixManifestPath: src\MappingGenerator.Vsix\source.extension.vsixmanifest
        VsixPath: src\MappingGenerator.Vsix\bin\Release\MappingGenerator.vsix
        VsixPublishManifestPath: src\MappingGenerator.Vsix\publishManifest.json
    steps:
    - name: Checkout repository
      uses: actions/checkout@v2   
    - name: Setup .NET Core
      uses: actions/setup-dotnet@v1
      with:
        dotnet-version: '3.1.x'
    - name: Setup MSBuild.exe
      uses: microsoft/setup-msbuild@v1.0.2
      id: MsBuildSetup
      with:
        vs-version: '[16.8,16.9)'
    - name: Restore NuGet Packages
      run: nuget restore $env:SolutionPath
    - name: Calculate next version
      uses: cezarypiatek/NextVersionGeneratorAction@0.4
      with:
        minor-pattern: '\bAdd\b'
        patch-pattern: '.*'
        output-to-env-variable: 'Version'
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
    - name: Generate release note
      run: |
        git fetch --prune --unshallow
        $commitLog = git log "$(git describe --tags --abbrev=0)..HEAD" --pretty=format:"- %s"
        "What's new: `r`n`r`n$([string]::Join("`r`n",$commitLog))" | Out-File release_note.md -Encoding utf8
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
    - name: Upload Release Asset - VSIX
      uses: actions/upload-release-asset@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        upload_url: ${{ steps.create_release.outputs.upload_url }}
        asset_path: ${{ env.VsixPath }}
        asset_name: MappingGenerator.vsix
        asset_content_type: binary/octet-stream
    - name: Upload Release Asset - Nuget
      uses: actions/upload-release-asset@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        upload_url: ${{ steps.create_release.outputs.upload_url }}
        asset_path: src\MappingGenerator\bin\Release\MappingGenerator.${{ env.Version }}.nupkg
        asset_name: MappingGenerator.${{ env.Version }}.nupkg
        asset_content_type: binary/octet-stream
    - name: Publish extension to Marketplace
      uses: cezarypiatek/VsixPublisherAction@0.1
      with:
        extension-file: ${{ env.VsixPath }}
        publish-manifest-file: ${{ env.VsixPublishManifestPath }}
        personal-access-code: ${{ secrets.VS_PUBLISHER_ACCESS_TOKEN }}      
    - name: Publish extension to Nuget
      run: |
        dotnet nuget push src\MappingGenerator\bin\Release\MappingGenerator.*.nupkg -k ${{ secrets.NUGET_API_KEY }} -s https://api.nuget.org/v3/index.json
```

**REMARKS:**

1. In the trigger's configuration, I defined the `paths` option. Thanks to that, the workflow will be triggered only when there are changes that affect the binaries. Updating documentation files (especially `README.md`) will not result in releasing a new version.

2. This workflow creates the official packages, so this time I'm storing the next version in the `Version` environment variable.

3. All tokens required for packages publishing are stored in [Repository Encrypted Secrets](https://docs.github.com/en/actions/reference/encrypted-secrets).
