---
title: "Collecting memory dumps for .NET Core on Kubernetes"
description: "How to create memory dumps for dotnet core app running in Kubernetes"
date: 2023-08-17T00:10:45+02:00
tags : ["aspcore", "dotnet", "debugging", "Kubernetes"]
highlight: true
highlightLang: ["cs", "json","powershell"]
image: "splashscreen.jpg"
isBlogpost: true
---


In the world of Kubernetes and microservices, diagnosing and debugging issues can be a challenging task. One powerful tool in your troubleshooting arsenal is memory dump analysis. Memory dumps capture the state of an application's memory at a particular point in time, providing insights into potential issues, bottlenecks, and crashes. In this blog post, I'll walk you through the process of collecting a memory dump from a .NET Core application running on Kubernetes.

## Step 1: Getting Started

If you don't already have it, you'll need to install `kubectl`, the command-line tool for interacting with Kubernetes clusters. You can follow the installation instructions provided on the [official Kubernetes documentation](https://kubernetes.io/docs/tasks/tools/) or use the `winget` command if you're on Windows:

```shell
winget install Kubernetes.kubectl
```

Having the kubectl tool installed, begin by identifying the relevant pods using a label selector. For instance, you can list the pods with the label `app.kubernetes.io/instance=YOUR_APP_NAME` in the `YOUR_NAMESPACE_NAME` namespace:

```shell
kubectl get pods --selector=app.kubernetes.io/instance=YOUR_APP_NAME --namespace YOUR_NAMESPACE_NAME -o=name --kubeconfig "path_to_kubeconfig.yaml"
```

The `--kubeconfig` parameter is used to specify the path to the configuration file for authenticating and interacting with a Kubernetes cluster. This file contains information about the cluster's API server, authentication credentials, and context. You can obtain the kubeconfig file from your Kubernetes administrator or generate it yourself if you have access to the cluster. If you are using `Rancher`, follow [this guideline](https://ranchermanager.docs.rancher.com/v2.5/how-to-guides/advanced-user-guides/manage-clusters/access-clusters/use-kubectl-and-kubeconfig#accessing-clusters-with-kubectl-from-your-workstation) to obtain your `kubeconfig` file.

## Step 2: Accessing the Pod
To access the pod and execute commands within it, you can use the `kubectl exec` command. This example assumes you're accessing the pod with the name YOUR_POD_NAME:

```shell
kubectl exec -it "pod/YOUR_POD_NAME" --kubeconfig "path_to_kubeconfig.yaml" --namespace YOUR_NAMESPACE_NAME -- sh

```
You will need to download `dotnet-dump`. However, you might have limited permission regarding saving data to disk in container so it's good to execute the following steps from `/tmp` directory. Navigate to the /tmp directory within the pod:

```shell
cd /tmp
```

## Step 3: Creating a Memory Dump

Now, let's proceed to collect the memory dump for the .NET Core application. Start by downloading the dotnet-dump tool:

```shell
curl -L -o dotnet-dump https://aka.ms/dotnet-dump/linux-x64
```

Give the necessary permissions to the downloaded tool:

```shell
chmod 777 ./dotnet-dump
```

Specify an extraction directory for the tool:


```shell
export DOTNET_BUNDLE_EXTRACT_BASE_DIR="/tmp/bundle_extract"
```

Now, initiate the memory dump collection. Replace 1 with the appropriate process ID of your .NET Core application:

```shell
./dotnet-dump collect -p 1
```

The collected memory dump will be saved as core_<timestamp> in the /tmp directory.

## Step 4: Archiving the Memory Dump
Once the memory dump is generated, you can compress it for easier transfer and analysis:

```shell
gzip core_<timestamp>
```

## Step 5: Downloading the Memory Dump

Now that the memory dump is ready, you can copy it from the pod to your local machine using the kubectl cp command. 

First you need to exit the pod console:

```shell
exit
```

Being back on your workstation console, execute the following command to download the memory file to your machine:

```shell
kubectl cp "YOUR_POD_NAME:/tmp/core_<timestamp>.gz" ./core_<timestamp>.gz --kubeconfig "path_to_kubeconfig.yaml" --namespace YOUR_NAMESPACE_NAME
```

## Step 5: Unpacking the Memory Dump

Now you need to unpack the memory dump file. You can do that with `Total Commander` or using the PowerShell script that I found here [Unzip GZ files using Powershell](https://social.technet.microsoft.com/Forums/windowsserver/en-US/5aa53fef-5229-4313-a035-8b3a38ab93f5/unzip-gz-files-using-powershell?forum=winserverpowershell)


Now you are ready to start a memory analysis. You can do that with VisualStudio, WindDBG or with dotMemory.

## Everything Everywhere All at Once

All the steps described above can be compiled into a simple `PowerShell` script to bring the whole process to a single command execution.


```powershell
param (
  [Parameter(Mandatory=$true)][string] $PodName,
  [Parameter(Mandatory=$true)][string] $Namespace,
  [Parameter(Mandatory=$true)][string] $KubeconfigFile,
  [Parameter(Mandatory=$true)][string] $OutputDirectory
)


Write-Host "Preparing dump file"

$linuxDumpScript = @"
cd /tmp && \
curl -L -o dotnet-dump https://aka.ms/dotnet-dump/linux-x64 && \
chmod 777 ./dotnet-dump && \
export DOTNET_BUNDLE_EXTRACT_BASE_DIR='/tmp/bundle_extract' && \
./dotnet-dump collect -p 1
"@ -replace "`r`n","`n"

$dumpLog = kubectl exec -it "pod/$PodName" --kubeconfig $KubeconfigFile --namespace "$Namespace" -- sh -c $linuxDumpScript.Trim() 

Write-Host $dumpLog

$pattern = "Writing full to (.*?)Complete"
$matches = [Regex]::Matches($dumpLog, $pattern)

if ($matches.Count -eq 0) {
    Write-Error "Cannot find dump file name"
    return
}

$dumpFile = $matches[0].Groups[1].Value.Trim()

Write-Host "Dump file $($matches[0].Groups[1].Value)"
Write-Host "Packing dump file"

kubectl exec -it "pod/$PodName" --kubeconfig $KubeconfigFile --namespace "$Namespace" -- sh -c "gzip $dumpFile" | Out-Host

$fileName = [System.IO.Path]::GetFileName($dumpFile)
$archiveFileName = "$fileName.gz"

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = "."
}

# Relative path is required by `kubectl cp`
$directoryRelativePath = Resolve-Path -Relative $OutputDirectory
$outputFile = Join-Path $directoryRelativePath $archiveFileName
Write-Host "Downloading dump file to $outputFile"

kubectl cp "$PodName`:$dumpFile`.gz" $outputFile --kubeconfig $KubeconfigFile --namespace $Namespace

function DeGZip-File {
    param (
        $infile,
        $outfile = ($infile -replace '\.gz$', '')
    )

    $input = [System.IO.File]::OpenRead($inFile)
    $output = [System.IO.File]::Create($outFile)
    $gzipStream = [System.IO.Compression.GzipStream]::new($input, [System.IO.Compression.CompressionMode]::Decompress)

    $buffer = [byte[]]::new(1024)
    while ($true) {
        $read = $gzipStream.Read($buffer, 0, 1024)
        if ($read -le 0) { break }
        $output.Write($buffer, 0, $read)
    }

    $gzipStream.Close()
    $output.Close()
    $input.Close()
}

Write-Host "Unpacking dump file"

DeGZip-File (Join-Path $OutputDirectory $archiveFileName) (Join-Path $OutputDirectory $fileName)
```

Save the script as `MemoryDump.ps1` file and enjoy creating memory dumps with this single line:

```powershell
./MemoryDump.ps1 -PodName 'YOUR_POD_NAME' -Namespace 'YOUR_NAMESPACE' -KubeconfigFile './YOUR_KUBECONFIG.yaml'

```


## Conclusion

Collecting memory dumps from applications running on Kubernetes can provide valuable insights into their state during critical moments. Armed with the information from memory dumps, you can more effectively troubleshoot and address issues within your .NET Core applications. Remember that memory dump analysis requires familiarity with debugging tools and techniques, but it's a skill that can significantly enhance your ability to maintain and improve your applications' performance and reliability.
