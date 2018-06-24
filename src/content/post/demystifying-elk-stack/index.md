---
title: "Demystifying ELK stack"
description: "How to easily implement centralized loging system based on ELK stack."
date: 2018-06-17T00:05:18+02:00
tags : ["Kibana", "Logstash", "ElasticSearch", "ELK", "Filebeat", "logging"]
scripts : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js", "//cdnjs.cloudflare.com/ajax/libs/fitvids/1.2.0/jquery.fitvids.min.js"]
css : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css"]
image: "splashscreen.jpg"
isBlogpost: true
draft: false
---
![splashscreen](splashscreen.jpg)


The purpose of this blog post is to summarize my knowledge about settuping ELK stack for existing project without need to make any changes in your codebase. The first time when I tried to do that it took me a few days. In the last project (It was the four time) I was able to make it work in three hours. My application is build with ASP.NET framework hosted on IIS and logging with `log4net`, but it doesn't mattern because ELK is capable to collect, process, store and presents logs that comes in any formats. I hope you can find this notes valuable and it helps you to save some time.

## Introduction
 - collecting logs from multiple servers, appps, in different formats
 - at first it may sounds complicated but I do my best to clarify this topic here. I will show you step by step how to implement ELK in your existing project without making any changes in your code base.

## Setup ELK

At first you need a Linux serwer which will be responsible for processing and storing log data. You have to install there ElasticSearch, Logstash and Kibana. You can do it manually by yourself or save a lot of time and use preconfigured docker images. In the docker path we have two options:

 - Single image https://elk-docker.readthedocs.io/ All services are packed into single image. This is not an official release but the documentation is excellent.
 - Docker compose https://github.com/deviantony/docker-elk Every service comes as a separated official docker image combine together with docker compose file.

Because the both solutions are very well documented it's needles to duplicate it here.


## Collecting logs with Filebeat

Filebeat is responsible for collecting your log data and send it to Logstash. In order to install Filebeat download appriopiate archive with binarries from https://www.elastic.co/downloads/beats/filebeat and extract it on the serwer where your logs are stored. I'm not recomending choosing `c:\Program Files\` or `c:\Program Files (x86)\` paths because `user access control` make it hard to update configuration file. After extracting archive, open `PowerShell` console, go to the dicrectory with FileBeat binaries and execute the following scrip

```powershell
./install-service-filebeat.ps1
```

This should install `filebeat` as a Windows service. Use `Get-Service filebeat` to verify the current status of filebeat service. In the next step you have to configure filebeat to harvest log data produced by your application. Filebeat havesting configuration is located in `filebeat.yml` file and minimal configuration that works for me looks as follows:


```yml
filebeat.prospectors:
- input_type: log
  paths:
    - c:\inetpub\wwwroot\MyApp\logs\
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

output.logstash:  
  hosts: ["10.0.2.12:5044"]
  bulk_max_size: 1024
```

To make it work with your log data you should modifie the following options:

 - `paths` should point to the location where your app is producing files with logs. Directory paths are accepted and conrete files as well (wildcards are accepted to)
 - `multiline.pattern` - regex pattern that match the begining of the new log entry inside the log file. In my case I'm expecting a line that starts with a date in the follogin format yyyy-MM-dd.
 - `fields` - a set of additional attributes that will be added to each log entry. I'm using it later to build ElasticSearch index and identifie the logs source.
 - `output.logstash` - `hosts` this is ip and port where the logstash is installed and listening. (TODO: how to extract it from docker)

