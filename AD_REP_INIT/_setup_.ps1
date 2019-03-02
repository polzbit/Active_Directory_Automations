<#######################################################################################################################
Title: Automation Process for Replication of Domain Controller in a Forest
Description: 
    a set of Powershell functions for replication DC automation, uses a registry key to continue the script after reboot
    - Function globals for registry
    - Utility functions to help Setup functions
    - Setup functions for reboot & continue
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