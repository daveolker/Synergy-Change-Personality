# Synergy Change Personality
Change the "personality" or Server Profile assigned to a Synergy Compute Module, allowing for different workloads to be scheduled at different times of the day, week, month.

## Synergy_Change_Personality.ps1
The Synergy_Change_Personality script does the following:

* Connects to an HPE Synergy Composer (or HPE OneView instance)
* Identifies the target compute module based on the "Source Server Profile" parameter
* Gracefully powers off the compute module
* Unassigns the existing Server Profile from the Compute Module
* Assigns the new Server Profile to the same Compute Module
* Powers on the compute module

The required parameters on the command-line are:
```
Appliance              IPv4 Address of the Synergy Composer or OneView Instance
Username               Administative User (Administrator)
SourceProfile          Server Profile currently assigned to Compute Module
TargetProfile          Server Profile desired to be assigned to Compute Module

The script will prompt for the Administrator's Password (not displayed in clear text)
```

# How to use the scripts
This PowerShell script requires the HPE OneView PowerShell library found here: https://github.com/HewlettPackard/POSH-HPOneView.

# Sample Command Syntax
> Synergy_Change_Personality.ps1 -Appliance <IP ADDR> -Username Administrator -SourceProfile ESX_Server -TargetProfile Windows_Server
