<#######################################################################################################################
Title: Automation Process for Replication of Domain Controller in a Forest
Description: 
    this is a powershell script for creating replication for domain controller in a forest.
    the script works in 3 steps:
        Step 1: 
            a. Turning off Windows Firewall
            b. Static IP Address Configuration
            c. Change computer name to logical name
            d. Reboot & Continue to Step 2
        Step 2:
            a. Install Active Directory Serivces on server
            b. Promote DC Replication process for existing Forest
            c. Reboot & Continue to Step 3
        Step 3:
            a. Install DHCP Services
            b. Configure DHCP
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
$DC = "CyberMainDC"
$CN = Get-VComputerName
$newName = "CyberSecDC"
$myForest = "$global:Forest.$global:ForestEnd"
$newIp = "ENTER IP HERE"
$defualtGate = "ENTER GATEWAY HERE"
$cardName = "Ethernet0"
$password = (ConvertTo-SecureString -AsPlainText -Force -String "Admin12345")  # set DSRM password
$username = "$global:Forest\Administrator" 
$credential = New-Object System.Management.Automation.PSCredential($username,$password)

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
    Write-Host "STEP B: Install AD Services and Promote Second DC Replicated Server"
    # Active Directory install and premote process
    Install-windowsfeature -name AD-Domain-Services -IncludeManagementTools
    Install-ADDSDomainController -DomainName $myForest -Credential $credential -SafeModeAdministratorPassword $password -NoGlobalCatalog:$false -ReplicationSourceDC "$DC.$myForest" -Force 
    Reboot-To-Step $script "C"
}

if (Check-Step "C") 
{   
    Write-Host "STEP C: Install & Configure DHCP Services"
    Install-WindowsFeature DHCP -IncludeManagementTools
    $scopeID = "qcyber_pool"
	
    Add-DhcpServerInDC -DnsName "$newName.$myForest" -IPAddress $newIp   
    Add-DHCPServerSecurityGroup -ComputerName $newName
    Set-DHCPServerDnsCredential -ComputerName $newName -Credential $credential
    netsh dhcp add securitygroups
    Add-DhcpServerv4Scope -Name $scopeID  -StartRange 192.168.1.1 -EndRange 192.168.1.254 -SubnetMask 255.255.255.0 -Description "Qcyber Network Pool"
    Set-DhcpServerv4OptionValue -ScopeId 192.168.1.0 -DnsServer 192.168.1.11 -WinsServer 192.168.1.12 -DnsDomain $myForest -Router 192.168.1.252
    Set-DhcpServerv4Scope -ScopeId 192.168.1.10 -LeaseDuration 1.00:00:00
    Add-Dhcpserverv4ExclusionRange -ScopeId 192.168.1.0 -StartRange 192.168.1.1 -EndRange 192.168.1.20
    Add-Dhcpserverv4ExclusionRange -ScopeId 192.168.1.0 -StartRange 192.168.1.200 -EndRange 192.168.1.254
    Restart-service dhcpserver
    Get-DhcpServerInDC
}
if (Check-Step "D") 
{   
    Wait-Prompt "Script Complete, press any key to exit script..."
}
# -------------------------------------
# END
# -------------------------------------
