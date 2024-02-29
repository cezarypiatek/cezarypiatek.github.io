---
title: "Mocking authorization tokens with WireMock.NET"
description: "How to test Web API protected with OAuth"
date: 2024-02-29T00:10:45+02:00
tags : ["csharp", "JWT", "WireMock.NET", "OAuth", "OpenID"]
highlight: true
highlightLang: ["cs", "json"]
image: "splashscreen.jpg"
isBlogpost: true
---

Testing applications that require authorization presents a unique set of challenges, especially when it comes to simulating different user permissions. Using an actual authorization server and manually creating test users with specific roles and claims can quickly become cumbersome when trying to cover a wide range of permission combinations.

Another option is to use libraries like [fake-authentication-jwtbearer](https://github.com/webmotions/fake-authentication-jwtbearer), but these libraries have a significant drawback. They replace the actual authorization logic, so we are not testing what will actually be used on production. In addition, running an application as a separate process during testing sessions limits the ability to change the application setup except for external configurations.

However, by leveraging a deep understanding of OAuth and the flexibility of WireMock.NET, we can generate JWT tokens with the desired permissions and seamlessly integrate them into our tests without altering the application's core authorization mechanisms. This blog post explores this approach and presents the streamlined solution for fabricated JWT tokens that can be used for testing Web API.

## Generate JWT token 

First, we need something that allows us to generate signed JWT with the desired set of claims. We can implement a helper like the one below using the mechanisms provided by the `Microsoft.AspNetCore.Authentication.JwtBearer` nuget package:

```cs
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.IdentityModel.Tokens;

namespace WireMockGraphQLExample.Tests;

public record SigningKeyInfo(string Modulus, string Exponent, string Kid, string Algorithm);

public class JwtTokenGenerator : IDisposable
{
    public string Authority { get; }
    public string Audience { get; }
    private readonly SigningCredentials _signingCredentials;
    private readonly RSA _rsa;
    private readonly string _kid;

    public JwtTokenGenerator(string authority, string audience)
    {
        Authority = authority;
        Audience = audience;
        _kid = Guid.NewGuid().ToString("N");
        _rsa = RSA.Create(2048);
        _signingCredentials = new SigningCredentials(
            new RsaSecurityKey(_rsa)
            {
                KeyId = _kid
            },
            SecurityAlgorithms.RsaSha256
        );
    }

    public SigningKeyInfo GetSigningKeyInfo()
    {  
        var keyParameters = _rsa.ExportParameters(false);
        var modulus = Base64UrlEncode(keyParameters.Modulus!);
        var exponent = Base64UrlEncode(keyParameters.Exponent!);
        return new SigningKeyInfo(modulus, exponent, _kid, "RS256");
    }

    public string CreateToken(IReadOnlyList<Claim>? customClaims= null, DateTime? expiresAt = null)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Iss, $"{Authority}/"),
            new(JwtRegisteredClaimNames.Aud, Audience)
        };
        if (customClaims != null)
        {
            claims.AddRange(customClaims);
        }
        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = expiresAt ?? DateTime.UtcNow.AddHours(1),
            SigningCredentials = _signingCredentials
        };
        var tokenHandler = new JwtSecurityTokenHandler();
        var token = tokenHandler.CreateToken(tokenDescriptor);
        return tokenHandler.WriteToken(token);
    }

    private static string Base64UrlEncode(byte[] arg)
    {
        var result = Convert.ToBase64String(arg);
        result = result.Split('=')[0];
        result = result.Replace('+', '-');
        result = result.Replace('/', '_');
        return result;
    }

    public void Dispose()
    {
        _rsa.Dispose();
    }
}
```

## Mocking OAUth Provider

We know how to generate JWT tokens with the desired content. Now we need to trick a tested application into recognizing our tokens as valid. Fortunately, it's not as difficult as it may seem, but first we need to understand what happens inside the application when we send a request with JWT to the protected endpoint. The diagram below shows a process of authentication and authorization using OAuth with a focus on token verification:

[![](https://mermaid.ink/img/pako:eNp1U1tv2jAU_iuWHyaqBQhQLslDJRSmiVbroqVapSnSZBzDzkjszHbKKOK_7zghFagsL0nO-c538eVAucoEDakRfyohuVgA22hWpJLgUzJtgUPJpCURYYZEOQj8npfle8A8XjpIrJUV3IrMFa6gEgeaV_YXSYR-EbqBpLJ5P-IwUVgmkTdPQvJ1ZRlIcv_81PSj7t3dR9dwDGgFOMOBD-Sbs28seVJbcaKaJ10Ed6MQm7bSNQkxsJFobQeoH2t4cdMPYn9VPl42MkrDaxOnlTn34lCtek3rZNpQl5yIbULV8RdguCvvT3bjZZutpev3diLPu1updrKvSiEh63Il17CpNLOgLoOenNRRC2FZxiwjHZA875Hfu635WWm4eaf1WVgCcq0IW6nKkrha5cDdkhiy1qp4m_yv1P3zQ0I6Z3M3V2KHzcaQ7yyH7Nx6baQGnFqiXr8Et4khvdvaKGdQmKukC8HBXJC97bgplTSCdBa4Cv1PWiuNvqhHC6ELBhme-IObSikeo0KkNMTPjOltSlN5RByrrEr2ktPQ6kp4tCqdudPtoOGa5QareKR_KFW0IPyl4YH-peFgNuhNR6Pp7XTsB4NxEEw9uqfh0J_1BqPR7WzsD4MR1mdHj77WDH5vOhxPgmAS-OPBzPdvJx4VGVilvzQ3tL6ox39rjyho?type=png)](https://mermaid.live/edit#pako:eNp1U1tv2jAU_iuWHyaqBQhQLslDJRSmiVbroqVapSnSZBzDzkjszHbKKOK_7zghFagsL0nO-c538eVAucoEDakRfyohuVgA22hWpJLgUzJtgUPJpCURYYZEOQj8npfle8A8XjpIrJUV3IrMFa6gEgeaV_YXSYR-EbqBpLJ5P-IwUVgmkTdPQvJ1ZRlIcv_81PSj7t3dR9dwDGgFOMOBD-Sbs28seVJbcaKaJ10Ed6MQm7bSNQkxsJFobQeoH2t4cdMPYn9VPl42MkrDaxOnlTn34lCtek3rZNpQl5yIbULV8RdguCvvT3bjZZutpev3diLPu1updrKvSiEh63Il17CpNLOgLoOenNRRC2FZxiwjHZA875Hfu635WWm4eaf1WVgCcq0IW6nKkrha5cDdkhiy1qp4m_yv1P3zQ0I6Z3M3V2KHzcaQ7yyH7Nx6baQGnFqiXr8Et4khvdvaKGdQmKukC8HBXJC97bgplTSCdBa4Cv1PWiuNvqhHC6ELBhme-IObSikeo0KkNMTPjOltSlN5RByrrEr2ktPQ6kp4tCqdudPtoOGa5QareKR_KFW0IPyl4YH-peFgNuhNR6Pp7XTsB4NxEEw9uqfh0J_1BqPR7WzsD4MR1mdHj77WDH5vOhxPgmAS-OPBzPdvJx4VGVilvzQ3tL6ox39rjyho)

The diagram shows that during the token verification process, the application queries two endpoints from the authorization server. To convince our application that the tokens are valid, we need to control these endpoints. This can be accomplished with a little help from WireMock.NET. 

First, we need to start WireMock.NET with `SSL` enabled because ASP.NET core will not make a call to the Authorization Server endpoints if they are not exposed via `HTTPS`. This can be done with:

 ```cs
var wireMock = WireMockServer.StartWithAdminInterface(port: 9096, ssl: true)
 ```

 Or if you still need the `HTTP` endpoint then you can specify the required endpoints manually:

 ```cs
var wireMock = WireMockServer.StartWithAdminInterface(new []
{
    "http://localhost:9095",
    "https://localhost:9096",
});
```

To make the `SSL` work correctly, you need a trusted certificate. If you don't have your own certificate, you can generate a self-signed development certificate by running the command below:

```sh
dotnet dev-certs https --trust
```

In the next step, we need to create an instance of our `JwtTokenGenerator` and override the application config to use the WireMock.NET endpoint as an `Authority`:

```cs
// Create Token Generator with appropriate audience and authority pointing to WireMock
var tokenGenerator = new JwtTokenGenerator(authority: "https://localhost:9096/Auth",  audience: "TestAPIId");

// Setup app under test and override config with data from our generator
await using var appFactory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
{
    builder.ConfigureAppConfiguration((context, configurationBuilder) =>
    {
        configurationBuilder.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Authorization:Authority"] = tokenGenerator.Authority,
            ["Authorization:Audience"] = tokenGenerator.Audience,
        });
    });
});

```
The way the application configuration is overridden for testing purposes is based on the assumption that authorization is configured like below:

```cs
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{

    options.Authority = builder.Configuration["Authorization:Authority"];
    options.Audience = builder.Configuration["Authorization:Audience"];
});
```

We have configured Application to use WireMock.NET as an OAuth server, and now we need to configure WireMock.NET to mimic the behavior of the OAuth server.
When an API performs JWT token validation with OAuth 2.0, it calls the `.well-known/openid-configuration` endpoint of an OpenID provider. This endpoint is part of the OpenID Connect discovery process and returns a JSON document containing various metadata about the OpenID provider, including endpoints and other configuration information. So we need to stub this endpoint appropriately by preparing a response with configuration that directs all endpoints to our WireMock.NET server:

```cs
wiremock
    .Given(Request.Create()
        .UsingMethod("GET")
        .WithPath("/Auth/.well-known/openid-configuration"))
    .AtPriority(1)
    .RespondWith(Response.Create()
        .WithStatusCode(200)
        .WithHeader("Content-Type", "application/json; charset=utf-8")
        .WithBodyAsJson(new
        {
            issuer = $"{tokenGenerator.Authority}/",
            authorization_endpoint = $"{tokenGenerator.Authority}/authorize",
            token_endpoint = $"{tokenGenerator.Authority}/oauth/token",
            device_authorization_endpoint = $"{tokenGenerator.Authority}/oauth/device/code",
            userinfo_endpoint = $"{tokenGenerator.Authority}/userinfo",
            mfa_challenge_endpoint = $"{tokenGenerator.Authority}/mfa/challenge",
            jwks_uri = $"{tokenGenerator.Authority}/.well-known/jwks.json",
            registration_endpoint = $"{tokenGenerator.Authority}/oidc/register",
            revocation_endpoint = $"{tokenGenerator.Authority}/oauth/revoke",
            scopes_supported = new [] { "openid", "profile", "offline_access", "name", "given_name", "family_name", "nickname", "email", "email_verified", "picture", "created_at", "identities", "phone", "address" },
            response_types_supported = new [] { "code", "token", "id_token", "code token", "code id_token", "token id_token", "code token id_token" },
            code_challenge_methods_supported = new [] { "S256", "plain" },
            response_modes_supported = new [] { "query", "fragment", "form_post" },
            subject_types_supported = new [] { "public" },
            id_token_signing_alg_values_supported = new [] { "HS256", "RS256", "PS256" },
            token_endpoint_auth_methods_supported = new [] { "client_secret_basic", "client_secret_post", "private_key_jwt" },
            claims_supported = new [] { "aud", "auth_time", "created_at", "email", "email_verified", "exp", "family_name", "given_name", "iat", "identities", "iss", "name", "nickname", "phone_number", "picture", "sub" },
            request_uri_parameter_supported = false,
            request_parameter_supported = false,
            token_endpoint_auth_signing_alg_values_supported = new [] { "RS256", "RS384", "PS256" },
            backchannel_logout_supported = true,
            backchannel_logout_session_supported = true,
            end_session_endpoint = $"{tokenGenerator.Authority}/oidc/logout"
        })
    );
```

Among the returned configuration parameters, there is `jwks_uri` which is particularly important for token validation. The `jwks_uri` directs to a JSON Web Key Set endpoint which returns information about the public keys. These public keys are used in asymmetric key cryptography, where a private key signs the token and the corresponding public key verifies the signature. When an API receives a JWT, it must verify the signature of that token to ensure that it was actually issued by the expected authorization server and has not been tampered with. The API retrieves the public keys from the `jwks_uri` endpoint and uses them to verify the token's signature. 

The authorization token we fabricated with `JwtTokenGenerator` is signed with our keys. Therefore, we need to mock an endpoint designated as `jwks_uri` to provide information about our public key so that the application can correctly verify the token signature.

```cs
var signingKeyInfo = tokenGenerator.GetSigningKeyInfo();
wireMock
    .Given(Request.Create()
        .UsingMethod("GET")
        .WithPath("/Auth/.well-known/jwks.json"))
    .RespondWith(Response.Create()
        .WithStatusCode(200)
        .WithHeader("Content-Type", "application/json; charset=utf-8")
        .WithBodyAsJson(new
        {
            keys = new []
            {
                new
                {
                    kty = "RSA",
                    use = "sig",
                    n =  signingKeyInfo.Modulus,
                    e = signingKeyInfo.Exponent,
                    kid =  signingKeyInfo.Kid,
                    alg = signingKeyInfo.Algorithm
                }
            }
        })
    );
```

Now we can generate an authentication token with desired claims and use it for authenticating requests to the tested application:

```cs
// Create HTTP client to communicated with app under the test
var appClient = appFactory.CreateClient();

// Create JWT with desired claims
var authorizationToken = tokenGenerator.CreateToken
(
    customClaims: new Claim[]
    {
        new("email", "sample@email.com"),
        new("permissions", "SamplePermission1"),
        new("permissions", "SamplePermission2"),
    },
    expiresAt: DateTime.UtcNow.AddHours(1)
);

// Set the generated JWT as Authorization header
appClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(JwtBearerDefaults.AuthenticationScheme,authorizationToken);

// Issue the authorized request
var response = await appClient.GetAsync("/sample");

// Assert
Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
```

## Remarks

- For discovering all needed requests I used WireMock.NET Proxy feature, which is described in my previous blog post [The fastest way to create WireMock.NET mappings](/post/generate-wiremocknet-mappings-with-proxy/).

- I omitted the part about verifying the identity of the caller and retrieving JWTs from the authentication server because my focus was on testing APIs that require authorization, which do not involve those elements.

- I have tested the presented solution with two OAuth servers and it works.