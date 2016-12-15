<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.NOTES
    DEPENDENCEIES
        Helper scripts/functions and/or binaries needed for the function to work.
.PARAMETER
    N parameter
.PARAMETER
    N+1 parameter
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
.INPUTS
    Inputs to this cmdlet (if any)
.OUTPUTS
    Output from this cmdlet (if any)
#>

function New-VNCConnection {

    [CmdletBinding(
        DefaultParameterSetName='Parameter Set 1', 
        PositionalBinding=$true,
        ConfirmImpact='Medium'
    )]
    [Alias('vnc')]
    Param(
        [Parameter(
            Mandatory=$False,
            ParameterSetName='Parameter Set 1'
        )]
        [Alias("vncdir")]
        [string]$VNCViewerDir = $(Read-Host -Prompt "Please enter the full path to the directory that contains vncviewer.exe"),

        [Parameter(
            Mandatory=$False,
            ParameterSetName='Parameter Set 1'
        )]
        $RemoteHost = $(Read-Host -Prompt "Please enter the IP Address or DNS-resolvable name of the remote host."),

        [Parameter(
            Mandatory=$False,
            ParameterSetName='Parameter Set 1'
        )]
        [Alias("remoteport")]
        [int]$RemoteVNCPort = $(Read-Host -Prompt "Please enter the port number listening on the remote VNC Server."),

        [Parameter(
            Mandatory=$False,
            ParameterSetName='Parameter Set 1'
        )]
        [Alias("enc")]
        [switch]$encrypted,

        [Parameter(
            Mandatory=$False,
            ParameterSetName='Parameter Set 1'
        )]
        [Alias("killputty")]
        [switch]$KillExistingPuttyPortForwarding,

        [Parameter(
            Mandatory=$False,
            ParameterSetName='Parameter Set 1'
        )]
        [Alias("localport")]
        [int]$LocalPortForSSHTunnel,

        [Parameter(
            Mandatory=$False,
            ParameterSetName='Parameter Set 1'
        )]
        [string]$PuttyDir,

        [Parameter(
            Mandatory=$False,
            ParameterSetName='Parameter Set 1'
        )]
        [Alias("sshuname")]
        [string]$SSHUserName,

        [Parameter(
            Mandatory=$False,
            ParameterSetName='Parameter Set 1'
        )]
        [Alias("sshkey")]
        [string]$SSHKeyPath
    )

    ##### REGION Helper Functions and Libraries #####

    ## BEGIN Sourced Helper Functions ##

    ## END Sourced Helper Functions ##

    ## BEGIN Native Helper Functions ##
    function Test-Port
    {
        [CmdletBinding()]
        [Alias('testport')]
        Param(
            [Parameter(Mandatory=$False)]
            $RemoteMachine = $(Read-Host -Prompt "Please enter the IP Address or DNS-resolvable name of the remote host."),

            [Parameter(Mandatory=$False)]
            [int]$RemotePort = $(Read-Host -Prompt "Please enter the port number listening on the remote host.")
        )

        Begin {
            ##### BEGIN Variable/Parameter Transforms and PreRun Prep #####
            $tcp = New-Object Net.Sockets.TcpClient
            ##### END Variable/Parameter Transforms and PreRun Prep #####
        }

        Process {
            if ($pscmdlet.ShouldProcess("$RemoteMachine","Test Connection on $RemoteMachine`:$RemotePort")) {
                ##### BEGIN Main Body #####
                try {
                    $tcp.Connect($RemoteMachine, $RemotePort)
                }
                catch {}

                if ($tcp.Connected) {
                    $tcp.Close()
                    $open = $true
                }
                else {
                    $open = $false
                }

                $PortTestResult = [pscustomobject]@{
                    IP      = $RemoteMachine
                    Port    = $RemotePort
                    Open    = $open
                }
                $PortTestResult
                ##### END Main Body #####
            }
        }
    }
    ## END Native Helper Functions ##

    ##### REGION END Helper Functions and Libraries #####


    ##### BEGIN Parameter Validation #####
    # Validate $VNCViewerDir
    if (! $(Test-Path $VNCViewerDir)) {
        Write-Host "The path $VNCViewerDir was not found! Halting!"
        Write-Error "The path $VNCViewerDir was not found! Halting!"
        $global:FunctionResult = "1"
        return
    }

    # Validate $RemoteHost
    if (! $(Test-Connection $RemoteHost -Count 1 -Quiet)) {
        Write-Host "Unable to connect to $RemoteHost. Please ensure $RemoteHost can be resolved and try again. Halting!"
        Write-Error "Unable to connect to $RemoteHost. Please ensure $RemoteHost can be resolved and try again. Halting!"
        $global:FunctionResult = "1"
        return
    }

    try {
        $RemoteHostIPObject = [ipaddress]$RemoteHost
    }
    catch [System.Management.Automation.RuntimeException] {
        Write-Verbose "The parameter `$RemoteHost is NOT an IP Address. Attempting to determine IP..."
        [string]$RemoteHostIP = $(Resolve-DnsName -Name $RemoteHost).IPAddress
    }
    finally {
        if ($RemoteHostIPObject) {
            [string]$RemoteHostIP = $RemoteHostIPObject.IPAddressToString
        }
    }

    # Validate $RemoteVNCPort
    #if (! $(Test-NetConnection -ComputerName $RemoteHostIP -Port $RemoteVNCPort).TcpTestSucceeded)
    if (! $(Test-Port -RemoteMachine $RemoteHostIP -RemotePort $RemoteVNCPort).Open) {
        Write-Host "The port $RemoteVNCPort on remote host $RemoteHost is not open. Halting!"
        Write-Error "The port $RemoteVNCPort on remote host $RemoteHost is not open. Halting!"
        $global:FunctionResult = "1"
        return
    }

    if ($encrypted) {
        # Validate $LocalPortForSSHTunnel
        if (! $LocalPortForSSHTunnel) {
            [int]$LocalPortForSSHTunnel = Read-Host -Prompt "Please enter the local port number that will be used for the ssh tunnel."
        }

        if (! $PuttyDir) {
            $PuttyDir = Read-Host -Prompt "Please enter the full path to the directory that contains putty.exe."
        }
        if (! $(Test-Path $PuttyDir)) {
            Write-Host "The path $PuttyDir was not found! Halting!"
            Write-Error "The path $PuttyDir was not found! Halting!"
            $global:FunctionResult = "1"
            return
        }

        # Validate $SSHUsername
        if (! $SSHUsername) {
            Read-Host -Prompt "Please enter the username for SSH access on the remote host."
        }

        # Validate $SSHKeyPath
        if (! $SSHKeyPath) {
            $SSHKeyPath = Read-Host -Prompt "Please enter the file path to the Putty .ppk key used to access $RemoteHost"
        }
        if (! $(Test-Path $SSHKeyPath)) {
            Write-Host "The path $SSHKeyPath was not found! Halting!"
            Write-Error "The path $SSHKeyPath was not found! Halting!"
            $global:FunctionResult = "1"
            return
        }
    }
    ##### END Parameter Validation #####

    ##### BEGIN Variable/Parameter Transforms and PreRun Prep #####
    $ExistingConnectionUsingLocalPortScenario1 = Get-NetTCPConnection | Where-Object {
        $_.LocalAddress -eq "127.0.0.1" -and `
        $_.RemoteAddress -eq "127.0.0.1" -and `
        $_.LocalPort -eq "$LocalPortForSSHTunnel" -and `
        $_.State -ne "TimeWait" -and `
        $_.State -ne "CloseWait"
    }
    $ExistingConnectionUsingLocalPortScenario2 = Get-NetTCPConnection | Where-Object {
        $_.LocalAddress -eq "127.0.0.1" -and `
        $_.RemoteAddress -eq "0.0.0.0" -and `
        $_.LocalPort -eq "$LocalPortForSSHTunnel" -and `
        $_.State -ne "TimeWait" -and `
        $_.State -ne "CloseWait"
    }
    $ExistingConnectionUsingLocalPortScenario3 = Get-NetTCPConnection | Where-Object {
        $_.LocalAddress -eq "127.0.0.1" -and `
        $_.RemoteAddress -eq "127.0.0.1" -and `
        $_.RemotePort -eq "$LocalPortForSSHTunnel" -and `
        $_.State -ne "TimeWait" -and `
        $_.State -ne "CloseWait"
    }
    $ExistingConnectionUsingLocalPortScenario4 = Get-NetTCPConnection | Where-Object {
        $_.RemoteAddress -ne "$RemoteHostIP" -and `
        $_.RemoteAddress -ne "127.0.0.1" -and `
        $_.RemoteAddress -ne "::" -and `
        $_.RemotePort -eq "$LocalPortForSSHTunnel" -and `
        $_.State -ne "TimeWait" -and `
        $_.State -ne "CloseWait"
    }
    $ExistingConnectionUsingLocalPortScenario5 = Get-NetTCPConnection | Where-Object {
        $_.RemoteAddress -ne "$RemoteHostIP" -and `
        $_.RemoteAddress -ne "0.0.0.0" -and `
        $_.RemoteAddress -ne "::" -and `
        $_.LocalPort -eq "$LocalPortForSSHTunnel" -and `
        $_.State -ne "TimeWait" -and `
        $_.State -ne "CloseWait"
    }
    $ExistingConnectionUsingLocalPortScenario6 = Get-NetTCPConnection | Where-Object {
        $_.RemoteAddress -eq "$RemoteHostIP" -and `
        $_.OwningProcess -eq $($ExistingConnectionUsingLocalPortScenario2.OwningProcess)
    }
    $OwningProcessArray = @()
    $OwningProcessArray += $ExistingConnectionUsingLocalPortScenario1.OwningProcess
    $OwningProcessArray += $ExistingConnectionUsingLocalPortScenario2.OwningProcess
    $OwningProcessArray += $ExistingConnectionUsingLocalPortScenario3.OwningProcess
    $OwningProcessArray += $ExistingConnectionUsingLocalPortScenario4.OwningProcess
    $OwningProcessArray += $ExistingConnectionUsingLocalPortScenario5.OwningProcess
    $OwningProcessArray += $ExistingConnectionUsingLocalPortScenario6.OwningProcess
    $RemoteAddressArray = @()
    $RemoteAddressArray += $ExistingConnectionUsingLocalPortScenario1.RemoteAddress
    $RemoteAddressArray += $ExistingConnectionUsingLocalPortScenario2.RemoteAddress
    $RemoteAddressArray += $ExistingConnectionUsingLocalPortScenario3.RemoteAddress
    $RemoteAddressArray += $ExistingConnectionUsingLocalPortScenario4.RemoteAddress
    $RemoteAddressArray += $ExistingConnectionUsingLocalPortScenario5.RemoteAddress
    $RemoteAddressArray += $ExistingConnectionUsingLocalPortScenario6.RemoteAddress
    
    $ExistingConnectionUsingLocalPortPIDs = $OwningProcessArray | Sort-Object | Get-Unique
    Write-Host "Writing PIDs related to existing tunnel connection:"
    $ExistingConnectionUsingLocalPortPIDs
    $ExistingConnectionUsingLocalPortRemoteHost = foreach ($PIDobj in $ExistingConnectionUsingLocalPortPIDs) {
        $PotentialRemoteAddress = $(Get-NetTCPConnection | Where-Object {
                $_.OwningProcess -eq "$PIDobj" -and `
                $_.RemoteAddress -ne "::" -and `
                $_.RemoteAddress -ne "0.0.0.0" -and `
                $_.RemoteAddress -ne "127.0.0.1"
            }
        ).RemoteAddress
        if ($PotentialRemoteAddress -ne $null)
        {
            $PotentialRemoteAddress
        }
    }
    Write-Host "Writing `$ExistingConnectionUsingLocalPortRemoteHost IP Address:"
    $ExistingConnectionUsingLocalPortRemoteHost

    $VNCViewerPIDs = $(Get-Process -Name vncviewer -ErrorAction SilentlyContinue).Id

    if ($encrypted) {
        if ($VNCViewerPIDs) {
            $VNCSessionsUsingPortForwarding = foreach ($VNCPID in $VNCViewerPIDs) {
                $(Get-NetTCPConnection | Where-Object {
                        $_.OwningProcess -eq "$VNCPID" -and `
                        $_.RemotePort -eq "$LocalPortForSSHTunnel" -and `
                        $_.State -ne "TimeWait" -and `
                        $_.State -ne "CloseWait"
                    }
                ).OwningProcess
            }

            $VNCProcessesToKill = $VNCSessionsUsingPortForwarding | Sort-Object | Get-Unique

            <#
            foreach ($VNCProcessID in $VNCProcessesToKill) {
                if ($(Get-Process -id $VNCProcessID).ProcessName -eq "vncviewer")
                {
                    Stop-Process -id $VNCProcessID
                    Start-Sleep -Seconds 1
                }
            }
            #>
        }

        # Determine if there is already an active VNC Session over an SSH Tunnel to $RemoteHost
        # If so, kill the corresponding VNC PID and Putty PID
        $PuttySessionsUsingVNCPortForwardingPrep = Get-NetTCPConnection | Where-Object {
            $_.RemoteAddress -eq "$RemoteHostIP" -or `
            $_.LocalPort -eq "$LocalPortForSSHTunnel" -and `
            $_.State -ne "TimeWait" -and `
            $_.State -ne "CloseWait"
        }
        if ($PuttySessionsUsingVNCPortForwardingPrep) {
            $PuttySessionsUsingVNCPortForwardingPrep2 = $($PuttySessionsUsingVNCPortForwardingPrep | Group-Object -Property OwningProcess | Where-Object {$_.Count -gt 2})
            $PuttySessionsUsingVNCPortForwarding = $($PuttySessionsUsingVNCPortForwardingPrep2.Name) | Sort-Object | Get-Unique
            Write-Host "Writing PID(s) for `$PuttySessionsUsingVNCPortForwarding"
            $PuttySessionsUsingVNCPortForwarding

            if ($KillExistingPuttyPortForwarding) {
                $PuttyProcessesToKill = foreach ($PuttyPID in $PuttySessionsUsingVNCPortForwarding) {
                    $NumberOfConnections = $($PuttySessionsUsingVNCPortForwardingPrep2.Group | Where-Object {
                        $_.OwningProcess -eq $PuttyPID -and `
                        $_.LocalPort -eq "$LocalPortForSSHTunnel"
                    }).Count
                    if ($NumberofConnections -gt 1) {
                        $PuttyPID
                    }
                }
                Write-Host "Writing PID(s) `$PuttyProcessesToKill"
                $PuttyProcessesToKill

                foreach ($PuttyPIDObj in $PuttyProcessesToKill) {
                    if ($(Get-Process -id $PuttyPIDObj).ProcessName -eq "putty") {
                        Stop-Process -id $PuttyPIDObj
                        Start-Sleep -Seconds 1
                    }
                }
            }
        }
    }

    if (! $encrypted) {
        if ($VNCViewerPIDs) {
            $VNCProcessesToKill = $(Get-NetTCPConnection | Where-Object {
                $_.RemotePort -eq "$RemoteVNCPort" -and `
                $_.State -ne "TimeWait" -and `
                $_.State -ne "CloseWait"
            }).OwningProcess
        }

        <#
        foreach ($VNCProcessID in $VNCProcessesToKill) {
            if ($(Get-Process -id $VNCProcessID).ProcessName -eq "vncviewer")
            {
                Stop-Process -id $VNCProcessID
                Start-Sleep -Seconds 1
            }
        }
        #>
    }
    ##### END Variable/Parameter Transforms and PreRun Prep #####


    ##### BEGIN Main Body #####
    if ($encrypted) {
        if ($RemoteAddressArray -contains $RemoteHostIP) {
            Write-Warning "There is already a tunnel using local port $LocalPortForSSHTunnel! (It's connected to remote host $ExistingConnectionUsingLocalPortRemoteHost)."
        }
        if ($RemoteAddressArray -notcontains $RemoteHostIP -and $ExistingConnectionUsingLocalPortScenario6) {
            Write-Host "Hello"
            Write-Host "There is already a tunnel using local port $LocalPortForSSHTunnel! (It's connected to remote host $ExistingConnectionUsingLocalPortRemoteHost). Halting!"
            Write-Error "There is already a tunnel using local port $LocalPortForSSHTunnel! (It's connected to remote host $ExistingConnectionUsingLocalPortRemoteHost). Halting!"
            $global:FunctionResult = "1"
            return
        }
        if ($pscmdlet.ShouldProcess("$env:ComputerName","Set Up SSH Tunnel on Local Port $LocalPortForSSHTunnel")) {
            if (! $($ExistingConnectionUsingLocalPortScenario1 -or $ExistingConnectionUsingLocalPortScenario2 -or $ExistingConnectionUsingLocalPortScenario3 -or $ExistingConnectionUsingLocalPortScenario4 -or $ExistingConnectionUsingLocalPortScenario5)) {
                & "$PuttyDir\putty.exe" -ssh $RemoteHost -l $SSHUserName -i $SSHKeyPath -L $LocalPortForSSHTunnel`:$RemoteHost`:$RemoteVNCPort
                Start-Sleep -Seconds 2
            }
        }

        $ExistingConnectionUsingLocalPortScenario1Updated = Get-NetTCPConnection | Where-Object {
            $_.LocalAddress -eq "127.0.0.1" -and `
            $_.RemoteAddress -eq "127.0.0.1" -and `
            $_.LocalPort -eq "$LocalPortForSSHTunnel" -and `
            $_.State -ne "TimeWait" -and `
            $_.State -ne "CloseWait"
        }
        $ExistingConnectionUsingLocalPortScenario2Updated = Get-NetTCPConnection | Where-Object {
            $_.LocalAddress -eq "127.0.0.1" -and `
            $_.RemoteAddress -eq "0.0.0.0" -and `
            $_.LocalPort -eq "$LocalPortForSSHTunnel" -and`
            $_.State -ne "TimeWait" -and `
            $_.State -ne "CloseWait"
        }
        $ExistingConnectionUsingLocalPortScenario3Updated = Get-NetTCPConnection | Where-Object {
            $_.LocalAddress -eq "127.0.0.1" -and `
            $_.RemoteAddress -eq "127.0.0.1" -and `
            $_.RemotePort -eq "$LocalPortForSSHTunnel" -and `
            $_.State -ne "TimeWait" -and `
            $_.State -ne "CloseWait"
        }
        $ExistingConnectionUsingLocalPortScenario4Updated = Get-NetTCPConnection | Where-Object {
            $_.RemoteAddress -ne "$RemoteHostIP" -and `
            $_.RemoteAddress -ne "127.0.0.1" -and `
            $_.RemoteAddress -ne "::" -and `
            $_.RemotePort -eq "$LocalPortForSSHTunnel" -and `
            $_.State -ne "TimeWait" -and `
            $_.State -ne "CloseWait"
        }
        $ExistingConnectionUsingLocalPortScenario5Updated = Get-NetTCPConnection | Where-Object {
            $_.RemoteAddress -ne "$RemoteHostIP" -and `
            $_.RemoteAddress -ne "0.0.0.0" -and `
            $_.RemoteAddress -ne "::" -and `
            $_.LocalPort -eq "$LocalPortForSSHTunnel" -and `
            $_.State -ne "TimeWait" -and `
            $_.State -ne "CloseWait"
        }
        $ExistingConnectionUsingLocalPortScenario6Updated = Get-NetTCPConnection | Where-Object {
            $_.RemoteAddress -eq "$RemoteHostIP" -and `
            $_.OwningProcess -eq $($ExistingConnectionUsingLocalPortScenario2.OwningProcess)
        }
        $OwningProcessArrayUpdated = @()
        $OwningProcessArrayUpdated += $ExistingConnectionUsingLocalPortScenario1Updated.OwningProcess
        $OwningProcessArrayUpdated += $ExistingConnectionUsingLocalPortScenario2Updated.OwningProcess
        $OwningProcessArrayUpdated += $ExistingConnectionUsingLocalPortScenario3Updated.OwningProcess
        $OwningProcessArrayUpdated += $ExistingConnectionUsingLocalPortScenario4Updated.OwningProcess
        $OwningProcessArrayUpdated += $ExistingConnectionUsingLocalPortScenario5Updated.OwningProcess
        $OwningProcessArrayUpdated += $ExistingConnectionUsingLocalPortScenario6Updated.OwningProcess
        $RemoteAddressArrayUpdated = @()
        $RemoteAddressArrayUpdated += $ExistingConnectionUsingLocalPortScenario1Updated.RemoteAddress
        $RemoteAddressArrayUpdated += $ExistingConnectionUsingLocalPortScenario2Updated.RemoteAddress
        $RemoteAddressArrayUpdated += $ExistingConnectionUsingLocalPortScenario3Updated.RemoteAddress
        $RemoteAddressArrayUpdated += $ExistingConnectionUsingLocalPortScenario4Updated.RemoteAddress
        $RemoteAddressArrayUpdated += $ExistingConnectionUsingLocalPortScenario5Updated.RemoteAddress
        $RemoteAddressArrayUpdated += $ExistingConnectionUsingLocalPortScenario6Updated.RemoteAddress
        
        if ($ExistingConnectionUsingLocalPortScenario1Updated -and $ExistingConnectionUsingLocalPortScenario2Updated -and $ExistingConnectionUsingLocalPortScenario3Updated) {
            Write-Host "Hi"
            Write-Host "There is already an active VNC session using an SSH tunnel using local port $LocalPortForSSHTunnel! (It's connected to remote host $ExistingConnectionUsingLocalPortRemoteHost). Halting!"
            Write-Error "There is already an active VNC session using an SSH tunnel using local port $LocalPortForSSHTunnel! (It's connected to remote host $ExistingConnectionUsingLocalPortRemoteHost). Halting!"
            $global:FunctionResult = "1"
            return
        }
        if ($RemoteAddressArrayUpdated -notcontains $RemoteHostIP -and ! $($ExistingConnectionUsingLocalPortScenario1 -eq $null -and `
        $ExistingConnectionUsingLocalPortScenario2 -eq $null -and $ExistingConnectionUsingLocalPortScenario3 -eq $null -and `
        $ExistingConnectionUsingLocalPortScenario4 -eq $null -and $ExistingConnectionUsingLocalPortScenario5 -eq $null -and `
        $ExistingConnectionUsingLocalPortScenario6 -eq $null)) {
            Write-Host "bonjour"
            Write-Host "There is already a tunnel using local port $LocalPortForSSHTunnel! (It's connected to remote host $ExistingConnectionUsingLocalPortRemoteHost). Halting!"
            Write-Error "There is already a tunnel using local port $LocalPortForSSHTunnel! (It's connected to remote host $ExistingConnectionUsingLocalPortRemoteHost). Halting!"
            $global:FunctionResult = "1"
            return
        }
        if ($pscmdlet.ShouldProcess("$env:ComputerName","Start VNC Connection via SSH Tunnel on $LocalPortForSSHTunnel")) {
            if ($ExistingConnectionUsingLocalPortScenario6Updated -or `
            $($ExistingConnectionUsingLocalPortScenario1 -eq $null -and $ExistingConnectionUsingLocalPortScenario2 -eq $null -and `
            $ExistingConnectionUsingLocalPortScenario3 -eq $null -and $ExistingConnectionUsingLocalPortScenario4 -eq $null -and `
            $ExistingConnectionUsingLocalPortScenario5 -eq $null -and $ExistingConnectionUsingLocalPortScenario6 -eq $null)) {
                & "$VNCViewerDir\vncviewer.exe" -useaddressbook 127.0.0.1:$LocalPortForSSHTunnel
            }
        }
    }
    if (! $encrypted)
    {
        & "$VNCViewerDir\vncviewer.exe" -useaddressbook $RemoteHostIP`:$RemoteVNCPort
    }

    ##### END Main Body #####

}


# TESTING
# Encrypted, No killputty = SUCCESS
<#
$params = @{
    VNCViewerDir = "C:\Program Files\RealVNC\VNC Viewer"
    RemoteHost = "192.168.2.101"
    RemoteVNCPort = "5900"
    LocalPortForSSHTunnel = "5998"
    PuttyDir = "C:\Program Files (x86)\PuTTY"
    SSHKeypath = "$HOME\.ssh\pdadminmacz-pc_keypair.ppk"
    SSHUserName = "pdadmin"
}

New-VNCConnection @params -encrypted
#>

# Encrypted, killputty = SUCCESS
<#
$params = @{
    VNCViewerDir = "C:\Program Files\RealVNC\VNC Viewer"
    RemoteHost = "192.168.2.101"
    RemoteVNCPort = "5900"
    LocalPortForSSHTunnel = "5999"
    PuttyDir = "C:\Program Files (x86)\PuTTY"
    SSHKeypath = "$HOME\.ssh\pdadminmacz-pc_keypair.ppk"
    SSHUserName = "pdadmin"
}

New-VNCConnection @params -encrypted -killputty
#>

# Unencrypted
<#
New-VNCConnection -VNCViewerDir "C:\Program Files\RealVNC\VNC Viewer"`
-RemoteHost "192.168.2.101"`
-RemoteVNCPort "5900"
#>


# Different RemoteHost, Same LocalPortForSSHTunnel
# Encrypted, No killputty = SUCCESS
$params = @{
    VNCViewerDir = "C:\Program Files\RealVNC\VNC Viewer"
    RemoteHost = "192.168.2.34"
    RemoteVNCPort = "5904"
    LocalPortForSSHTunnel = "5999"
    PuttyDir = "C:\Program Files (x86)\PuTTY"
    SSHKeypath = "$HOME\.ssh\centos7-ws_keypair.ppk"
    SSHUserName = "pdadmin"
}

New-VNCConnection @params -encrypted


# Unencrypted
<#
New-VNCConnection -VNCViewerDir "C:\Program Files\RealVNC\VNC Viewer"`
-RemoteHost "192.168.2.34"`
-RemoteVNCPort "5904"
#>


#### ARCHIVE #####
<#
$PuttySessionsUsingVNCPortForwardingPrep = Get-NetTCPConnection | Where-Object {$_.RemoteAddress -eq "$RemoteHostIP" -or $_.LocalPort -eq "$LocalPortForSSHTunnel" `
-and $_.State -ne "TimeWait" -and $_.State -ne "CloseWait"}
$PuttySessionsUsingVNCPortForwardingPrep2 = $($PuttySessionsUsingVNCPortForwardingPrep | Group-Object -Property OwningProcess | Where-Object {$_.Count -gt 1})
$PuttySessionsUsingVNCPortForwarding = $($PuttySessionsUsingVNCPortForwardingPrep2.Name) | Sort-Object | Get-Unique

if ($($PuttySessionsUsingVNCPortForwardingPrep2.Group | Where-Object {$_.LocalPort -eq "$LocalPortForSSHTunnel"}).Count -gt 1)
{
    Write-Host "SSH Tunnel from local port $LocalPortForSSHTunnel to remote host $RemoteHost port $RemoteVNCPort is already open!"
}
if (! $PuttySessionsUsingVNCPortForwardingPrep -or `
    $($PuttySessionsUsingVNCPortForwardingPrep2.Group | Where-Object {$_.LocalPort -eq "$LocalPortForSSHTunnel"}).Count -le 1)
#>

##### ARCHIVE #####











# SIG # Begin signature block
# MIIMLAYJKoZIhvcNAQcCoIIMHTCCDBkCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQULq3xpTDk4+mQmONV8DvftUkK
# I5mgggmhMIID/jCCAuagAwIBAgITawAAAAQpgJFit9ZYVQAAAAAABDANBgkqhkiG
# 9w0BAQsFADAwMQwwCgYDVQQGEwNMQUIxDTALBgNVBAoTBFpFUk8xETAPBgNVBAMT
# CFplcm9EQzAxMB4XDTE1MDkwOTA5NTAyNFoXDTE3MDkwOTEwMDAyNFowPTETMBEG
# CgmSJomT8ixkARkWA0xBQjEUMBIGCgmSJomT8ixkARkWBFpFUk8xEDAOBgNVBAMT
# B1plcm9TQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCmRIzy6nwK
# uqvhoz297kYdDXs2Wom5QCxzN9KiqAW0VaVTo1eW1ZbwZo13Qxe+6qsIJV2uUuu/
# 3jNG1YRGrZSHuwheau17K9C/RZsuzKu93O02d7zv2mfBfGMJaJx8EM4EQ8rfn9E+
# yzLsh65bWmLlbH5OVA0943qNAAJKwrgY9cpfDhOWiYLirAnMgzhQd3+DGl7X79aJ
# h7GdVJQ/qEZ6j0/9bTc7ubvLMcJhJCnBZaFyXmoGfoOO6HW1GcuEUwIq67hT1rI3
# oPx6GtFfhCqyevYtFJ0Typ40Ng7U73F2hQfsW+VPnbRJI4wSgigCHFaaw38bG4MH
# Nr0yJDM0G8XhAgMBAAGjggECMIH/MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQW
# BBQ4uUFq5iV2t7PneWtOJALUX3gTcTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMA
# QTAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBR2
# lbqmEvZFA0XsBkGBBXi2Cvs4TTAxBgNVHR8EKjAoMCagJKAihiBodHRwOi8vcGtp
# L2NlcnRkYXRhL1plcm9EQzAxLmNybDA8BggrBgEFBQcBAQQwMC4wLAYIKwYBBQUH
# MAKGIGh0dHA6Ly9wa2kvY2VydGRhdGEvWmVyb0RDMDEuY3J0MA0GCSqGSIb3DQEB
# CwUAA4IBAQAUFYmOmjvbp3goa3y95eKMDVxA6xdwhf6GrIZoAg0LM+9f8zQOhEK9
# I7n1WbUocOVAoP7OnZZKB+Cx6y6Ek5Q8PeezoWm5oPg9XUniy5bFPyl0CqSaNWUZ
# /zC1BE4HBFF55YM0724nBtNYUMJ93oW/UxsWL701c3ZuyxBhrxtlk9TYIttyuGJI
# JtbuFlco7veXEPfHibzE+JYc1MoGF/whz6l7bC8XbgyDprU1JS538gbgPBir4RPw
# dFydubWuhaVzRlU3wedYMsZ4iejV2xsf8MHF/EHyc/Ft0UnvcxBqD0sQQVkOS82X
# +IByWP0uDQ2zOA1L032uFHHA65Bt32w8MIIFmzCCBIOgAwIBAgITWAAAADw2o858
# ZSLnRQAAAAAAPDANBgkqhkiG9w0BAQsFADA9MRMwEQYKCZImiZPyLGQBGRYDTEFC
# MRQwEgYKCZImiZPyLGQBGRYEWkVSTzEQMA4GA1UEAxMHWmVyb1NDQTAeFw0xNTEw
# MjcxMzM1MDFaFw0xNzA5MDkxMDAwMjRaMD4xCzAJBgNVBAYTAlVTMQswCQYDVQQI
# EwJWQTEPMA0GA1UEBxMGTWNMZWFuMREwDwYDVQQDEwhaZXJvQ29kZTCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBAJ8LM3f3308MLwBHi99dvOQqGsLeC11p
# usrqMgmEgv9FHsYv+IIrW/2/QyBXVbAaQAt96Tod/CtHsz77L3F0SLuQjIFNb522
# sSPAfDoDpsrUnZYVB/PTGNDsAs1SZhI1kTKIjf5xShrWxo0EbDG5+pnu5QHu+EY6
# irn6C1FHhOilCcwInmNt78Wbm3UcXtoxjeUl+HlrAOxG130MmZYWNvJ71jfsb6lS
# FFE6VXqJ6/V78LIoEg5lWkuNc+XpbYk47Zog+pYvJf7zOric5VpnKMK8EdJj6Dze
# 4tJ51tDoo7pYDEUJMfFMwNOO1Ij4nL7WAz6bO59suqf5cxQGd5KDJ1ECAwEAAaOC
# ApEwggKNMA4GA1UdDwEB/wQEAwIHgDA9BgkrBgEEAYI3FQcEMDAuBiYrBgEEAYI3
# FQiDuPQ/hJvyeYPxjziDsLcyhtHNeIEnofPMH4/ZVQIBZAIBBTAdBgNVHQ4EFgQU
# a5b4DOy+EUyy2ILzpUFMmuyew40wHwYDVR0jBBgwFoAUOLlBauYldrez53lrTiQC
# 1F94E3EwgeMGA1UdHwSB2zCB2DCB1aCB0qCBz4aBq2xkYXA6Ly8vQ049WmVyb1ND
# QSxDTj1aZXJvU0NBLENOPUNEUCxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxD
# Tj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPXplcm8sREM9bGFiP2NlcnRp
# ZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFzcz1jUkxEaXN0cmli
# dXRpb25Qb2ludIYfaHR0cDovL3BraS9jZXJ0ZGF0YS9aZXJvU0NBLmNybDCB4wYI
# KwYBBQUHAQEEgdYwgdMwgaMGCCsGAQUFBzAChoGWbGRhcDovLy9DTj1aZXJvU0NB
# LENOPUFJQSxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxD
# Tj1Db25maWd1cmF0aW9uLERDPXplcm8sREM9bGFiP2NBQ2VydGlmaWNhdGU/YmFz
# ZT9vYmplY3RDbGFzcz1jZXJ0aWZpY2F0aW9uQXV0aG9yaXR5MCsGCCsGAQUFBzAC
# hh9odHRwOi8vcGtpL2NlcnRkYXRhL1plcm9TQ0EuY3J0MBMGA1UdJQQMMAoGCCsG
# AQUFBwMDMBsGCSsGAQQBgjcVCgQOMAwwCgYIKwYBBQUHAwMwDQYJKoZIhvcNAQEL
# BQADggEBACbc1NDl3NTMuqFwTFd8NHHCsSudkVhuroySobzUaFJN2XHbdDkzquFF
# 6f7KFWjqR3VN7RAi8arW8zESCKovPolltpp3Qu58v59qZLhbXnQmgelpA620bP75
# zv8xVxB9/xmmpOHNkM6qsye4IJur/JwhoHLGqCRwU2hxP1pu62NUK2vd/Ibm8c6w
# PZoB0BcC7SETNB8x2uKzJ2MyAIuyN0Uy/mGDeLyz9cSboKoG6aQibnjCnGAVOVn6
# J7bvYWJsGu7HukMoTAIqC6oMGerNakhOCgrhU7m+cERPkTcADVH/PWhy+FJWd2px
# ViKcyzWQSyX93PcOj2SsHvi7vEAfCGcxggH1MIIB8QIBATBUMD0xEzARBgoJkiaJ
# k/IsZAEZFgNMQUIxFDASBgoJkiaJk/IsZAEZFgRaRVJPMRAwDgYDVQQDEwdaZXJv
# U0NBAhNYAAAAPDajznxlIudFAAAAAAA8MAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3
# AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisG
# AQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSN5xTwCyGm
# x73BwrmWZ3ZfTrwSDjANBgkqhkiG9w0BAQEFAASCAQCIpSC+YfPwabSy/2orMMP0
# azOd+wajmoejTsM79NHP65EjToJ2rUahghi3jLAIMncb/FmVQfjm3GvKguZfYct/
# O/SQMPvRrE75YMO6V0mLALVSJkMQwMN9IIv8sA2+Ycpf5BLZh7LcOYCV3mF25BAY
# pJ2zS/RWOXk6n0BgnlFHF+jzc5pRnZL24fNBR1mT5fagAY+BxGxRRFfULmnCvxn9
# wPWlZ7bpURCcGMiDot9O5JZkTC90B1Y3TVwfuX5QJa+oC8IWjoE5FHUF/kwTTQfb
# 27AfL1MNjNiujNYMSGWdgcHIknYVaFDehnvlyIL3UjuQH5mZxyWND4AAv87Zxm6P
# SIG # End signature block