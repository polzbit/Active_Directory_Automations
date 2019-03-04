<#######################################################################################################################
Title: Functions Definition For Automation Process Install FSRM Server in a Forest
Description: 
    a set of Powershell functions for first DC automation, uses a registry key to continue the script after reboot
    - Function globals for registry
    - Utility functions to help Setup functions
    - Setup functions for reboot & continue
    - Create sharing, mapdrive, folder redirection folders for file server
#######################################################################################################################>

# -------------------------------------
# Functions Globals Variables
# -------------------------------------
$global:start = $FALSE
$global:start_step = $Step
$global:reboot_key = "Reboot-To-Step"                                                          # Reboot key to write
$global:run_registry ="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"                         # Run registry
$global:ps = (Join-Path $env:windir "system32\WindowsPowerShell\v1.0\powershell.exe")               # Powershell variable

$global:Forest = "qcyber"          # Domain name 
$global:ForestEnd = "local"     # End of Domain name

$global:defaultPassword = "Admin12345"

# Rights
$readOnly = [System.Security.AccessControl.FileSystemRights]"ReadAndExecute"
$readWrite = [System.Security.AccessControl.FileSystemRights]"Modify"
$fullControl = [System.Security.AccessControl.FileSystemRights]"FullControl"

# Inheritance
$inheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
# Propagation
$propagationFlag = [System.Security.AccessControl.PropagationFlags]::None
# User Type
$type = [System.Security.AccessControl.AccessControlType]::Allow
# -------------------------------------
# Utility Functions
# -------------------------------------

# Function to check current step after reboot
function Check-Step([string] $prospectStep) 
{
    if ($global:start_step -eq $prospectStep -or $global:start) {
        $global:start = $TRUE
    }
    return $global:start
}
# Function to prompt message and wait for user key press
function Wait-Prompt([string] $message, [bool] $shouldExit=$FALSE) 
{
    Write-Host "$message" -foregroundcolor yellow
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    if ($shouldExit) {
        exit
    }
}
# Test run registry key
function Test-Reg([string] $path, [string] $key)
{
    return ((Test-Path $path) -and ((Get-RegKey $path $key) -ne $null))   
}
# remove run registry key
function Remove-RegKey([string] $path, [string] $key)
{
    Remove-ItemProperty -path $path -name $key
}
# set run registry key
function Set-RegKey([string] $path, [string] $key, [string] $value) 
{
    Set-ItemProperty -path $path -name $key -value $value
}
# get run registry key
function Get-RegKey([string] $path, [string] $key) 
{
    return (Get-ItemProperty $path).$key
}
# Function to set run registry key and reboot machine
function Reboot-And-Back([string] $key, [string] $run) 
{
    Set-RegKey $global:run_registry $key $run
    Restart-Computer
    exit
} 

# -------------------------------------
# Setup Functions
# -------------------------------------
# get CN	
Function Get-VComputerName {[system.environment]::MachineName}

# clear registry
function Clear-Reg([string] $key=$global:reboot_key) 
{
    # check regstry 
    if (Test-Reg $global:run_registry $key) {
        Remove-RegKey $global:run_registry $key
    }
}
# Function for reboot & continue
function Reboot-To-Step([string] $script, [string] $step) 
{
    Reboot-And-Back $global:reboot_key "$global:ps $script -Step $step"
}
function New-FS-Folders() {
    # Create main sharing folder for organization
    new-item c:\Sharing -itemtype directory
    # Create Home folders for every department
    new-item c:\Sharing\home_folders -itemtype directory
    new-item c:\Sharing\home_folders\management_home -itemtype directory
    new-item c:\Sharing\home_folders\marketing_home -itemtype directory
    new-item c:\Sharing\home_folders\it_home -itemtype directory
    new-item c:\Sharing\home_folders\blue_home -itemtype directory
    new-item c:\Sharing\home_folders\red_home -itemtype directory
    # Create MapDrive folders for every department
    new-item c:\Sharing\mapped_drives -itemtype directory
    new-item c:\Sharing\mapped_drives\management_drive -itemtype directory
    new-item c:\Sharing\mapped_drives\marketing_drive -itemtype directory
    new-item c:\Sharing\mapped_drives\it_drive -itemtype directory
    new-item c:\Sharing\mapped_drives\blue_drive -itemtype directory
    new-item c:\Sharing\mapped_drives\red_drive -itemtype directory
    # Create Redirect folders for every department
    new-item c:\Sharing\folder_redirections -itemtype directory
    new-item c:\Sharing\folder_redirections\management_redirect -itemtype directory
    new-item c:\Sharing\folder_redirections\marketing_redirect -itemtype directory
    new-item c:\Sharing\folder_redirections\it_redirect -itemtype directory
    new-item c:\Sharing\folder_redirections\blue_redirect -itemtype directory
    new-item c:\Sharing\folder_redirections\red_redirect -itemtype directory
}

function New-Share([string] $Name,[string] $Path) {
    New-SMBShare -Name $Name -Path $Path
    # Grant-SmbShareAccess -Name $Name -AccountName "Creator Owner" -AccessRight Full -Force
    Grant-SmbShareAccess -Name $Name -AccountName "Domain Users" -AccessRight Read -Force
    Grant-SmbShareAccess -Name $Name -AccountName "System" -AccessRight Full -Force
    Grant-SmbShareAccess -Name $Name -AccountName "Administrator" -AccessRight Full -Force
    Grant-SmbShareAccess -Name $Name -AccountName "Authenticated Users" -AccessRight Full -Force
}

