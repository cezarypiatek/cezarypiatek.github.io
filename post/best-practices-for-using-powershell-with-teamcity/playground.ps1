Set-StrictMode -Version 2.0
function Invoke-Sample
{
    param($Sample1)
    Write-Host "$Sample1"
}
function Invoke-NewSample
{
    [CmdletBinding()]
    param($Sample1)
    Write-Verbose "$Sample1, $as"    
    Write-Host $aaa
}



Invoke-NewSample



function Verb-Noun {
    [CmdletBinding()]
    param (
     #parameters go here   
    )    
}