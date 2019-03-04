<#######################################################################################################################
Title: Automation Process for Install FSRM Server in a Forest
Description: 
    this is a powershell script for creating file server in a forest name qcyber.local.
    the script works in 3 steps:
        Step 2: 
            a. Turning off Windows Firewall
            b. Static IP Address Configuration
            c. Change computer name to logical name 
            d. Reboot & Continue to Step 2
        Step 2:
            a. Install FSRM Serivces on the server
#######################################################################################################################>

param($Step="A")
# -------------------------------------
# Imports
# -------------------------------------
$script = $myInvocation.MyCommand.Definition
$scriptPath = Split-Path -parent $script
. (Join-Path $scriptpath _setup_.ps1)
# -------------------------------------
# Variables
# -------------------------------------
$newName = "FS-SRV"
$myForest = "$global:Forest.$global:ForestEnd"
$newIp = "ENTER IP HERE"
$defualtGate = "ENTER GATEWAY HERE"
$cardName = "Ethernet0"
$password = (ConvertTo-SecureString -AsPlainText -Force -String "Admin12345")  # set DSRM password
$username = "$global:Forest\Administrator" 
$credential = New-Object System.Management.Automation.PSCredential($username,$password)
$csvPath="C:\FS_INIT\users.csv"
# -------------------------------------
# START
# -------------------------------------
Clear-Reg

if (Check-Step "A") 
{
    Write-Host "STEP A: Server First Setup (firewall off, new name, static IP)"
    # Turn off Firewall
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
    # Static IP Configuration
    New-NetIPAddress -InterfaceAlias $cardName -AddressFamily IPv4 -IPAddress $newIp -PrefixLength 24 -DefaultGateway $defualtGate  # You want to set a subnet mask of 255.255.255.0 (which is /24 in CIDR notation)
    Set-DnsClientServerAddress -InterfaceAlias $cardName -ServerAddresses $defualtGate
     # Change Computer name and REBOOT
    Rename-Computer -NewName $newName -LocalCredential $credential
    Start-Sleep 5
    # Add server to Domain
    Add-Computer -DomainName $myForest -NewName $newName -Credential $credential

    Wait-Prompt "Step A finished successfully, press any key to reboot..." 
    Reboot-To-Step $script "B"
}

if (Check-Step "B") 
{
    Write-Host "STEP B: Install FSRM Services"
    # FSRM install
    Install-WindowsFeature -Name FS-Resource-Manager, RSAT-FSRM-Mgmt
    
    #Create FS Folders
    CSV_FOLDERS $csvPath

    # new Quota no audio & video at Z drive
    New-FsrmFileScreen -Path "C:\Sharing\mapped_drives\Office" -Description "No Audio & Video in Office Shared folder" -Template "Block Audio and Video Files"

    # Reboot-To-Step $script "C"
}

if (Check-Step "C") 
{
    # Enable Shadow-Copy C Drive
    vssadmin add shadowstorage /for=C: /on=C:  /maxsize=8128MB
    vssadmin create shadow /for=C:

    #Set Shadow Copy Scheduled Task for C: AM
    $Action=new-scheduledtaskaction -execute "c:\windows\system32\vssadmin.exe" -Argument "create shadow /for=C:"
    $Trigger=new-scheduledtasktrigger -daily -at 6:00AM
    Register-ScheduledTask -TaskName ShadowCopyC_AM -Trigger $Trigger -Action $Action -Description "ShadowCopyC_AM"

    Wait-Prompt "Script Complete, press any key to exit script..."
}

# -------------------------------------
# END
# -------------------------------------
