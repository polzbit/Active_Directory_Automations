<#######################################################################################################################
Title: Automation Process for First Domain Controller in a Forest
Description: 
    this is a powershell script for creating first domain controller in a new forest name FIZ.local.
    the script works in 3 steps:
        Step 1: 
            a. Turning off Windows Firewall
            b. Static IP Address Configuration
            c. Change computer name to logical name 'FIZ-DC'
            d. Reboot & Continue to Step 2
        Step 2:
            a. Install Active Directory Serivces on server
            b. Promote AD process for new forest 'FIZ.local'
            c. Reboot & Continue to Step 3
        Step 3:
            a. Create new OUs from CSV file
            b. Create Users & Groups from CSV file
            c. link user to group
Date: 15/01/19
Created By Bar Polyak For The Technion CSSI Course
Source for Reboot & Continue process: https://www.codeproject.com/Articles/223002/Reboot-and-Resume-PowerShell-Script
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
$newName = "CyberMainDC"
$newForest = "$global:Forest.$global:ForestEnd"
$newIp = "192.168.1.11"
$defualtGate = "192.168.1.252"
$cardName = "Ethernet0"
$adapter = Get-NetAdapter | ? {$_.Status -eq "up"}

$dsrmPassword = (ConvertTo-SecureString -AsPlainText -Force -String "Admin12345")  # set DSRM password
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
    Rename-Computer -NewName $newName 
    Wait-Prompt "Step A finished successfully, press any key to reboot..." 
    Reboot-To-Step $script "B"
}

if (Check-Step "B") 
{
    Write-Host "STEP B: Install AD Services and Promote Server"
    # Active Directory install and premote process
    Install-windowsfeature -name AD-Domain-Services -IncludeManagementTools
    Install-AddsForest -DomainName $newForest -SafeModeAdministratorPassword $dsrmPassword -Force 
    Reboot-To-Step $script "C"
}

if (Check-Step "C") 
{   
    Write-Host "STEP C: Create OU, Users & GPOs"
    # Create OU, Groups, Users and link users to groups from csv file
    CSV_Create
    # Imports GPOs
    Init-GPO 
    Invoke-GPUpdate
}

Wait-Prompt "Script Complete, press any key to exit script..."

# -------------------------------------
# END
# -------------------------------------