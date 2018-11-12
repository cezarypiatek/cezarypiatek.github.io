---
title: "Tips and Tricks for managing ELK configuration"
description: "How to easily implement centralized logging system based on ELK stack."
date: 2018-11-12T00:21:18+02:00
tags : ["Logstash", "ElasticSearch", "ELK", "Filebeat", "logging", "powershell"]
highlight: true
highlightLang: ["yaml"]
image: "splashscreen.jpg"
isBlogpost: true
draft: false
---

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


```yaml
COMMON_OPTIONS : &COMMON_OPTIONS
    scan_frequency: 10
    encoding: utf-8
    multiline.pattern: '^(\d{4}-\d{2}-\d{2}\s)'
    multiline.negate: true
    multiline.match: after  
    fields_under_root: true


filebeat.prospectors:
- input_type: log
  paths:
    - C:\logs\demo_experimental\Client.Web.log
  << : *COMMON_OPTIONS
  fields:
    app_env: experimental
    app_name: client
    type: web

- input_type: log
  paths:
    - C:\logs\demo_experimental\Office.Web.log
  << : *COMMON_OPTIONS
  fields:
    app_env: experimental
    app_name: office
    type: web
```