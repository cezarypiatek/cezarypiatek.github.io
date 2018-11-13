---
title: "Tips and Tricks for managing ELK configuration"
description: "My last discoveries which help me work more effectively with ELK."
date: 2018-11-13T00:21:18+02:00
tags : ["Logstash", "ElasticSearch", "ELK", "Filebeat", "logging", "powershell"]
highlight: true
highlightLang: ["yaml","powershell"]
image: "splashscreen.jpg"
isBlogpost: true
draft: false
---

A few months ago I published "[Demystifying ELK stack](/post/demystifying-elk-stack/)" article that summarizes my knowledge about setting up and configuring the system for collecting, processing and presenting logs, based on Filebeat, Logstash, Kibana, and Elasticsearch. Since then I've learned a few new DevOps things which help me and my teammates to work more effectively with ELK. I think they're worth sharing.
<!--more-->

## Shrinking Filebeat configuration
I use `Filebeat` to collect data from log files and send them to `Logstash` for further processing and analyzing. `Filebeat` configuration is in `YAML` format and the most important part of it is the section `filebeat.prospectors` which is responsible for configuring harvesting data. A sample configuration looks as follows:

```yaml
filebeat.prospectors:
- input_type: log
  paths:
    - c:\inetpub\wwwroot\MyApp\logs\Client.Web.log
  scan_frequency: 10
  encoding: utf-8
  multiline.pattern: '^(\d{4}-\d{2}-\d{2}\s)'
  multiline.negate: true 
  multiline.match: after  
  fields_under_root: true
  fields:
    app_env: test
    app_name: client
    type: web
```

Currently, I have 10 internal environments for different purposes (manual testing, automated UI testing, load testing, presentations for different customers etc.). Each environment consists of two web applications and each of them produces 2 log files (diagnostic and performance data). That gives me `10 * 2 * 2 = 40` log files and for every single one of them, I have to configure a separate prospector. I can't use a single prospector with a wildcard in the `path` attribute because there is a need to add additional metadata, such as environment name, app name and log type (attributes defined in the `fields` node).  However, some of the attributes are the same for every prospector which causes a massive configuration duplication and makes it harder to modify those common values. I was even thinking about preparing some kind of template for prospector configuration with custom `PowerShell` script that could facilitate creating a config for the entire environment. Instead of rushing to develop an in-house solution though, I started from browsing `YAML` specification and I found [Merge Key Language-Independent Type](http://yaml.org/type/merge.html) which seemed to be a solution to my problem. The ``!!merge`` feature together with `Anchors and Aliases` allows to define and reuse keys of the map - simply speaking it's a kind of variables in YAML files. In the following example, I've defined a common configuration with anchor `&PROSPECTOR_COMMON_OPTIONS` and merge it into any prospector configuration with `<< :` operator. 

```yaml
PROSPECTOR_COMMON_OPTIONS : &PROSPECTOR_COMMON_OPTIONS
    scan_frequency: 10
    encoding: utf-8
    multiline.pattern: '^(\d{4}-\d{2}-\d{2}\s)'
    multiline.negate: true
    multiline.match: after  
    fields_under_root: true

filebeat.prospectors:
- input_type: log
  paths:
    - C:\logs\manualtest\Client.Web.log
  << : *PROSPECTOR_COMMON_OPTIONS
  fields:
    app_env: manualtest
    app_name: client
    type: web

- input_type: log
  paths:
    - C:\logs\automatedui\Office.Web.log
  << : *PROSPECTOR_COMMON_OPTIONS
  fields:
    app_env: automatedui
    app_name: office
    type: web
```

Thanks to this little trick I was able to reduce the number of entries in my `Filebeat` configuration and improve its maintainability. A lot of people criticize `YAML` for being hard to read and edit - in comparizon to `JSON` format - but it has some less known features which give it more possibilities than `JSON` has.


## Temporary variables in Logstash configuration

In the [Be the first to know of the bug](/post/be-the-first-to-know-of-the-bug/) article I described how we can easily integrate `Logstash` with `Microsoft Teams` to create some kind of early-warning system. In the proposed solution I used `mutate` filter  to create extra fields which hold additional data consumed only by the `output` section, for example URL for Kibana filter, Jira create issue link or `Microsft Teams` webhook. After a while, I've realized that this additional data is unnecessarily stored in `ElasticSearch` index and consumes a lot of space. Thankfully, the authors of Filebeat foresaw the need for temporal variables and introduced [Logstash Metadata](https://www.elastic.co/blog/logstash-metadata). Now, instead of adding fields to events only for processing purpose, we can store them in the dedicated `@metadata` field:

```js
 mutate
 {
    add_field =>
    {
        "[@metadata][webhookUrl]" => "https://outlook.office.com/webhook/0c744aca-7d19-4556/IncomingWebhook/ceb6ba15106147a57e14e03d662de6/86aafacf-4c13-9780-5d9063b10fb6"
    }
}
```

## Automating the configuration update

Every time I changed `Logstash` or `Filebeat` configuration I had to log in to the appropriate server, replace the old config with the new one, restart the service and examine the service log file if the whole operation was successful. If something failed, I needed to correct the config file and repeat the whole routine. It was a very tedious process and nobody in the team besides me knew to how to do it. I even wrote the whole instruction down but the number of steps or the need to log into `Linux` server repealed others. A better solution than creating manual instruction is to automate the process. The easiest part was to create the script that updates `Filebeat` configuration because it resides on the Windows server:

