#===============================================================================================================
# Language     :  PowerShell 5.0
# Filename     :  
# Autor        :  Julien MAZOYER [jmazoyer@synapsys-it.com]
# Description  :  
#===============================================================================================================
<#
    .SYNOPSIS
    
    .DESCRIPTION
    
    .EXAMPLE
        
    .EXAMPLE
    
    .LINK
    
#>

[CmdletBinding()]
param(
    [string]$Target
)

#============================================================================
#VARIABLES
#============================================================================
#Setup paths
$ScriptName = [io.path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
$script:ReturnCode = 0

#AD PORT REFERENCE
$ADPorts = @(
    @{Description = "Kerberos"       ; Port = "88"   ; Protocol = "TCP" },
    @{Description = "SMB"            ; Port = "445"  ; Protocol = "TCP" },
    @{Description = "Kerberos"       ; Port = "464"  ; Protocol = "TCP" },
    @{Description = "Global Catalog" ; Port = "3269" ; Protocol = "TCP" },
    @{Description = "Global Catalog" ; Port = "3268" ; Protocol = "TCP" },
    @{Description = "LDAP"           ; Port = "389"  ; Protocol = "TCP" },
    @{Description = "LDAPS"          ; Port = "636"  ; Protocol = "TCP" },
    @{Description = "DNS"            ; Port = "53"   ; Protocol = "TCP" },
    @{Description = "RPC"            ; Port = "135"  ; Protocol = "TCP" }
)


#============================================================================
#FUNCTIONS
#============================================================================
function Test-Port
{
    <#
.SYNOPSIS
    Test port status on remote computer
.DESCRIPTION
    Test port status on remote computer
.PARAMETER ComputerName
    Target computer
.PARAMETER Port
	Port(s) to test
.PARAMETER Protocol
    TCP/UDP
.EXAMPLE
    Test-Port -computername Server01,Server02 -Port 80,443
#>

    [CmdletBinding(DefaultParameterSetName = 'TCP')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$ComputerName,
        [Parameter(Mandatory = $true, Position = 1)]
        [int[]]$Port,
        [Parameter(Mandatory = $false)]
        [ValidateSet('TCP', 'UDP')]
        [string]$Protocol = "TCP",
        [Parameter(ParameterSetName = 'TCP')]
        [int]$TcpTimeout = 1000,
        [Parameter(ParameterSetName = 'UDP')]
        [int]$UdpTimeout = 1000
    )
    process
    {
        foreach ($Computer in $ComputerName)
        {
            foreach ($Portx in $Port)
            {
                $Output = [ordered]@{ 'Computername' = $Computer; 'Port' = $Portx; 'Protocol' = $Protocol; 'Result' = '' }
                Write-Verbose "$($MyInvocation.MyCommand.Name) - Beginning port test on '$Computer' on port '$Protocol : $Portx'"
                if ($Protocol -eq 'TCP')
                {
                    $TcpClient = New-Object System.Net.Sockets.TcpClient
                    $Connect = $TcpClient.BeginConnect($Computer, $Portx, $null, $null)
                    $Wait = $Connect.AsyncWaitHandle.WaitOne($TcpTimeout, $false)
                    if (!$Wait)
                    {
                        $TcpClient.Close()
                        Write-Verbose "$($MyInvocation.MyCommand.Name) - '$Computer' failed port test on port '$Protocol : $Portx'"
                        $Output.Result = $false
                    }
                    else
                    {
                        $TcpClient.EndConnect($Connect)
                        $TcpClient.Close()
                        Write-Verbose "$($MyInvocation.MyCommand.Name) - '$Computer' passed port test on port '$Protocol<code>:$Portx'"
                        $Output.Result = $true
                    }
                    $TcpClient.Close()
                    $TcpClient.Dispose()
                }
                elseif ($Protocol -eq 'UDP')
                {
                    $UdpClient = New-Object System.Net.Sockets.UdpClient
                    $UdpClient.Client.ReceiveTimeout = $UdpTimeout
                    $UdpClient.Connect($Computer, $Portx)
                    Write-Verbose "$($MyInvocation.MyCommand.Name) - Sending UDP message to computer '$Computer' on port '$Portx'"
                    $a = New-Object system.text.asciiencoding
                    $byte = $a.GetBytes("$(Get-Date)")
                    [void]$UdpClient.Send($byte, $byte.length)
					
                    Write-Verbose "$($MyInvocation.MyCommand.Name) - Creating remote endpoint"
                    $remoteendpoint = New-Object system.net.ipendpoint([system.net.ipaddress]::Any, 0)
                    try
                    {
						
                        Write-Verbose "$($MyInvocation.MyCommand.Name) - Waiting for message return"
                        $receivebytes = $UdpClient.Receive([ref]$remoteendpoint)
                        [string]$returndata = $a.GetString($receivebytes)
                        If ($returndata)
                        {
                            Write-Verbose "$($MyInvocation.MyCommand.Name) - '$Computer' passed port test on port '$Protocol</code>:$Portx'"
                            $Output.Result = $true
                        }
                    }
                    catch
                    {
                        Write-Verbose "$($MyInvocation.MyCommand.Name) - '$Computer' failed port test on port '$Protocol`:$Portx' with error '$($_.Exception.Message)'"
                        $Output.Result = $false
                    }
                    $UdpClient.Close()
                    $UdpClient.Dispose()
                }
                [pscustomobject]$Output
            }
        }
    }
}

#============================================================================
#EXECUTION
#============================================================================
if ($Target -as [ipaddress])
{
    $TargetIP = $Target
    $TargetName = (([System.Net.Dns]::GetHostByAddress("10.22.231.69")).Hostname -split "\.")[0].ToUpper()
}
else
{
    $TargetIP = ([System.Net.Dns]::GetHostAddresses($Target)).IPAddressToString
    $TargetName = $Target
}

$SourceIP =  ([System.Net.Dns]::GetHostAddresses($env:computername)).IPAddressToString | Where-Object {$_ -match  "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$"}

$Result = foreach ($Port in $ADPorts) 
{
    Write-Verbose $("Check > {0} ({1}) from {2} to {3}" -f $Port.Port,$Port.Description,$env:COMPUTERNAME,$Target)
    
    $TestResult = Test-Port -ComputerName $Target -Port $Port.port -Protocol $port.Protocol

    [PSCustomObject]@{
        Source = $env:computername
        SourceIP = $SourceIP
        Destination = $TargetName
        DestinationIP = $TargetIP
        Port = $port.port
        Protocol = $port.protocol
        Description = $port.description
        Open = $TestResult.Result
    }
}

Write-output $Result
#============================================================================
#END
#============================================================================