Filebat configuration is in the yaml format which is sensible for whitespace. I'm using `VisualStudioCode` with [yaml plugin](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml) to avoid potential problem cause by invalid intendation.
After updating Filebeat configuration restart the service using `Restart-Service filebeat` powershell command. If you are not sure that Filebeat is working as expected stop Filebeat service with `Stop-Service filebat` and run it in the debbug mode using command `filebeat -e -d "publish"` where all events will be printed in the console. [Here](https://www.elastic.co/guide/en/beats/filebeat/1.1/enable-filebeat-debugging.html) you can read more about filebeat debugging.


## Processing logs with Logstash
Another piece of our logging stack is Logstash. This service is responsible for processing log entries. Its configuration consists of three parts
 - input 
 - filter 
 - output
 
In the `input` section we have to configure plugin that allows us to receive data from filebeat. The `filter` section is responsible for parsing and transforming log entries.
The `output` section allows to set plugin that sends structural logs to target storage (ElasticSearch in our case)

In order to parse logs you have to use [Grok filter](https://www.elastic.co/guide/en/logstash/current/plugins-filters-grok.html). `Grok` is DSL that can be described as regular expression on the steroids. It allows to use standard `regexp` as well as predefined patterns (there is even an option to create own patterns). A list of default patterns is available [here](https://github.com/elastic/logstash/blob/v1.4.2/patterns/grok-patterns). Pattern that handles multiline entries should starts with `(?m)`. Sample multiline patter can looks as follows:

```plaintext
(?m)%{TIMESTAMP_ISO8601:timestamp}~~\[%{NUMBER:thread}\]~~\[%{USERNAME:user}\]~~\[%{DATA:ipAddress}\]~~\[%{DATA:requestUrl}\]~~\[%{DATA:requestId}\]~~%{DATA:level}~~%{DATA:logger}~~%{DATA:message}~~%{GREEDYDATA:exception}\|\|
```

To test your grok pattern you can use the followings on-line grok debuggers:

- http://grokdebug.herokuapp.com/ - Works with multiline but handles only single entry
- http://grokconstructor.appspot.com/do/match - Works with multiple log entries but unfortunately is not accepting `(?m)` at the begging (multiline switch can be used for subpatterns, checkout this [example](http://grokconstructor.appspot.com/do/match?example=0))

Grok debbugger is also a part of Kibana X-Pack ([Grok debugger in X-Pack](https://www.elastic.co/guide/en/kibana/current/grokdebugger-getting-started.html)).

Sample logstash configuration with input listening to filebeat and ouput set to elasticsearch:

```
input {
  beats {
    port => 5044
  }
}
filter {
  grok {      
      match => { "message" => "(?m)^%{TIMESTAMP_ISO8601:timestamp}~~\[%{DATA:thread}\]~~\[%{DATA:user}\]~~\[%{DATA:requestId}\]~~\[%{DATA:userHost}\]~~\[%{DATA:requestUrl}\]~~%{DATA:level}~~%{DATA:logger}~~%{DATA:logmessage}~~%{DATA:exception}\|\|" }
      add_field => { 
        "received_at" => "%{@timestamp}" 
        "received_from" => "%{host}"
      }
      remove_field => ["message"]      
    }
  date {
    match => [ "timestamp", "yyyy-MM-dd HH:mm:ss:SSS" ]
  }
}

output { 
  elasticsearch {
    hosts => ["127.0.0.1:9200"]
    sniffing => true
    manage_template => false 
    index => "%{app_name}_%{app_env}_%{type}-%{+YYYY.MM.dd}"
    document_type => "%{[@metadata][type]}"
  }
}
```

Please notice that besides the grok filter I've also used `date` filter to set date type for field containint our timestamp (thanks to that Kibana will be able to use it for time  filter).

Save your logstash config in `MyApp.conf` file and put under `/etc/logstash/conf.d` path (if you are using docker copy to the directory that is mapped to this volume). To copy files between windows and linux machine I'm using [WinScp](https://winscp.net/eng/download.php)

After updating logstash configuration you have to restart this service with command `systemctl restart logstash`. If there is a problem with restarting logstash you can check its logs in `/var/log/logstash` directory.

## Presenting logs with Kibana
The last thing that left to do is to configure log presentation in Kibana. At first we have to configure index pattern. Open Kibana in web browser (type your ELK server address with port 5601). Go to `Management -> Index Patterns -> Create Index Patter`. In the `Step 1` provide your index name with the date replaced by wildcard (This is the value defined in logstash configuration for `output.elasticsearch.index`). You need to inject data into elasticsearch before being able to configure it (if there is no index maching your patter, make sure that the filebeat and logstash are working correctly) In the `Step 2` select `@timestamp` field for `Time Filter field name`. After successfuly creating index, you can go to `Discover` tab and start quering your new index.



 - configure index [you need to inject data into Logstash before being able to configure a Logstash index pattern via the Kibana web UI. ]
 - how to use discovery
 - generate links for single entry and filter

## Maintenance
 -  listing and removing index throught kibana
 -  Use Elastic API with postman
 -  Cron job
![Elastic is not working](elastic_is_down.jpg)


You can remove old indices using ElasticSeach API. In order to send request to ElasticSearch API you can use any REST client ([postman](https://www.getpostman.com/) or event powershell `Invoke-RestMethod` cmdlet).

![Kibana dev tools](kibana_dev_tools.jpg)

Gettting list of all indices:

```powershell
Invoke-RestMethod -Method Get -Uri http://your-elk.domain.com:9200/_cat/indices
```

Delete indices which match given pattern

```powershell
Invoke-RestMethod -Method Delete -Uri http://your-elk.domain.com:9200/my_index_pattern-*
```
Be carefull not tu drop `.kibana` index.


[Curator](https://www.elastic.co/guide/en/elasticsearch/client/curator/5.1/delete_indices.html)


## Key to the success
 - Educate your team
 - Where it's accessible
 - How to use it
 
## Summary





1. Problem description
2. Architecture overview
3. How to cheat the system and save a cauple of days (clone existing machine or use docker)
4. Preparing minimal configuration 
5. Deploying configuration ( Tools: WinScp, mRemoteNG, putty, MidnightCommander). How to restart services.
6. Troubleshooting the problems (where to find the logs)
7. How to make people addicted to ELK (show how to use, link sharing, absolute time, queries)
8. Possibilities of extensions (Visuzalization and Performance tracking with Grafana)
9. How to parse logs shipped by customer (when they didn't installed ELK)


## Logstash
- inputs: How events get into Logstash
- filters: How you can manipulate events in Logstash
- outputs: How you can output events from Logstash
Each component block can have an associated plugin.

• Logstash Agent: The central component that collects data from
all the sources.
• Logstash Forwarder: The client component installed on all the
machines that pushes data to Logstash agent. (Currently implemented as Filebeat)



Logstash Input Plugins
You can use input plugins to push events into Logstash. Input plugins have common configuration options.

Filter Plugins: This plugin offers an optional facility where the
original events can be modified and manipulated.

• GEOIP: This plugin fetches geographical location information
from IP addresses. The logs are then enhanced with the location
information.
• Grok: This plugin is the “heart and soul” of Logstash filters. It is quite popular for giving the proper
form to unstructured data.
You first define a search and then extract parts of the log line into
structured fields.

Logstash Codecs
Codecs can be used to encode or decode output or input data. Some common codecs are the following:



Logstash Output Plugins
Logstash outputs are the end stage of the event pipeline. Before completing the event pipeline, you can use
output plugins to forward the output to a particular destination.


Logstash conditional expressions
• The equality operators are ==, !=, <, >, <=, >=.
• The regexp operators of =~, !~ check a pattern on the right-hand
side against a string value on the left-hand side.
• The inclusion operators are in and not in.
You can use the following binary operators:
• and, or, xor, nand
You can use the following unary operator:
• !

https://github.com/logstash-plugins


• inputs: https://github.com/logstash-plugins/logstashinput-
example
• outputs: https://github.com/logstash-plugins/logstashoutput-
example
• filters: https://github.com/logstash-plugins/logstashfilter-
example
• codecs: https://github.com/logstash-plugins/logstashcodec-
example

-----------------------
After doing csv filter configuration, the next step
is to associate specific data types with columns. The first step is to identify which column is going to
represent the date field. This is important as this field can then be explicitly indexed as a date type and
the event can be filtered based on date. There is a specific date filter in Logstash
-------
The matching timestamp is mapped using the target filter. The default value is
@timestamp (the time when the event was captured). For your purpose, since you are dealing with
historical data, it would be misleading to have the event capture time (the time when event was processed
by Elasticsearch) to be in @timestamp. Rather, it should be the date of record. The date field would be
mapped to @timestamp. This is not mandatory but it is recommended
----------------------
Once the data types of the date fields are updated, the next step is to update the data type of fields, which
are required for numeric comparison or operation. The default value is the string data type. It will be
converted to integer so that operations like aggregations and comparisons can be performed on the data.
For conversion of fields to a specific data type, the mutate filter can be used. This filter performs general
mutations such as modification of data types, renaming, replacing fields, and removing fields. It can also
perform other advanced functions like merging two fields, performing uppercase and lowercase
conversion, split and strip fields, and so on.

Generally, a mutate filter looks like following:
filter {
mutate {
convert => # hash of field and data type (optional)
join => # hash of fields to be joined (optional)
lowercase => # array of fields to be converted (optional)
merge => # hash of fields to be merged (optional)
rename => # hash of original and rename field (optional)
replace => # hash of fields to replaced with (optional)
split => # hash of fields to be split (optional)
uppercase => # array of fields (optional)
}
}
-----------------------




## Kibana
Kibana interface consists of four main components: Discover, Visualize, Dashboard, and Settings.

Discover
Kibana provides a Discover page for exploring matching data as per selected index pattern. On this page,
you can query data, search with a filter, and view data from a document. You can also see the count of
matching results and statistics related to a field.
If you configure the timestamp field in the indexed data, it will also display, by default, a histogram
showing distribution of documents over time.
Visualize
Kibana provides Visualize page to create new visualizations. These can be on the basis of different data
sources, such as an already saved search, a new search, or a saved visualization. You can create the
following visualization with Kibana 4:

Kibana is an open source analytics engine that can be used to search, view, and analyze data. Various
kinds of visualizations are available to illustrate data in the form of tables, charts, histograms, maps, etc.
There is a web-based interface to handle large volumes of data. Creating a dashboard is quite seamless
and queries data in real time. Essentially, a dashboard is nothing but a way for analyzing JSON
documents. You can save them, make them as templates, or simply export them. The ease of setup and use
will help you cut through the complexities of stored data in minutes.


The Lucene query syntax is leveraged by Kibana for searching among indices stored in index patterns. As
described in an earlier chapter, the Elasticsearch Query DSL can also be used. This automatically
refreshes the field list, indexed documents lists, and the histograms.

## ElasticSearch
check the clusterhealth:
curl -XGET 'http://localhost:9200/_cluster/health?pretty=true'

You can list all nodes in the cluster by giving the following command:
$ curl -XGET 'localhost:9200/_cat/nodes?v'

how Elasticsearch understands document structure by checking out the mapping for the cd index:
curl -XGET 'localhost:9200/cd/_mapping/author?pretty'

A straightforward search can be one of the following:
• Structured query: This is similar to the queries you give using
SQL to a relational database, such as querying on distinct fields
like bank account number or account type, which can be sorted
by a field like balance amount.
• Full text query: These types of queries find documents by
matching search keywords, and the response is sorted by
relevance.
• Combination of above two
For the most part, you can query by just giving some matching or search criteria.
However, in order to leverage the full power of Elasticsearch, it is helpful to understand which
components of Elasticsearch map and search data:
• Mapping: Interpretation of data in a field.
• Analysis: Processing of full text to make it search ready.
• Query DSL: The query language used by Elasticsearch, which
provides powerful and flexible searching.

## Requirements
Since Lucene uses many disk-based data structures, Elasticsearch utilizes OS cache significantly.
Happily, memory prices have dropped these days so we should try to allocate as much memory as
possible.
■ Tip Although it is quite common to see machines with 32GB or 16GB of RAM size, the ideal memory
size is 64GB of RAM. There can be challenges if the RAM size is less than 8GB
or more than 64GB.

## TL;DR
