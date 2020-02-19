# Active_Directory_Automations

Powershell automation scripts to setup the following servers in a Forest:
- AD_INIT: first Domain Controller
- AD_REP_INIT: Domain Controller Replication 
- FS_INIT:File Server

## Getting Started

each script works in 3 steps:
Step 1: 
1. Turning off Windows Firewall
2. Static IP Address Configuration
3. Change computer name to logical name 
4. Reboot & Continue to Step 2
Step 2:
1. Install  Serivces on server
2. Promote server process for new forest 
3. Reboot & Continue to Step 3
Step 3:
AD_INIT:
1. Create new OUs from CSV file 
2. Create Users & Groups from CSV file 
3. link user to group 
4. Init GPO policies 
AD_REP_INIT:
1. Install DHCP Services
2. Configure DHCP
FS_INIT:
1. Install FSRM Serivces
            
## Deployment

there are a few veriables that needs changes before running the scripts.
in `_setup_.ps1` it's important to give domain name value to variable ```$global:Forest``` 
end of domain to variable ```$global:ForestEnd``` and password to variable ```$global:defaultPassword```.
the variable ```$csvPath``` contain the path to users csv file.

in `run.ps1` the variable ```$newName``` will hold the new DC name.
```$newIp``` will hold the new static ip address.
```$defaultGate``` will hold the defualt gateway address.
```$cardName``` will hold the name of the network interface that in use.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
