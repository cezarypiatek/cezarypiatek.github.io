---
title: "The fastest way to create WireMock.NET mappings"
description: "How to use proxies to automatically generate WireMock.MET stubs"
date: 2024-01-20T00:10:45+02:00
tags : ["testing", "mocks", "aspcore", "dotnet", "WireMock"]
highlight: true
highlightLang: ["cs", "json"]
image: "splashscreen.jpg"
isBlogpost: true
---


- how to handle proxy to multiple downstream services
- use WireMockInspector for fetching mapping info

## Generate mapping with proxy

```cs
[Test]
public async Task test_proxy()
{
    // INFO: Start WireMock.NET with admin interface
    var wireMock = WireMockServer.StartWithAdminInterface(port:9095);
    
    // INFO: Setup your app, set WireMock as downstream service address
    await using var appFactory = new WebApplicationFactory<Program>()
    .WithWebHostBuilder(builder =>
    {
        builder.ConfigureAppConfiguration((context, configurationBuilder) =>
        {
            configurationBuilder.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ExternalServices:WeatherService"] = "http://localhost:9095"
            });
        });
    });

    // INFO: Defined proxy
    wireMock
        .Given(
            Request.Create()
                .WithPath("/data/2.5/*")
        )
        .RespondWith(
            Response.Create()
                .WithProxy(new ProxyAndRecordSettings()
                {
                    Url = "https://api.openweathermap.org/",
                    SaveMapping = true
                })
        );

    // INFO: call an endpoint in your app that use the downstream service
    _ = await appFactory.CreateClient().GetAsync("/api/sample-endpoint");

    // INFO: Hold the process to inspect WireMock.NET admin api from the browser or WireMockInspector
    await Task.Delay(TimeSpan.FromDays(1));
}
```

WireMock.NET should automatically generate mapping based on the forwarded request and its response. You can find generated mapping definition by inspecting result of `http://localhost:9095/__admin/mappings` endpoint. Additionally, if you set `ProxyAndRecordSettings.SaveMappingToFile` to true, WireMock.Net will automatically save generated mapping definitions into a separate files under `/__admin/mappings/` in your output dir. 

But what if you prefer defining your mappings directly in C# code rather than loading from files? This can be automatically generated for you too. Just take the guid of generated mapping and call `http://localhost:9095/__admin/mappings/code/MAPPING_GUID` endpoint.

## Get your mappings with WireMockInspector

Generated mapping definition, as well as the C# code can be easily retrieved also by using [WireMockInspector](https://github.com/WireMock-Net/WireMockInspector). Just install `WireMockInspector` dotnet tool and instead of holding your tests with `Task.Delay` use `Inspect` extension method from [WireMock.Net.Extensions.WireMockInspector](https://www.nuget.org/packages/WireMock.Net.Extensions.WireMockInspector) nuget package.

![](wiremockinspector_generated_mapping.png)


## Create proxy to multiple downstream services

```cs
var wireMock = WireMockServer.StartWithAdminInterface(port:9095);
wireMock
    .Given(
        Request.Create()
            .WithPath("/OpenWeather/*")
    )
    .RespondWith(
        Response.Create()
            .WithProxy(new ProxyAndRecordSettings()
            {
                Url = "https://api.openweathermap.org/",
                SaveMapping = true,
                ReplaceSettings = new ProxyUrlReplaceSettings()
                {
                    OldValue = "/OpenWeather/",
                    NewValue = ""
                }
            })
```

1. Use different prefix for each downstream service
2. Use `ReplaceSettings` to remove prefix
3. Use endpoint for fetching mappings then use endpoint for fetching code
4. Use WireMock inspector to get the code