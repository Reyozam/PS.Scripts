#Requires -Module activedirectory
<#
.SYNOPSIS
Create test Active Directory accounts.

.LINK
https://gist.github.com/tylerapplebaum/d692d9d2e1335b8b111927c8292c5dac
https://randomuser.me/

.DESCRIPTION
Queries randomuser.me to generate user information. Creates an Active Directory user based on that.

.PARAMETER NumUsers
Specify the number of users to create

.PARAMETER CompanyName
Specify the company name to be used in the AD users' profile

.PARAMETER Nationalities
Specify the nationality of the users you are creating. randomuser.me relies on this for correct address formatting.

.INPUTS
System.String, System.Int32

.OUTPUTS
CSV with the creation results; Active Directory user account

.EXAMPLE
PS C:\> Add-TestUsers.ps1 -NumUsers 10
Creates 10 AD user accounts

.EXAMPLE
PS C:\> Add-TestUsers.ps1 -NumUsers 18 -CompanyName "Apple Computer"
Creates 18 AD user accounts with Apple Computer as the Company Name under Organization
#>

[CmdletBinding()]
param(
		[Parameter(mandatory = $true, HelpMessage = "Specify the number of users to create")]
		[Alias("users")]
  [ValidateRange(1, 1000)]
  [int]$Numbers,
    
  [Parameter(HelpMessage = "Specify the company name")]
  [Alias("co")]
  [string]$CompanyName = "Contoso",

  [Parameter(HelpMessage = "Specify the OU target")]
  [string]$OU,
    
  [Parameter(HelpMessage = "Specify the users' nationalities")]
  [Alias("nat")]
  [string]$Country = "FR"

)


$Date = (Get-Date -Format (Get-Culture).DateTimeFormat.ShortDatePattern) -replace '/', '.'
$DesktopPath = [Environment]::GetFolderPath("Desktop")

Try
{
  Import-Module ActiveDirectory -ErrorAction Stop
}
Catch [Exception]
{
  Return $_.Exception.Message
}

$DomainInfo = Get-ADDomain
if (-not $OU) { $OU = $DomainInfo.UsersContainer }
$UPNSuffix = "@" + $DomainInfo.DNSRoot

#End Set-Environment

Function Get-UserData 
{
  [CmdletBinding()]
  param (
    [Parameter()]
    [int]
    $Numbers,

    [Parameter()]
    [string]
    $Country


  )
  Try
  {
    return Invoke-RestMethod "https://www.randomuser.me/api/?results=$Numbers&nat=$Country" | Select-Object -ExpandProperty Results
  }
  Catch [Exception]
  {
    Return $_.Exception.Message
  }
}

Function Get-Password 
{

  $RandomInputSymbol = $(ForEach ($Char in @(32..47 + 58..64 + 91..96 + 123..126)) { [char]$Char }) | Get-Random -Count 2
  $RandomInputNum = $(ForEach ($Char in @(48..57)) { [char]$Char }) | Get-Random -Count 2
  $RandomInputUpper = $(ForEach ($Char in @(65..90)) { [char]$Char }) | Get-Random -Count 4
  $RandomInputLower = $(ForEach ($Char in @(97..122)) { [char]$Char }) | Get-Random -Count 4
  $PasswordArrComplete = $RandomInputSymbol + $RandomInputNum + $RandomInputUpper + $RandomInputLower
  $Random = New-Object Random
  $Password = [string]::join("", ($PasswordArrComplete | sort { $Random.Next() }))
  
  return @{ #Snag the plaintext password for later use
    "PlainPW"           = $Password
    "EncryptedPassword" = $Password | ConvertTo-SecureString -AsPlainText -Force
  }

} 


#EXECUTION

$RandomUsers = Get-UserData -Numbers $Numbers -Country $Country

$Summary = ForEach ($RandomUser in $RandomUsers)
{

  $First = $RandomUser.Name.First.Substring(0, 1).ToUpper() + $RandomUser.Name.First.Substring(1).ToLower()
  $Last = $RandomUser.Name.Last.Substring(0, 1).ToUpper() + $RandomUser.Name.Last.Substring(1).ToLower()
  $PasswordsHash = Get-Password 

  $NewADUsersParam = @{
    "GivenName"             = $First
    "Surname"               = $Last
    "Name"                  = $First + " " + $Last
    "DisplayName"           = $First + " " + $Last
    "OfficePhone"           = $RandomUser.Phone
    "City"                  = $RandomUser.Location.City
    "State"                 = $RandomUser.Location.State
    "Country"               = $Nationalities
    "Company"               = $CompanyName
    "SAMAccountName"        = ($First[0], $Last -join ".").ToLower()
    "UserPrincipalName"     = $Last + $First[0] + $UPNSuffix
    "AccountPassword"       = $PasswordsHash["EncryptedPassword"]
    "Enabled"               = $True
    "ChangePasswordAtLogon" = $False
    "Description"           = "Test Account Generated $Date by $env:username"
    "Path"                  = $OU
  }

  New-ADUser @NewADUsersParam -Verbose

  [PSCustomObject]@{
    Name           = $NewADUsersParam.Name
    SamAccountName = $NewADUsersParam.SAMAccountName
    Password       = $PasswordsHash["PlainPW"]
  }


}

return $Summary
