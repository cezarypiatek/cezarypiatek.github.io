---
title: "Mocking authorization tokens with WireMock.NET"
description: "How to prepare authorization tokens that works in your tests"
date: 2024-02-25T00:10:45+02:00
tags : ["csharp", "JWT", "WireMock.NET", "OAuth", "testing"]
highlight: true
highlightLang: ["cs", "json"]
image: "splashscreen.jpg"
isBlogpost: true
---

1. When we test app with authorization we would like to simulate users with different permission.
2. We can use libraries like [fake-authentication-jwtbearer](https://github.com/webmotions/fake-authentication-jwtbearer) however it replace our authorization logic so we do not test what we actually use on production. Moreover, if we run our app as separate process for the purpose of test session then replacing anything in the app setup (beside the external config) is not an option.
3. We can use the actual authorization server and create a test users with a particular set of permissions and claims however adding other combination is cumbersome.
4. However if you know how OAuth works we can very easily create JWT tokens with desired content and with a little help of WireMock.Net we can make them work without messing in the internals of the tested app.
5. Explain how OAuth and JWT works
6. Use WireMock proxy to check what endpoints of the Identity server are use by tested app
7. Show how to generate JWT and how to stub Identity Server endpoints with WireMock.NET
 - generate tokens
 - enable SSL endpoint
 - stub endpoint for options and for token keys
 - generate ssl certificate for dev `dotnet dev-certs https --trust`

## Generate JWT token 


```cs
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.IdentityModel.Tokens;

namespace WireMockGraphQLExample.Tests;

public record SigningKeyInfo( string Modulus, string Exponent, string Kid, string Algorithm);

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

We know how to generated JWT tokens with desired content. Now we need to trick tested application to treat our tokens as valid. This can be achieved with a little help of WireMock.NET

[![](https://mermaid.ink/img/pako:eNp1U-9v0zAQ_Vcsf0BDNGmTLGnJh0lRilBBQLVMQ0KRkHGuxTSxg-OsdFX_d875UW2s5Evsu3fv3rPPR8pVATSmDfxuQXJYCrbVrMolwa9m2gguaiYNSQlrSFoKwHVS1y8ByXplIWutDHADhQ1cQGUWlLTmJ8lAP4DuIbns_5-xmCgMk3SSZDH58sMwIcmHr3d9PnVubt7YhGVAKYIzLHhFbq38xpA7tYOBKskcBDtpjEnT6oHkQpv1qqdTWjz2ske6pz0tauyyFyj_rOlfSoT22juXS9FwGz4Mqtar0cLINnX3UJbOTqq9nKoapCgcruRGbFvNjFDP_QxCOkcVGFYww8iVkLx0ya_9rvneavH6Ra_3YFDwx4xstKrOuP8SW-gFW3F_vuSelaJ4Kq1r1AGGFNjjIZnYSoaE9obSkomquUi6BC6aZ2Tni2tqJRsgV0t0OX2ntdLojU5oBbpiosDBPdqqnOI0VJDTGJcF07uc5vKEONYalR0kp7HRLUxoW1txw5DTeMPKBqM4md-UqkYQbml8pH9o7M1Ddx5ch2HoRYEf-YtgQg809gPf9d8GXhTNgsUi8vz5aUIfO4aZOw8ROvODhecF17MAK6AQRulP_UPr3tvpL--WE_Y?type=png)](https://mermaid.live/edit#pako:eNp1U-9v0zAQ_Vcsf0BDNGmTLGnJh0lRilBBQLVMQ0KRkHGuxTSxg-OsdFX_d875UW2s5Evsu3fv3rPPR8pVATSmDfxuQXJYCrbVrMolwa9m2gguaiYNSQlrSFoKwHVS1y8ByXplIWutDHADhQ1cQGUWlLTmJ8lAP4DuIbns_5-xmCgMk3SSZDH58sMwIcmHr3d9PnVubt7YhGVAKYIzLHhFbq38xpA7tYOBKskcBDtpjEnT6oHkQpv1qqdTWjz2ske6pz0tauyyFyj_rOlfSoT22juXS9FwGz4Mqtar0cLINnX3UJbOTqq9nKoapCgcruRGbFvNjFDP_QxCOkcVGFYww8iVkLx0ya_9rvneavH6Ra_3YFDwx4xstKrOuP8SW-gFW3F_vuSelaJ4Kq1r1AGGFNjjIZnYSoaE9obSkomquUi6BC6aZ2Tni2tqJRsgV0t0OX2ntdLojU5oBbpiosDBPdqqnOI0VJDTGJcF07uc5vKEONYalR0kp7HRLUxoW1txw5DTeMPKBqM4md-UqkYQbml8pH9o7M1Ddx5ch2HoRYEf-YtgQg809gPf9d8GXhTNgsUi8vz5aUIfO4aZOw8ROvODhecF17MAK6AQRulP_UPr3tvpL--WE_Y)


First we need to launch WireMock.Net with enabled  `SSL` because ASP.NET core won't make call to endpoint `jwks_uri` that returns info about public key that was used to sign the token if it's not exposed via `HTTPS`. This can be done with:

 ```cs
var wireMock = WireMockServer.StartWithAdminInterface(port: 9095, ssl: true)
 ```

 Or if you still need the `http` endpoint then you can specify the required endpoints manually:

 ```cs
var wireMock = WireMockServer.StartWithAdminInterface(new []
{
    "http://localhost:9095",
    "https://localhost:9096",
});
```

To make the `SSL` works correctly you need trusted certificate. If you don't have your own certificate, you can generated self-signed development certificate by executing the command below:

```sh
dotnet dev-certs https --trust
```


When an API performs JWT token validation with OAuth 2.0, it calls the `.well-known/openid-configuration` endpoint of an OpenID Provider. This endpoint is part of the OpenID Connec discovery process and returns a JSON document containing various metadata about the OpenID Provider, including endpoints and other configuration information. So we need to stub this endpoint with WireMock.NEt appropiately by preparing a response with configuration that points out all endpoints to our WireMock.NET server:

```cs
var authority = "https://localhost:9096/Auth";
wiremock
    .Given(Request.Create()
        .UsingMethod("GET")
        .WithPath("/Auth/.well-known/openid-configuration"))
    .RespondWith(Response.Create()
        .WithStatusCode(200)
        .WithHeader("Content-Type", "application/json; charset=utf-8")
        .WithBodyAsJson(new
        {
            issuer = $"{authority}/",
            authorization_endpoint = $"{authority}/authorize",
            token_endpoint = $"{authority}/oauth/token",
            device_authorization_endpoint = $"{authority}/oauth/device/code",
            userinfo_endpoint = $"{authority}/userinfo",
            mfa_challenge_endpoint = $"{authority}/mfa/challenge",
            jwks_uri = $"{authority}/.well-known/jwks.json",
            registration_endpoint = $"{authority}/oidc/register",
            revocation_endpoint = $"{authority}/oauth/revoke",
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
            end_session_endpoint = $"{authority}/oidc/logout"
        })
    );
```

Among the returned configuration parameters, there's `jwks_uri` which is particularly important for handling tokens and their validation. The `jwks_uri` points to a JSON Web Key Set endpoint. This endpoint contains the public keys that a client can use to verify the signature of JWTs issued by the authorization server. These public keys are used in asymmetric key cryptography, where a private key signs the token, and the corresponding public key verifies its signature. This endpoint is used during the token validation phase. For example, when an API receives a JWT in an API call, it needs to verify the signature of this token to ensure it was indeed issued by the expected authorization server and has not been tampered with. The API retrieves the public keys from the `jwks_uri` endpoint and uses them to verify the token's signature. The fabricated authorization token is signed with our keys so we need to mock `jwks_uri` endpoint to return info about our public key so the application will be able to correctly verify token signature.


```cs
var mappingBuilder = new MappingBuilder();
mappingBuilder
    .Given(Request.Create()
        .UsingMethod("GET")
        .WithPath("/Auth/.well-known/jwks.json")
    .RespondWith(Response.Create()
        .WithStatusCode(200)
        .WithHeader("Content-Type", "application/json; charset=utf-8")
        .WithHeader("Last-Modified", "Sun, 25 Feb 2024 14:14:17 GMT")
        .WithHeader("Date", "Sun, 25 Feb 2024 14:39:33 GMT")
        .WithHeader("Transfer-Encoding", "chunked")
        .WithHeader("Connection", "keep-alive")
        .WithHeader("CF-Ray", "85b0b2c92e033bb5-WAW")
        .WithHeader("CF-Cache-Status", "HIT")
        .WithHeader("Access-Control-Allow-Origin", "*")
        .WithHeader("Age", "0")
        .WithHeader("Cache-Control", "public, max-age=15, stale-while-revalidate=15, stale-if-error=86400")
        .WithHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
        .WithHeader("Vary", "Accept-Encoding, Origin, Accept-Encoding")
        .WithHeader("Access-Control-Allow-Credentials", "false")
        .WithHeader("Access-Control-Expose-Headers", "X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset")
        .WithHeader("X-Auth0-RequestId", "2e43b2eb5fb049b92676")
        .WithHeader("X-Content-Type-Options", "nosniff")
        .WithHeader("X-RateLimit-Limit", "300")
        .WithHeader("X-RateLimit-Remaining", "299")
        .WithHeader("X-RateLimit-Reset", "1708871974")
        .WithHeader("Server", "cloudflare")
        .WithHeader("Alt-Svc", "h3=\":443\"")
        .WithBodyAsJson(new
        {
            keys = new []
            {
                new
                {
                    kty = "RSA",
                    use = "sig",
                    n = "2FjYrCOd5GSBwrumnRzfSbzefoEAULGTnegKEbnnTD_mGN8NUuJAjOCqHSxC9Hh7qbjjBJ1vn9kd7DOiBJVRdFNf34-uRikD9xhgVk0JW_3uf9GNBqQAidSWCcUcs9JZRUG4ydPyGPqpf8VRCUu_B5HozR_NC_5OpgdlcNU_LD9_Y48lPg-_bGEePz_CtE7bc1x7CFZWEq7m_Mj4JgHzKMQ8blbWK8SOnwhBDm1y-aEbT0aUPllttFfAj4Nv_MTBQJZpilMvrO9LksstA9kV5i1q9W0rlhRuxXhAoPyk28LSqHurlr0e8kGGwDZfvmrkTTBArSgUzSPXIzCxI72JGQ",
                    e = "AQAB",
                    kid = "7y1t8qsbT-f-dexo0e5C5",
                    x5t = "aYTrSxnU01yJQqPS2QBO0-fuQck",
                    x5c = new [] { "MIIDHTCCAgWgAwIBAgIJcOngwoP7hyRVMA0GCSqGSIb3DQEBCwUAMCwxKjAoBgNVBAMTIWRldi1haGIwZzBsZ2U3dWh4M3kwLnVzLmF1dGgwLmNvbTAeFw0yNDAyMjMxOTI5MTdaFw0zNzExMDExOTI5MTdaMCwxKjAoBgNVBAMTIWRldi1haGIwZzBsZ2U3dWh4M3kwLnVzLmF1dGgwLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANhY2KwjneRkgcK7pp0c30m83n6BAFCxk53oChG550w/5hjfDVLiQIzgqh0sQvR4e6m44wSdb5/ZHewzogSVUXRTX9+PrkYpA/cYYFZNCVv97n/RjQakAInUlgnFHLPSWUVBuMnT8hj6qX/FUQlLvweR6M0fzQv+TqYHZXDVPyw/f2OPJT4Pv2xhHj8/wrRO23NcewhWVhKu5vzI+CYB8yjEPG5W1ivEjp8IQQ5tcvmhG09GlD5ZbbRXwI+Db/zEwUCWaYpTL6zvS5LLLQPZFeYtavVtK5YUbsV4QKD8pNvC0qh7q5a9HvJBhsA2X75q5E0wQK0oFM0j1yMwsSO9iRkCAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU5nJ8a6AWfdgJl1h30lZ40uxHN5AwDgYDVR0PAQH/BAQDAgKEMA0GCSqGSIb3DQEBCwUAA4IBAQA6N7rdfeLHYyeP8cpDhGCLlkNUp+nher5qqsZGWsV4+0qHn3w5IrfMUzW8h6yVZFUMSMUEzWBuX6IPz6gnpukrkzQD4TzPQLBD1UuEymPIu8EVYTuKTFEUZt2V6mZoXBWgusu8wqgZYPjm5ptIWMG6WZCr0r82JpTLOmwnbIb4vpzo7dKw8T0TG5yrLakTsjILmjYjCyhNDBwYdi5ieyWFgytuuSEcHiYB3e++QHLYRF69H/8Q6qH/NKpQVRb2rObNX1lxT48jVwP4XS89etID+MJKxlr6mSsT+QwDuXpVyyLn7IhHepdymrpL4Hgoh8re0otMd1VKwvHAoLH3Vqex" },
                    alg = "RS256"
                },
                new
                {
                    kty = "RSA",
                    use = "sig",
                    n = "s1RfGqARjvoDScLCcd1_e97H2nuEeWNNKla-1BCgExmCJl3OmtoDGhqOIQU2NkHmbsx_iBrfnfBare6-CPiTj-KZgXY7IQIFdDeuBoGs6SZUVXexR693Brl-yyt_ZESPIYAZObIOpRbQReEzVun9neqOfG_VBQzBunRpX7wz_FrPbPmKs1H1pUmVAWEpHPWGI_U6VEosu8W-X1CcCHO3Y8zGGf6FhpCPjyq9_gB0nCIdguMNFAA3OtrILbDaOh_l_zFwbW2ZCXj-OoTX33sh_t6-0MB-DTsIf4xgnm76goT6K8hZ-3NwTXCDxi-Su-zfe93Z3pVln7AhSDEzMy4b7w",
                    e = "AQAB",
                    kid = "yGi_GkR1cm-_UlF89My_y",
                    x5t = "LTfF9MtDcneD0hGI-kxTtu-Ilcs",
                    x5c = new [] { "MIIDHTCCAgWgAwIBAgIJEKypmY0C1pyqMA0GCSqGSIb3DQEBCwUAMCwxKjAoBgNVBAMTIWRldi1haGIwZzBsZ2U3dWh4M3kwLnVzLmF1dGgwLmNvbTAeFw0yNDAyMjMxOTI5MTdaFw0zNzExMDExOTI5MTdaMCwxKjAoBgNVBAMTIWRldi1haGIwZzBsZ2U3dWh4M3kwLnVzLmF1dGgwLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALNUXxqgEY76A0nCwnHdf3vex9p7hHljTSpWvtQQoBMZgiZdzpraAxoajiEFNjZB5m7Mf4ga353wWq3uvgj4k4/imYF2OyECBXQ3rgaBrOkmVFV3sUevdwa5fssrf2REjyGAGTmyDqUW0EXhM1bp/Z3qjnxv1QUMwbp0aV+8M/xaz2z5irNR9aVJlQFhKRz1hiP1OlRKLLvFvl9QnAhzt2PMxhn+hYaQj48qvf4AdJwiHYLjDRQANzrayC2w2jof5f8xcG1tmQl4/jqE1997If7evtDAfg07CH+MYJ5u+oKE+ivIWftzcE1wg8Yvkrvs33vd2d6VZZ+wIUgxMzMuG+8CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUSzLyhHClXqLI9xf/TVekpt30fgUwDgYDVR0PAQH/BAQDAgKEMA0GCSqGSIb3DQEBCwUAA4IBAQBKmU8fiodYqDTqbLzM+EgLuoFv7EZKuz5ZW5/XLZxfdJ290CXvfMaowuW0e8skvyIOSh3cuVc/AT+qBSYx3lBZberGDVgVTBTQwuUwMZ5DtlJgGKKTrCvIMEly8Uy2Wwri1I8wpi/CETr8I2W5UrlKwWz2PkskFyRDdCnkN9dmaaE3HbdqlRZdzTkzPRrnKF7agrD1DSEn3kia2wvd1OpkQRtGOPyjGLrOeR4nrFitX5KpEUS+lQnThEsDcWc+x9F/jIStaK8kHdtQNE+NrIsDNLP0PNg0AmF2pQ7seXUqzw/Q4h4Ol32o0X288aEbBIk5/uNcyAFAgBckTXyUNyX1" },
                    alg = "RS256"
                }
            }
        })
    );
```