---
title: "Scheduled ElasticSearch index cleanup"
description: "How to configure an automated cleanup of old log indicies in ELK"
date: 2018-12-09T00:21:45+02:00
tags : ["ELK", "ElasticSearch", "devops", "logging", "curator", "cron" ]
highlight: true
highlightLang: ["yaml"]
image: "splashscreen.jpg"
isBlogpost: true
---


It's been over a year since I've started using ELK stack for logging purpose. In the meantime, I was able to successfully introduce it in a few development teams, totally changing the way we are working with application logs. Everything is working fine and the only downside so far was the need for periodical maintenance work. By maintenance, I mean removing old indices. If the disk free space drops below certain level the ElasticSearch stops working correctly. This behavior is controlled by a number of ElasticSearch parameters described in  [Disk-based Shard Allocation](https://www.elastic.co/guide/en/elasticsearch/reference/current/disk-allocator.html) section. Together with ElasticSearch, Kibana also goes down and when we try to use it we get the error screen with `Elasticsearch plugin is read` message as below:

![broken elastic](elastic_is_down.jpg)

In this situation, all Kibana functions are disabled, even the `DevTool` page. In order to bring it back to life, we have to restart `ElasticSearch` service and free some disk space by deleting old indices. Because `DevTool` is not available we have to do this using anything that can issue HTTP `POST` request (for example `curl` or `Postman`). According to Murphy's law, this always happens when you badly need to check something in the logs, so it would be great to have a mechanism that prevents this kind of `ELK downtime`.

There is a lesser known tool from Elastic stable called `curator` which can help with managing ElasticSearch indices. In this post, I will show you how to build a self-maintenance mechanism for `ELK` stack using `curator` together with `cron` scheduler.


## Before we start
In order to avoid all problems related to insufficient permissions, I've started from switching to root user with `sudo su` command.

## Installing curator

Before we install `curator` we have to update package repository path. Without it `apt-get` will install curator's old version. In order to do that, please add the following line to `/etc/apt/sources.list` file:

```plaintext
deb [arch=amd64] https://packages.elastic.co/curator/5/debian stable main
```

After adding this new repository path we have to download the package lists and update them to get information on the newest versions of packages and their dependencies. This can be simply achieved with the command:

```shell
apt-get update
```

Now we can install `curator` with `apt-get`:

```shell
apt-get install elasticsearch-curator
```

After installation, please verify `curator` version:

```shell
curator --version
```
If you have a version older than 5.X or you experienced any problems during the installation, please check [the official installation instruction](https://www.elastic.co/guide/en/elasticsearch/client/curator/current/apt-repository.html).


## Configure curator
We need to prepare two configuration files:

- `config.yml` - general options related to curator usage
- `action.yml` -  description for actions that will be performed on ElasticSearch indices

Let's starts from  `curator` configuration:

```yaml
---
client:
  hosts:
    - 127.0.0.1
  port: 9200
  url_prefix:
  use_ssl: False
  certificate:
  client_cert:
  client_key:
  ssl_no_validate: False
  http_auth:
  timeout: 30
  master_only: False

logging:
  loglevel: INFO
  logfile:  /var/log/curator/curator.log
  logformat: default
  blacklist: ['elasticsearch', 'urllib3']
```
Save this content to `config.yml`. For correct logging, you need to create `/var/log/curator` directory.
Sometimes using `127.0.0.1` for `client.hosts` is not working and you need to provide the real IP address (I think it depends on server configuration).  For more info about curator configuration please check [the official reference](https://www.elastic.co/guide/en/elasticsearch/client/curator/5.x/configfile.html).


Prepare `action.yml` file with cleanup configuration:

```yaml
---
actions:
  1:
    action: delete_indices
    description: >-
      Delete indices older than 14 days (based on index creation date)
    options:
      ignore_empty_list: True
    filters:
    - filtertype: pattern
      kind: prefix
      value: test_
    - filtertype: age
      source: creation_date
      direction: older
      unit: days
      unit_count: 14

```

In this example I've defined the action that deletes all indices selected by two filters: 

- `pattern` that select all indices which names starts with `test_` prefix (It's good to use this filer because it save you from accidental deleting ELK internal indices)
- `age` to select indices that creation date is older than 14 days. 

All filters are combined with `AND` operator. All available filters are described [here](https://www.elastic.co/guide/en/elasticsearch/client/curator/5.x/filters.html).  More info about action configuration [here](https://www.elastic.co/guide/en/elasticsearch/client/curator/5.x/actions.html). 


Copy both files: `config.yml` and `action.yml` to `/opt/curator-config/` directory. Now we can perform cleanup by running `curator` with parameters as follows:

```shell
curator --config /opt/curator-config/config.yml /opt/curator-config/action.yml
```

The output should be logged to `/var/log/curator/curator.log` file.

## Schedule periodical clean-up

Now we have to schedule the clean-up with `cron` scheduler. In order to configure `cron` use the following command:

```shell
crontab -e
```

You should get the following info:

```shell
Select an editor.  To change later, run 'select-editor'.
  1. /bin/ed
  2. /bin/nano        <---- easiest
  3. /usr/bin/vim.basic
  4. /usr/bin/vim.tiny

Choose 1-4 [2]:
```

Select your favorite text editor and add the following entry at the end of the opened file

```shell
0 0 * * * /usr/bin/curator --config /opt/curator-config/config.yml /opt/curator-config/action.yml >/dev/null 2>&1
```

Each line in the crontab configuration has the following format:

```
<time-expression> <command-to-execute>
```

In my example, I used `0 0 * * *` as a time-expression which means that my command will run every day at midnight. If you don't know crontab time syntax you can easily generate the desired expression using https://crontab-generator.org/. After saving crontab config file, if everything was configured correctly, you should get `crontab: installing new crontab` message. That's all. You can verify if everything is working correctly by examining `/var/log/curator/curator.log`  log file.


## Summary
As you saw, thanks to `curator` and `cron` scheduler I was able to create the mechanism for automated ELK maintenance. Now I don't need to worry anymore that ELK server will run out of free disk space and bring all logging stack down. I would like to thank Robert Łysoń ([@RobertLyson](https://twitter.com/RobertLyson)) who helped me with preparing  `curator` configuration. Next time the beer is on me ;)