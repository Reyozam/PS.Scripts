#Requires -Module ActiveDirectory

<# 
.DESCRIPTION 
 This script creates reports on foreign security principals. 
#> 

[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $DomainName = $env:USERDOMAIN
)


$Trusted_Domain_SIDs = (Get-ADTrust -filter {intraforest -eq $false} -Properties securityIdentifier,memberof -server $DomainName).securityIdentifier.value

Get-ADObject -Filter { objectClass -eq "foreignSecurityPrincipal" } -server $DomainName | ForEach-Object {
    
    $FSP_Translate = $null
    if($_.Name -match "^S-\d-\d+-\d+-\d+-\d+-\d+")
    {
        $domain_sid = $matches[0]
    }
    else
    {
        $domain_sid = $null
    }
    
    $FSP_Translate = try
    {
        ([System.Security.Principal.SecurityIdentifier] $_.Name).Translate([System.Security.Principal.NTAccount])
        $Orphan = $false
    }
    catch
    {
        $Orphan = $true
    }


    [PSCustomObject]@{
        Domain = $DomainName
        ADObject = $_
        SID = $_.Name
        Translate = $FSP_Translate
        Orphan = $Orphan
        TrustExist = if($Trusted_Domain_SIDs -like $domain_sid){$True} else {$false}

    }

}

