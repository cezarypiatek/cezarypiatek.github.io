---
title: "Create Roslyn refactoring with UI configuration"
description: "How to create Roslyn refactoring that can be configured throwgh dedicated option window"
date: 2018-11-03T00:21:18+02:00
tags : ["Roslyn", "refactoring", "visualstudio"]
scripts : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js", "//cdnjs.cloudflare.com/ajax/libs/fitvids/1.2.0/jquery.fitvids.min.js"]
css : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css"]
image: "splashscreen.jpg"
isBlogpost: true
draft: false
---


1. Add Refactoring solution
 - Define `IOptionsProvider` interface
 - Import `IOptionsProvider` using MEF
 - Add class that inherit from `CodeActionWithOptions`
 - Register refactoring using `CodeActionWithOptions`
2. Add UI services project
  - Implement IOptionsProvider
  - Add references
    - Microsoft.VisualStudio.Shell.15.0,
    - PresentationCore
    - PresentationFramework
    - System.ComponentModel.Composition
    - WindowsBase
  - Add DiaglogWindow with options

  ```xaml
  <platformUi:DialogWindow x:Class="MappingGenerator.Vsix.SampleWindow"
                 xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                 xmlns:ui="clr-namespace:Microsoft.VisualStudio.PlatformUI;assembly=Microsoft.VisualStudio.Shell.15.0"
                 xmlns:platformUi="clr-namespace:Microsoft.VisualStudio.PlatformUI;assembly=Microsoft.VisualStudio.Shell.15.0"
                 Title="Convert to record options" Height="160" Width="320">
    <Grid Height="auto" Width="300" Margin="10">
        <StackPanel Orientation="Vertical">
            <CheckBox>Remove setters</CheckBox>
            <CheckBox>Add initialization constructor</CheckBox>
            <CheckBox>Implement Equals method</CheckBox>
            <CheckBox>Implement GetHashCode method</CheckBox>            
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,10">
                <Button Content="Apply" Name="btnYes" Click="btnYes_Click" Height="25" Width="75" Margin="5" HorizontalAlignment="Center"  />
                <Button Content="Cancel" Name="btnNo" Click="btnNo_Click" Height="25" Width="75" HorizontalAlignment="Right" />
            </StackPanel>
        </StackPanel>
    </Grid>
</platformUi:DialogWindow>
```
3. Add MEF asset to vsix manifest
4. Add testing project
 - Install RoslynNUnitLigth
 - Add test with mocked configuration
