##############################################################################
# Synergy_Change_Personality.ps1
#
#   Change the "personality" or Server Profile associated 
#   with a Synergy Compute Module
#
#   VERSION 1.0
#
#   AUTHORS
#   Dave Olker - HPE Global Solutions Engineering (BEST)
#
# (C) Copyright 2017 Hewlett Packard Enterprise Development LP 
##############################################################################
<#
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>


[CmdletBinding()]
param
(
    [Parameter (Mandatory, HelpMessage = "Provide the IP Address of the Synergy Composer.")]
    [ValidateNotNullorEmpty()]
    [IPAddress]$Appliance,
    
    [Parameter (Mandatory, HelpMessage = "Provide the Administrator Username.")]
    [ValidateNotNullorEmpty()]
    [String]$Username,
    
    [Parameter (Mandatory, HelpMessage = "Provide the Administrator's Password.")]
    [ValidateNotNullorEmpty()]
    [SecureString]$Password,
    
    [Parameter (Mandatory, HelpMessage = "Provide the Source Server Profile Name.")]
    [ValidateNotNullorEmpty()]
    [String]$SourceProfile,
    
    [Parameter (Mandatory, HelpMessage = "Provide the Target Server Profile Name.")]
    [ValidateNotNullorEmpty()]
    [String]$TargetProfile
)


function PowerOff_Compute_Module
{
    Write-Output "Powering OFF Compute Module Located at '$Location'" | Timestamp
    Get-HPOVServer -Name "$Location" | Stop-HPOVServer -Confirm:$false | Wait-HPOVTaskComplete
    Write-Output "Compute Module '$Location' Powered OFF" | Timestamp
}


function Unassign_Source_Server_Profile
{
    Write-Output "Unassigning Server Profile '$SourceProfile'" | Timestamp
    Get-HPOVServerProfile -Name "$SourceProfile" | New-HPOVServerProfileAssign -Unassigned | Wait-HPOVTaskComplete
    Write-Output "Server Profile '$SourceProfile' Unassigned" | Timestamp
    #
    # Sleep for 10 seconds to allow compute module to quiesce
    #
    Start-Sleep 10
}


function Assign_Target_Server_Profile
{
    Write-Output "Assigning Server Profile '$TargetProfile'" | Timestamp
    Get-HPOVServerProfile -Name "$TargetProfile" | New-HPOVServerProfileAssign -Server "$Location" -ApplianceConnection $ApplianceConnection | Wait-HPOVTaskComplete
    Write-Output "Server Profile '$TargetProfile' Assigned" | Timestamp
}


function PowerOn_Compute_Module
{
    Write-Output "Powering ON Compute Module Located at '$Location'" | Timestamp
    Get-HPOVServer -Name "$Location" | Start-HPOVServer | Wait-HPOVTaskComplete
    Write-Output "Compute Module '$Location' Powered ON" | Timestamp
}


##############################################################################
#
# Main Program
#
##############################################################################

if (-not (get-module HPOneview.300)) 
{
    Import-Module HPOneView.300
}

if (-not $ConnectedSessions) 
{
	$ApplianceConnection = Connect-HPOVMgmt -Hostname $Appliance -Username $Username -Password $Password

    if (-not $ConnectedSessions)
    {
        Write-Output "Login to the Synergy Composer failed.  Exiting."
        Exit
    } 
    else {
        Import-HPOVSslCertificate
    }
}

filter Timestamp {"$(Get-Date -Format G): $_"}

Write-Output "HPE Synergy Compute Module Personality Change Beginning..." | Timestamp

#
# Identify the Synergy Compute Module based on the Source Server Profile
#
$Profile = Get-HPOVServerProfile -Name $SourceProfile
$Enc = Send-HPOVRequest -uri $Profile.enclosureUri -method GET
$EncBay = $Profile.enclosureBay
$EncName = $Enc.name
$Location = "$EncName, bay $EncBay"

PowerOff_Compute_Module
Unassign_Source_Server_Profile
Assign_Target_Server_Profile
PowerOn_Compute_Module

Write-Output "HPE Synergy Compute Module Personality Change Complete" | Timestamp
