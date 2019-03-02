<#######################################################################################################################
Title: Functions Definition For Automation Process First Domain Controller in a Forest
Description: 
    a set of Powershell functions for first DC automation, uses a registry key to continue the script after reboot
    - Function globals for registry
    - Utility functions to help Setup functions
    - Setup functions for reboot & continue
    - Function to create OU, groups & users from CSV file and link user to group
Date: 15/01/19
Created By Bar Polyak For The Technion CSSI Course
Source for Reboot & Continue process: https://www.codeproject.com/Articles/223002/Reboot-and-Resume-PowerShell-Script
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
$csvPath="C:\AD_INIT\users.csv"
$gpoPath="C:\AD_INIT\GPOs"
$ADUsers = Import-csv $csvPath   #Store the data from users.csv in the $ADUsers variable
$OUlist = $ADUsers.ou       # get list of all users OUs 
$OUlist = $OUlist | Select-Object -uniq    # get unique OUs from OU list
# -------------------------------------
# Utility Functions
# -------------------------------------
# get CN	
Function Get-VComputerName {[system.environment]::MachineName}

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
# Function to create users from csv file
function CSV_Create() 
{
    #Loop through each row containing user details in the CSV file 
    # Create Domain & Groups OU
    NEW-ADOrganizationalUnit $global:Forest -path "DC=$global:Forest,DC=$global:ForestEnd"
    NEW-ADOrganizationalUnit "Groups" -path "OU=$global:Forest,DC=$global:Forest,DC=$global:ForestEnd"
    New-ADGroup "mng" -Path "OU=Groups,OU=$global:Forest,DC=$global:Forest,DC=$global:ForestEnd" -GroupCategory Security -GroupScope Global
    # Create department OUs
    foreach($Unit in $OUlist)
    {
        NEW-ADOrganizationalUnit $Unit -path "OU=$global:Forest,DC=$global:Forest,DC=$global:ForestEnd"
        $GroupName = $Unit + "-group"
        New-ADGroup $GroupName -Path "OU=Groups,OU=$global:Forest,DC=$global:Forest,DC=$global:ForestEnd" -GroupCategory Security -GroupScope Global
    }
    
    # Create Users
    foreach ($User in $ADUsers)
    {
        #Read user data from each field in each row and assign the data to a variable as below
	    
	    $Password 	= $global:defaultPassword
	    $Firstname 	= $User.firstname
	    $Lastname 	= $User.lastname
        $Username 	= $User.username
        $email      = "$Username@$global:Forest.com"
	    $OU 		= $User.ou      #This field refers to the OU the user account is to be created in
        
        $streetaddress = $User.streetaddress
        $city       = $User.city
        $country    = $User.country
        $telephone  = $User.telephone
        $jobtitle   = $User.jobtitle
        ## allow logon 8am - 4pm Sunday to Thursday
        [byte[]]$full_hours = @(255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255)                  
        [byte[]]$hours = @(192,63,0,192,63,0,192,63,0,192,63,0,192,63,0,0,0,0,0,0,0)           

        $homeDirectory = "\\FS-SRV\Home map\$Username"
        $homeDrive = "H:"
	    #Check to see if the user already exists in AD
	    if (Get-ADUser -F {SamAccountName -eq $Username})
	    {
		    #If user does exist, give a warning
		    Write-Warning "A user account with username $Username already exist in Active Directory."
	    }
	    else
	    {
		    #User does not exist then proceed to create the new user account
            #Account will be created in the OU provided by the $OU variable read from the CSV file
		    New-ADUser `
                -SamAccountName $Username `
                -UserPrincipalName $email `
                -Name "$Firstname $Lastname" `
                -GivenName $Firstname `
                -Surname $Lastname `
                -Enabled $True `
                -DisplayName "$Lastname, $Firstname" `
                -Path "OU=$OU,OU=$global:Forest,DC=$global:Forest,DC=$global:ForestEnd" `
                -City $city `
                -Company $global:Forest `
                -Country $country `
                -StreetAddress $streetaddress `
                -OfficePhone $telephone `
                -EmailAddress $email `
                -Title $jobtitle `
                -Department $OU `
                -ChangePasswordAtLogon $true `
                -AccountPassword (convertto-securestring $Password -AsPlainText -Force)
            Set-ADUser -Identity $Username -Replace @{logonhours = $full_hours}
            Set-ADUser -Identity $Username -HomeDrive $homeDrive -HomeDirectory $homeDirectory
            $grpName = "$OU-group"
            Add-AdGroupMember -Identity $grpName -Members $Username
            Add-AdGroupMember -Identity "Remote Desktop Users" -Members $Username
            if($jobtitle -eq "Manager") {
                Add-AdGroupMember -Identity "mng" -Members $Username
                if($OU -eq "IT") {
                    Set-ADUser -Identity $Username -PasswordNeverExpires 1  -ChangePasswordAtLogon $false  # IT Manager password never expires
                }
            }
            if($OU -eq "Marketing") {
                Set-ADUser -Identity $Username -Replace @{logonhours = $hours}      # Marketing log-in only between 8am - 16pm
            }
	    }
    }
}

# Import GPO Policies
# set a password policy rules: 
# 1. password must be at least 8 chars 
# 2. user must change password every 2 months 
# 3. user cannot use pervios password at least 6 months back
# 4. user that enter password wrong fot 3 times wil be locked, only IT Department can Unlock the user
function Init-GPO() 
{   
    # Default Domain Policy Configuration for min password length 8 chars
    Set-ADDefaultDomainPasswordPolicy -Identity "$global:Forest.$global:ForestEnd" -MinPasswordLength 8 -ComplexityEnabled $False -LockoutThreshold 3 -PasswordHistoryCount 3 
    # import & link backup GPO from folder
    $GPOFolderName = $gpoPath
    $import_array = get-childitem $GPOFolderName | Select-Object name
    foreach ($ID in $import_array) {
        $XMLFile = $GPOFolderName + "\" + $ID.Name + "\gpreport.xml"
        $XMLData = [XML](get-content $XMLFile)
        $GPOName = $XMLData.GPO.Name
        import-gpo -BackupId $ID.Name -TargetName $GPOName -path $GPOFolderName -CreateIfNeeded
        New-GPLink -Name $GPOName -Target "ou=$global:Forest,dc=$global:Forest,dc=$global:ForestEnd"  -LinkEnabled Yes
        <#
        foreach($dep in $OUlist) {
            New-GPLink -Name $GPOName -Target "ou=$dep,ou=$global:Forest,dc=$global:Forest,dc=$global:ForestEnd"  -LinkEnabled Yes
        }#>
    }
}
