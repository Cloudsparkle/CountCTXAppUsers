#requires -modules ActiveDirectory
<#
.SYNOPSIS
  Get a list of enabled published resources on Citrix CVAD, and counts the number of (enabled) AD users per application
.DESCRIPTION
  This script generates a CSV file with an inventory of published resources on Citrix CVAD, retrieves AD users and groups per application and counts the number of (enabled) AD accounts per application
.PARAMETER <Parameter_Name>
    None
.INPUTS
  None
.OUTPUTS
  CSV File
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  11/09/2020
  Purpose/Change: CVAD Application User Count Inventory
.EXAMPLE
  None
#>

if ((Get-PSSnapin "Citrix*" -EA silentlycontinue) -eq $null) 
    {
	try { Add-PSSnapin Citrix* -ErrorAction Stop }
	catch { write-error "Error loading XenApp Powershell snapin"; Return }
    }

#Variables to be customized
$CTXDDC = "nitcitddc1vp"
$CSVFile = "c:\temp\CTXAppInventory.csv"

#Initializing Script Variables
$csvContents = @() # Create the empty array that will eventually be the CSV file

#Get all Published Resources
$CTXApplications = Get-BrokerApplication -AdminAddress $CTXDDC

foreach ($CTXApp in $CTXApplications)
{
If ($CTXApp.Enabled -eq $True)
	{
	#Initializing
    $output=""
    $totalcount = 0

    #Get AD Users and groups of the published resource
    $accountlist = $CTXApp.AssociatedUserNames
    
	
    
	foreach ($account in $accountlist)
	    {
        $AppGroup = $null
        $IsADUser = $false

        $input = $account
        $domain,$ADName = $input.split('\')
        
        $output += ($ADName + ";")
                
        #Check if and AD Group or AD User has been used
        try {$AppGroup = Get-ADGroup $ADName }
	    catch { $IsADUser = $true }

        #$AppGroup = Get-ADGroup $ADName
        
        if ($IsADUser -eq $false)
            {
            #Initialize Counter
            $counter1 = 0

            $counter1 = (Get-ADGroupMember -Recursive -Identity $ADName |get-aduser|Where{$_.Enabled -eq $true}).count
         
            #Check if something was returned
            if ($counter1 -ne $null)
                {
                $totalcount += $counter1
                }
            }
        Else    
            {
            $AppUser = Get-ADUser $ADName
            write-host $AppUser
            if ($AppUSer.Enabled -eq $True)
                {
                $totalcount = $totalcount + 1
                }
            } 
 
        }

    #When running interactive, get some running output
    write-host $CTXAPP.ApplicationName, $output, $totalcount

    #Get the CSV data ready
	$row = New-Object System.Object # Create an object to append to the array
	$row | Add-Member -MemberType NoteProperty -Name "Application" -Value $CTXApp.Displayname
	$row | Add-Member -MemberType NoteProperty -Name "Accounts" -Value $output
	$row | Add-Member -MemberType NoteProperty -Name "Count" -Value $totalcount
	
	$csvContents += $row # append the new data to the array#
	}
}

#Write the CSV output
$csvContents | Export-CSV -path $CSVFile -NoTypeInformation