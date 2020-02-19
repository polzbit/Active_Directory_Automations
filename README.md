# Active_Directory_Automations

Powershell automation scripts to setup the following servers in a Forest:
- AD_INIT: first Domain Controller
- AD_REP_INIT: Domain Controller Replication 
- FS_INIT:File Server

## Getting Started

each script works in 3 steps:
        Step 1: 
            a. Turning off Windows Firewall
            b. Static IP Address Configuration
            c. Change computer name to logical name 
            d. Reboot & Continue to Step 2
        Step 2:
            a. Install  Serivces on server
            b. Promote server process for new forest 
            c. Reboot & Continue to Step 3
        Step 3:
            AD_INIT:
              a. Create new OUs from CSV file 
              b. Create Users & Groups from CSV file 
              c. link user to group 
              d. Init GPO policies 
              
            AD_REP_INIT:
              a. Install DHCP Services
              b. Configure DHCP
              
            FS_INIT:
              a. Install FSRM Serivces
            
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