```powershell
function Update-FilebeatConfig
{
    [CmdletBinding()]
    param(
        $ComputerName, 
        $Credentials, 
        $FilebeatSrcFile
     )
    $session = New-PSSession -ComputerName $ComputerName -Credential $Credentials
    Copy-Item $FilebeatSrcFile -Destination "C:\Tools\Filebeat\" -ToSession $session -Force
    Invoke-Command -Session $session -ScriptBlock {
        Write-Verbose "Restarting filebeat..."
        Restart-Service filebeat
        Get-Service filebeat
        Write-Verbose "Filebeat restart finished."
    }
    Remove-PSSession -Session $session
}
```

Now everybody can easily update Filebeat configuration by invoking this function as follows:

```powershell
Update-FilebeatConfig -ComputerName "app.server.lan" -Credentials (Get-Credential) -FilebeatSrcFile "./filebeat.yml" -Verbose
```

### PowerShell Core on Linux

However, the real challenge for me was to automate the same process for `Logstash` configuration that lives on the `Linux` server. I started by installing `PowerShell Core` on my Linux server with the following commands:

```bash
sudo apt-get install libunwind8 libicu55 liblttng-ust0
wget https://github.com/PowerShell/PowerShell/releases/download/v6.1.0/powershell_6.1.0-1.ubuntu.16.04_amd64.deb
sudo dpkg -i powershell_6.1.0-1.ubuntu.16.04_amd64.deb
sudo apt-get install -f
```

Depending on your Linux distribution and version you might need to use a different package of [`PowerShell Core`](https://github.com/PowerShell/PowerShell/releases)
If you are working on `Ubuntu`, you can check your current version with `lsb_release -a` command. If everything went well, you should be able to enter the `PowerShell` console with `pwsh` command. 

Beside installing `PowerShell` I also needed to enable `PowerShell Remoting`. This can be accomplished by installing `OMI PSRP` packages:

```bash
wget https://github.com/PowerShell/psl-omi-provider/releases/download/v1.4.1-28/psrp-1.4.1-28.universal.x64.deb
wget https://github.com/Microsoft/omi/releases/download/v1.4.2-5/omi-1.4.2-5.ssl_100.ulinux.x64.deb
sudo dpkg -i omi-1.4.2-5.ssl_100.ulinux.x64.deb
sudo dpkg -i psrp-1.4.1-28.universal.x64.deb
```

Despise all my concerns the installation went pretty smoothly (I only needed to adjust the version of package responsible for `SSL`) and I was able to remotely invoke command on the Linux server from my Windows workstation with `Invoke-Command` cmdlet.  Then I was able to easily automate the process of updating `Logstash` config:

```powershell
$sharedContext = {
    function Watch-File {
        [CmdletBinding()]
        param (
            [string] $FileName,
            [string] $StopContentPositive,
            [string] $StopContentNegative
        )
        $ErrorActionPreference = "Stop"    
        $stream =  New-Object  System.IO.FileStream $FileName, ([System.IO.FileMode]::Open), ([System.IO.FileAccess]::Read), ([System.IO.FileShare]::ReadWrite)
        $tries = 0
        $maxTries = 100
        
        try{
            try{
                $stream.Seek(0,  [IO.SeekOrigin]::End)
                $streanReader = New-Object System.IO.StreamReader $stream, ([System.Text.Encoding]::UTF8)
                do{
                    $line = $streanReader.ReadLine() 
                    $tries = $tries +1
                    if($null -eq $line)
                    {                    
                        Start-Sleep -Seconds 2
                    }else{
                        Write-Verbose $line
                    }
                    
                    if($line -like "*$StopContentNegative*")
                    {
                        Write-Error "Cannot restart logstash"
                        break;
                    }
                    
                }while ((-not ($line -like "*$StopContentPositive*")) -and ($tries -lt $maxTries)) 
    
                if($tries -eq $maxTries){
                    Write-Error "Cannot restart logstash"
                }               
            }finally{
                $streanReader.Dispose()
            }    
        }finally{
            $stream.Dispose()
        }
       
    }
}

function Update-LogstashConfig
{
    [CmdletBinding()]
    param(
            $ComputerName, 
            $Credentials, 
            $LogstashSrcFile
        )

    $sessionOptions = New-PSSessionOption -SkipCACheck -SkipRevocationCheck -SkipCNCheck
    $session = New-PSSession -ComputerName $ComputerName -Credential $Credentials -Authentication basic -UseSSL -SessionOption $sessionOptions
    Copy-Item $LogstashSrcFile -Destination /etc/logstash/conf.d/ -ToSession $session -Force
    Invoke-Command -Session $session -ScriptBlock {
        . ([scriptblock]::Create($using:sharedContext))   
        Write-Verbose "Restarting logstash..."
        systemctl restart logstash
        Watch-File -FileName "/var/log/logstash/logstash-plain.log" -StopContentPositive "Pipelines running" -StopContentNegative "Failed to execute action"
    } 
    Remove-PSSession -Session $session
}
```

I've enriched my script with `Watch-File` function that forwards `Logstash` logs and blocks the process until the restart is finished. Thanks to that we have a live stream of what is going on during the restart. The Logstash config update can be performed with the command:

```powershell
Update-LogstashConfig -ComputerName 'elk.server.lan' -Credentials (Get-Credential) -LogstashSrcFile "./logstash/App.conf" -Verbose
```


I've put all of the above scripts together with the config files in the source control so everybody in the team can easily modify and deploy new ELK configuration.


## TL;DR
Thanks to `!!merge, Anchors and Aliases` I can simulate variables in `YAML` and create reusable parts of `Filebeat` configuration. The  Logstash `@metadata` field allows me to create variables needed only for processing logic without polluting `ElasticSeach` indices. With `PowerShell Core` I can easily manage Linux servers directly from my Windows workstation and automatically deploy `ELK` configuration.