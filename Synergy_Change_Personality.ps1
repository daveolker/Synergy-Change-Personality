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


function Add_Remote_Enclosures
{
    Write-Output "Adding Remote Enclosures" | Timestamp
    Send-HPOVRequest -uri "/rest/enclosures" -method POST -body @{'hostname' = 'fe80::2:0:9:7%eth2'} | Wait-HPOVTaskComplete
    Write-Output "Remote Enclosures Added" | Timestamp
}


function Configure_SAN_Managers
{
    Write-Output "Configuring SAN Managers" | Timestamp
    Add-HPOVSanManager -Hostname 172.18.20.1 -SnmpUserName dcs-SHA-AES128 -SnmpAuthLevel AuthAndPriv -SnmpAuthPassword hpinvent! -SnmpAuthProtocol sha -SnmpPrivPassword hpinvent! -SnmpPrivProtocol aes-128 -Type Cisco -Port 161 | Wait-HPOVTaskComplete
    Add-HPOVSanManager -Hostname 172.18.20.2 -SnmpUserName dcs-SHA-AES128 -SnmpAuthLevel AuthAndPriv -SnmpAuthPassword hpinvent! -SnmpAuthProtocol sha -SnmpPrivPassword hpinvent! -SnmpPrivProtocol aes-128 -Type Cisco -Port 161 | Wait-HPOVTaskComplete
    Write-Output "SAN Manager Configuration Complete" | Timestamp
}


function Configure_Networks
{
    ##########################################################################
    #
    # Process variables in the Populate_HPE_Synergy-Params.txt file.
    #
    ##########################################################################
    New-Variable -Name config_file -Value .\Populate_HPE_Synergy-Params.txt

    if (Test-Path $config_file) {    
        Get-Content $config_file | Where-Object { !$_.StartsWith("#") } | Foreach-Object {
            $var = $_.Split('=')
            New-Variable -Name $var[0] -Value $var[1]
        }
    } else { 
        Write-Output "Configuration file '$config_file' not found.  Exiting." | Timestamp
        Exit
    }
    
    Write-Output "Adding IPv4 Subnets" | Timestamp
    New-HPOVAddressPoolSubnet -Domain "mgmt.lan" -Gateway $prod_gateway -NetworkId $prod_subnet -SubnetMask $prod_mask
    New-HPOVAddressPoolSubnet -Domain "deployment.lan" -Gateway $deploy_gateway -NetworkId $deploy_subnet -SubnetMask $deploy_mask
    
    Write-Output "Adding IPv4 Address Pool Ranges" | Timestamp
    Get-HPOVAddressPoolSubnet -NetworkId $prod_subnet | New-HPOVAddressPoolRange -Name Mgmt -Start $prod_pool_start -End $prod_pool_end
    Get-HPOVAddressPoolSubnet -NetworkId $deploy_subnet | New-HPOVAddressPoolRange -Name Deployment -Start $deploy_pool_start -End $deploy_pool_end
    
    Write-Output "Adding Networks" | Timestamp
    New-HPOVNetwork -Name "ESX Mgmt" -MaximumBandwidth 20000 -Purpose Management -Type Ethernet -TypicalBandwidth 2500 -VlanId 1131 -VLANType Tagged
    New-HPOVNetwork -Name "ESX vMotion" -MaximumBandwidth 20000 -Purpose VMMigration -Type Ethernet -TypicalBandwidth 2500 -VlanId 1132 -VLANType Tagged
    New-HPOVNetwork -Name Prod_1101 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1101 -VLANType Tagged
    New-HPOVNetwork -Name Prod_1102 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1102 -VLANType Tagged
    New-HPOVNetwork -Name Prod_1103 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1103 -VLANType Tagged
    New-HPOVNetwork -Name Prod_1104 -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1104 -VLANType Tagged
    New-HPOVNetwork -Name Deployment -MaximumBandwidth 20000 -Purpose General -Type Ethernet -TypicalBandwidth 2500 -VlanId 1500 -VLANType Tagged
    Set-HPOVNetwork -InputObject Deployment -IPv4Subnet $deploy_subnet
    New-HPOVNetwork -Name Mgmt -MaximumBandwidth 20000 -Purpose Management -Type Ethernet -TypicalBandwidth 2500 -VlanId 100 -VLANType Tagged
    Set-HPOVNetwork -InputObject Mgmt -IPv4Subnet $prod_subnet
    New-HPOVNetwork -Name "SAN A FC" -Type "Fibre Channel" -FabricType FabricAttach -LinkStabilityTime 30 -ManagedSan VSAN20 -MaximumBandwidth 20000 -TypicalBandwidth 8000
    New-HPOVNetwork -Name "SAN B FC" -Type "Fibre Channel" -FabricType FabricAttach -LinkStabilityTime 30 -ManagedSan VSAN21 -MaximumBandwidth 20000 -TypicalBandwidth 8000
    New-HPOVNetwork -Name "SAN A FCoE" -VlanId 10 -ManagedSan VSAN10 -MaximumBandwidth 20000 -Type FCoE -TypicalBandwidth 8000
    New-HPOVNetwork -Name "SAN B FCoE" -VlanId 11 -ManagedSan VSAN11 -MaximumBandwidth 20000 -Type FCoE -TypicalBandwidth 8000
    
    Write-Output "Adding Network Sets" | Timestamp
    New-HPOVNetworkSet -Name Prod -Networks Prod_1101, Prod_1102, Prod_1103, Prod_1104 -MaximumBandwidth 20000 -TypicalBandwidth 2500
    
    Write-Output "Networking Configuration Complete" | Timestamp
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
        Write-Output "Login to Synergy Appliance failed.  Exiting."
        Exit
    } 
    else {
        Import-HPOVSslCertificate
    }
}

filter Timestamp {"$(Get-Date -Format G): $_"}

Write-Output "Configuring HPE Synergy Appliance" | Timestamp

Add_Firmware_Bundle


Write-Output "HPE Synergy Appliance Configuration Complete" | Timestamp
