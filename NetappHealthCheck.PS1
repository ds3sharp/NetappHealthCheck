<#
Author...............Jeff Sharp  
Creation Date........1/11/2021

Description
=============================================================
This script collects health information of Netapp Clustered
ONTAP systems. 

In order to run the script, update the $ListLocation
variable with the fqdn / ip address of the netapp
clusters you want to check status on.

DataOntap module 9.6 or newer required

Modification Log
Date    | Initials | +/- | Description
============================================================
01/11/2021 | JGS      |  +  | Initial Draft
01/12/2021 | JGS      |  +  | Updated script after taking powershell scripting class


#>

#SETUP Global Variables
# None at this time

#Create a file with the IP or FQDN of Netapp Clusters - one per line
$ListLocation = "D:\NETAPP\filers.txt"

#Read the contents of the list into an array
$FilerList = Get-Content $ListLocation

#$Credential = Get-Credential
$password = ConvertTo-SecureString -AsPlainText -Force P@ssw0rd # Update this to whatever the password of the netapp cluster is. 
$credential = new-object management.automation.pscredential admin, $password
#Use $credential as the credential object to pass to the -Credential parameter in any cmdlet that supports this parameter.

#Show the currently connected controller(s)
#$global:CurrentNcController

#Disconnect from all controllers
#$global:CurrentNcController = $null

# 1. Import the netapp cmdlets - DataOntap Module can be downloaded from Netapp Support or Powershell Gallery
Import-Module DataOntap

foreach ($filer in $FilerList) {

Connect-NcController -name $filer -Credential $Credential -HTTPS | Out-Null #suppress the output to the screen with out-null

write-host "-----------------------------------------------------------------------------------------------"

#----------------Print the current date and time -----------------------------------------------------------------------------------------
$time = get-date | Select-Object DateTime
Write-Host -BackgroundColor Black -ForegroundColor Green "Date and Time:          ",$time.DateTime

#----------------Show Cluster information------------------------------------------------------------------------------------------------
$Cluster_Show = Get-NcCluster
Write-Host -BackgroundColor Black -ForegroundColor Green "Cluster:                ",$Cluster_Show.ClusterName,$Cluster_Show.NcController

$CLUSUptime = (get-ncnode).nodeuptime 
$TS = New-TimeSpan -Seconds $CLUSUptime
Write-Host -BackgroundColor Black -ForegroundColor Yellow "System Uptime:          ",$TS.Days"Days",$TS.Hours"Hours",$TS.Minutes "Minutes" 

# ------------------------ Check the node health ---------------------------------------------
$Health = Get-NcNode | Select-Object -Property Node,IsNodeHealthy
Write-Host "Node" $Health.Node "Is Healthy: " $Health.IsNodeHealthy
# ---------------------------------------------------------------------------------------------

# -------------  Display all Lifs that are not currently home ----------------------------------------------------------------------------

#Write-Host -BackgroundColor Black -ForegroundColor Green "Display all Lifs that are not currently home"

$LIF_Status = 
Get-NcNetInterface -Name * |
    Where-Object -Property IsHome -EQ $False | #boolean values are represented by $True, and $False
    Sort-Object -Property InterfaceName |
    Format-Table -Property InterfaceName, IsHome, CurrentNode 

if (!$LIF_Status) { #the exclamation point checks to see if the variable is blank
     Write-Host -BackgroundColor Black -ForegroundColor Green "ALL Lifs are currently home"
     }
Else {
     Write-Host -BackgroundColor Black -ForegroundColor Red "These LIFs are not home:"
     $LIF_Status
#Write-Host $(" "*$LIF_Status) -BackgroundColor White -ForegroundColor Red
#Write-Host -BackgroundColor Black -ForegroundColor Red $LIF_Status | Format-Table
     }

#-----------------------------------------------------------------------------------------------------------------------------------------

$DISKStatus = Get-NcDisk | ?{ $_.DiskRaidInfo.ContainerType -eq "broken" }

if (!$DISKStatus) {
     Write-Host -BackgroundColor Black -ForegroundColor Green "There are no Broken Disks"
     }
Else {
     Write-Host -BackgroundColor Black -ForegroundColor Red "These Disks are Broken:"
     $DISKStatus
     }

# --------------------------- Check for volumes above 80% --------------------------------------------------------------

$Volumes = Get-NcVol 

foreach ($vol in $Volumes) {

$volused = (Get-NcVol -Name $vol.Name).VolumeSpaceAttributes.PercentageSizeUsed

$volavail = (Get-NcVol -Name $vol.Name).VolumeSpaceAttributes.SizeAvailable
#$volavail = $volavail/1GB
#$volavail = [math]::Round($volavail,2)
$volavail = [math]::Round(($volavail/1GB),2)

#$volsnap = (Get-NcVol -Name VOL1).VolumeSpaceAttributes.SizeUsedBySnapshots
#$volsnap = [math]::Round(($volsnap/1GB),2)

if ($volused -gt 79) {
Write-Host -BackgroundColor Black -ForegroundColor Red "volume" $vol.Name "is" $volused "percent used" $volavail "GB available"
$bd = $bd + 1
}


}

if ($bd -lt 1) {
Write-Host -BackgroundColor Black -ForegroundColor Green "There are no volumes above 80%"
}

# -------------------------------------------------------------------------------------------------------------------------


# Check to see if the SIS log is full


# Get any alerts
Get-NcDiagnosisAlert

# Get the last 10 messages from the the event log
"`r`n" # Drop down a line for readability 

Write-Host -BackgroundColor Black -ForegroundColor Yellow "These are the most recent 10 errors"
Get-NcEmsMessage -Count 10 -Severity error

write-host "----------------------------------------------------------------------------------------------"
#End of Script 
}
