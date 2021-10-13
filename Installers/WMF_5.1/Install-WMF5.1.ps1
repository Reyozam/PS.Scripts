
<#PSScriptInfo

.VERSION 1.0

.GUID bae78b34-2bd5-42ce-9577-ec348b598570

.AUTHOR Microsoft Corporation

.COMPANYNAME Microsoft Corporation

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


#>

<#

.DESCRIPTION
 Test the compatibility of current system with WMF 5.1 and install the package if requirements are met.

#>

##Check OS Version is below Windows 10.
[CmdletBinding()]
param(

)

$ErrorActionPreference = 'Stop'
$LogFile = "C:\Insartic\Log\Install-WMF_5.1-{0}.log" -f $(Get-Date -f "yyyyMMdd")

function Write-Log
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, ParameterSetName = "Message", ValueFromPipeline = $true)]
        [Parameter(ParameterSetName = "Step")][string]$Message,
        [Parameter(Mandatory = $false, ParameterSetName = "Message")] [ValidateSet("Info", "Error", "Warn")][string]$Level = "Info",
        [Parameter(Mandatory = $true, ParameterSetName = "StartLog", ValueFromPipeline = $true)][switch]$StartLog,
        [Parameter(Mandatory = $true, ParameterSetName = "EndLog", ValueFromPipeline = $true)][switch]$EndLog,
        [Parameter(Mandatory = $true, ParameterSetName = "Step", ValueFromPipeline = $true)][switch]$Step,
        [Parameter(Mandatory = $false)][string]$Color = "Green",
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][string]$LogFile

    )

    #=============================================
    # EXECUTION
    #=============================================

    Switch ($PsCmdlet.ParameterSetName)
    {
        "StartLog" # HEADER
        {
            $CurrentScriptName = $myinvocation.ScriptName
            $script:StartDate = Get-Date
            $LogStartDate_str = Get-Date -UFormat "%d-%m-%Y %H:%M:%S"

            #Information Système & Contexte
            $Current = [Security.Principal.WindowsIdentity]::GetCurrent()
            $CurrentUser = $Current.Name
            $CurrentComputer = $ENV:COMPUTERNAME
            #System
            if ($PSVersionTable.PSVersion -gt "4.0"){
                $CIM = Get-CimInstance win32_operatingsystem -Property Caption, Version, OSArchitecture
            }
            else
            {
                $CIM = Get-WmiObject win32_operatingsystem -Property Caption, Version, OSArchitecture
            }
            $OS = "$($CIM.Caption) [$($CIM.OSArchitecture)]"
            $OSVersion = $CIM.Version
            $PSVersion = ($PSVersionTable.PSVersion)
            #UAC
            #determine the current user so we can test if the user is running in an elevated session
            $Principal = [Security.Principal.WindowsPrincipal]$Current
            $Elevated = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

            $Header = "+========================================================================================+`r`n"
            $Header += "Script Name              : $CurrentScriptName`r`n"
            $Header += "When generated           : $LogStartDate_str`r`n"
            $Header += "User                     : $CurrentUser`r`n"
            $Header += "Elevated                 : $Elevated`r`n"
            $Header += "Computer                 : $CurrentComputer`r`n"
            $Header += "OS                       : $OS`r`n"
            $Header += "OS Version               : $OSVersion`r`n"
            $Header += "PS Version               : $PSVersion`r`n"
            $Header += "+========================================================================================+`n"


            # Log file creation
            [VOID] (New-Item -ItemType File -Path $LogFile -Force)
            $Header | Out-File -FilePath $LogFile -Append
            Write-Host $Header -ForegroundColor Cyan
            break
        }

        "Message" #LOG
        {
            $TimeStamp = Get-Date -UFormat "%H:%M:%S"
            switch ($Level)
            {
                Info { $Line  = ("[{0}][INFO   ] {1}" -f $TimeStamp, $Message); $Color = 'Cyan'; break }
                Error { $Line = ("[{0}][ERROR  ] {1}" -f $TimeStamp, $Message); $Color = 'Red'; break }
                Warn { $Line  = ("[{0}][WARNING] {1}" -f $TimeStamp, $Message); $Color = 'Yellow'; break }
            }
            $script:PreviousLine = $Line
            Write-Host $Line -ForegroundColor $Color
            if ($PSVersion -lt "4.0") {"$Line" | Out-File -FilePath $LogFile -Append}
            else {"`n$Line" | Out-File -FilePath $LogFile -Append -NoNewline}
            break
        }

        "Step" #Status d'un étape sur la meme ligne
        {

            $Message = "`t[$Message]"

            #Déplacement Cursor
             $ConsoleY = ([System.Console]::CursorTop) - 1
             [System.Console]::SetCursorPosition(0,$ConsoleY)

            Write-Host $PreviousLine -ForegroundColor Cyan  -NoNewline
            Write-Host $Message -ForegroundColor $Color
            if ($PSVersion -lt "4.0") {"$Message" | Out-File -FilePath $LogFile -Append}
            else {"$Message" | Out-File -FilePath $LogFile -Append -NoNewline}
            break
        }

        "EndLog" #Status d'un étape sur la meme ligne
        {
            $EndDate  = Get-Date
            $TimeSpan = New-TimeSpan -Start $StartDate -End $EndDate
            $Duration_Str = "{0} hours {1} min. {2} sec" -f $TimeSpan.Hours,$TimeSpan.Minutes,$TimeSpan.Seconds

            $Footer += "`r`n"
            $Footer += "+========================================================================================+`r`n"
            $Footer += "End Time                 : $EndDate`r`n"
            $Footer += "Total Duration           : $Duration_Str`r`n"
            $Footer += "+========================================================================================+"

            $Footer| Out-File -FilePath $LogFile -Append
            Write-Host $Footer -ForegroundColor Cyan
        }

    }
}


