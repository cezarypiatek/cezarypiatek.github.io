---
title: "Demystifying ELK stack"
description: "How to easily implement centralized loging system based on ELK stack."
date: 2018-01-25T00:05:18+02:00
tags : ["Kibana", "Logstash", "ElasticSearch", "ELK", "Filebeat", "logging"]
scripts : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/highlight.min.js", "//cdnjs.cloudflare.com/ajax/libs/fitvids/1.2.0/jquery.fitvids.min.js"]
css : ["//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.12.0/styles/default.min.css"]
image: "splashscreen.jpg"
isBlogpost: true
draft: true
---
![splashscreen](splashscreen.jpg)

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