function New-Per([string] $Name,[string] $Path,[string] $Perr) {
    $userRW = New-Object System.Security.Principal.NTAccount($Name)
    icacls $Path /inheritance:d
    if($perr -eq "readOnly") {
        $accessControlEntryRW = New-Object System.Security.AccessControl.FileSystemAccessRule @($userRW, $readOnly, $inheritanceFlag, $propagationFlag, $type)
    }
    if($perr -eq "Modify") {
        $accessControlEntryRW = New-Object System.Security.AccessControl.FileSystemAccessRule @($userRW, $readWrite, $inheritanceFlag, $propagationFlag, $type)
    }
    if($perr -eq "fullControl") {
        $accessControlEntryRW = New-Object System.Security.AccessControl.FileSystemAccessRule @($userRW, $fullControl, $inheritanceFlag, $propagationFlag, $type)
    }
    $objACL = Get-ACL $Path
    $objACL.AddAccessRule($accessControlEntryRW)
    Set-ACL $Path $objACL
    
}
function CSV_FOLDERS([string] $path) 
{
    #Loop through each row containing user details in the CSV file 
    $ADFolders = Import-csv $path   #Store the data from users.csv in variable
    $OUlist = $ADFolders.ou       # get list of all users OUs 
    $OUlist = $OUlist | Select-Object -uniq    # get unique OUs from OU list
    # Create main sharing folder for organization
    new-item c:\Sharing -itemtype directory
    New-Share -Name "Shared" -Path "C:\Sharing"
    # Create Home Folders

    new-item "c:\Sharing\folder_redirections\Documents" -itemtype directory
    New-Share -Name "docRedirect" -Path "c:\Sharing\folder_redirections\Documents"

    new-item "c:\Sharing\home_folders" -itemtype directory
    New-Share -Name "Home map" -Path "c:\Sharing\home_folders"
    Grant-SmbShareAccess -Name "Home map" -AccountName "Authenticated Users" -AccessRight Full -Force

    new-item "c:\Sharing\mapped_drives" -itemtype directory
    New-Share -Name "Drive map" -Path "c:\Sharing\mapped_drives"

    new-item "C:\Sharing\mapped_drives\Office" -itemtype directory
    New-Share -Name "Cyber Share" -Path "C:\Sharing\mapped_drives\Office"
    New-Per -Name "CREATOR OWNER" -Path "C:\Sharing\mapped_drives\Office" -Perr "readOnly"
    New-Per -Name "mng" -Path "C:\Sharing\mapped_drives\Office" -Perr "Modify"
    # icacls "C:\Sharing\mapped_drives\Office" /remove 'creator owner' everyone

    foreach ($Folder in $ADFolders)
    {
        $Fname = $Folder.username
        $job = $Folder.jobtitle
        $Fpath = "C:\Sharing\home_folders\$Fname"
        $userRW = New-Object System.Security.Principal.NTAccount($Fname)
        new-item $Fpath -itemtype directory 
        New-Per -Name $Fname -Path $Fpath -Perr "fullControl"

        if($folder.ou -eq "IT" -AND $job -eq "Manager") {
            New-Per -Name $Fname -Path "C:\Sharing" -Perr "fullControl"
            New-Per -Name $Fname -Path "C:\Sharing\mapped_drives\Office" -Perr "fullControl"
            New-Per -Name $Fname -Path "C:\Sharing\home_folders" -Perr "fullControl"
            New-Per -Name $Fname -Path "C:\Sharing\mapped_drives" -Perr "fullControl"
        }
        
    }
    foreach($OU in $OUlist) {
        $OUname = "$OU-drive"
        $OUpath = "C:\Sharing\mapped_drives\$OUname"
        $grpName = "$OU-group"
        $userRW= New-Object System.Security.Principal.NTAccount($grpName)
        # create map drive folders and set permission
        new-item $OUpath -itemtype directory
        New-Per -Name $grpName -Path $OUpath -Perr "fullControl"
        # check for IT manager, gets full control
        New-Per -Name $grpName -Path "C:\Sharing\mapped_drives\Office" -Perr "readOnly"
        
        $Rname = "$OU-desktop"
        $Rpath = "C:\Sharing\folder_redirections\Desktop\$Rname"
        Remove-SmbShare -Name $Rname -Force
        new-item $Rpath -itemtype directory
        New-Share -Name $Rname -Path $Rpath 
        Grant-SmbShareAccess -Name $Rname -AccountName $grpName -AccessRight Change -Force

        if($OU -eq "IT") {
            icacls "C:\Sharing\mapped_drives\Office" /inheritance:d
            $Account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList $grpName;
            $accessControlEntry = New-Object System.Security.AccessControl.FileSystemAccessRule @($userRW, $readWrite, $inheritanceFlag, $propagationFlag, $type)
            $objACL = Get-ACL "C:\Sharing\mapped_drives\Office" 
            $objACL.AddAccessRule($accessControlEntry)
            $objACL.SetOwner($Account)
            Set-ACL "C:\Sharing\mapped_drives\Office" $objACL
        }
        Grant-SmbShareAccess -Name "docRedirect" -AccountName $grpName -AccessRight Change -Force
    } 
}