function Test-Compatibility
{
    $returnValue = $true

    $BuildVersion = [System.Environment]::OSVersion.Version

    if($BuildVersion.Major -ge '10')
    {
        Write-Log -Level Warn -Message "Windows 10 / Windows Server 2016 détecté : WMF 5.1 non supporté" -LogFile $LogFile
        $returnValue = $false
    }

    ## Check if WMF 3 is installed
    $wmf3 = Get-WmiObject -Query "select * from Win32_QuickFixEngineering where HotFixID = 'KB2506143'"

    if($wmf3)
    {
        Write-Log -Level Info -Message "WMF 3.0 détecté" -LogFile $LogFile

        while (Get-Process wusa -ErrorAction SilentlyContinue) {
            Write-Log -Level Warn -Message "Attente fin du process WUSA.EXE" -LogFile $LogFile
            Start-Sleep  1
        }

        try {
            Write-Log -Level Info -Message "Désinstallation de WMF 3.0" -LogFile $LogFile
            Start-Process -FilePath 'wusa.exe' -ArgumentList "/KB:2506143 /quiet /uninstall /norestart" -Wait -ErrorAction Stop
            Write-Log -Step -Message "OK" -LogFile $LogFile
        }
        catch {
            Write-Log -Step -Message "ERREUR" -LogFile $LogFile
            $returnValue = $false
        }

        while (Get-Process wusa -ErrorAction SilentlyContinue) {
            Write-Log -Level Warn -Message "Attente fin du process WUSA.EXE" -LogFile $LogFile
            Start-Sleep  1
        }

    }

    # Check if .Net 4.5 or above is installed
    $release = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\' -Name Release -ErrorAction SilentlyContinue -ErrorVariable evRelease).release
    $installed = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\' -Name Install -ErrorAction SilentlyContinue -ErrorVariable evInstalled).install

    if (($installed -ne 1) -or ($release -lt 378389))
    {
        Write-Log -Level Warn -Message "WMF 5.1 requires .Net 4.5." -LogFile $LogFile
        $returnValue = $false
    }

    return $returnValue
}

Write-Log -StartLog -LogFile $LogFile

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$BuildVersion = [System.Environment]::OSVersion.Version -as [string]
switch -wildcard  ($BuildVersion)
{
    "6.1*" {$packageName = 'Win7AndW2K8R2-KB3191566-x64.msu'}
    "6.3*" {$packageName = 'Win8.1AndW2K12R2-KB3191564-x64.msu'}
}

$packagePath = Join-Path $scriptPath $packageName

Write-Log -Level Info -Message "Package trouvé : $packagepath" -LogFile $LogFile

if($packagePath -and (Test-Path $packagePath))
{
    Write-Log -Level Info -Message "Test de compatibilité ..." -LogFile $LogFile
        if(Test-Compatibility)
        {
            $wusaExe = "$env:windir\system32\wusa.exe"
            Write-Log -Level Info -Message "Installation de WMF 5.1 ..." -LogFile $LogFile

            Start-Process 'wusa.exe' -ArgumentList "`"$($packagePath)`" /quiet /norestart" -Wait -Verbose

        }
        else
        {
            Write-log -Level Error -Message "Impossible d'installer WMF 5.1, les pré-requis ne sont pas remplis." -LogFile $LogFile
        }
}
else
{
    Write-log -Level Error -Message "Le package `"$packageName`" est introuvable" -LogFile $LogFile
}

Write-Log -EndLog -LogFile $LogFile

