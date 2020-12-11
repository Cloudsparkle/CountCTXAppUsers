#requires -modules ActiveDirectory
<#
.SYNOPSIS
  Get a list of enabled published resources on XenApp 6.5, and counts the number of enabled AD users per application
.DESCRIPTION
  This script generates a CSV file with an inventory of published resources on XenApp 6.5, retrieves AD users and groups per application and counts the number of enabled AD accounts per application
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
  Purpose/Change: XenApp 6.5 Application User Count Inventory
.EXAMPLE
  None
#>

#Try loading Citrix Powershell modules, exit when failed
if ((Get-PSSnapin "Citrix.XenApp.Commands" -EA silentlycontinue) -eq $null)
  {
	try {Add-PSSnapin Citrix* -ErrorAction Stop }
	catch {Write-error "Error loading XenApp Powershell snapin"; Return }
  }

#Variables to be customized
$XenAppZDC = "" #Choose any Zone Data Collector
$CSVFile = "c:\temp\CTXAppInventory.csv"

#Initializing Script Variables
$csvContents = @() # Create the empty array that will eventually be the CSV file

#Connect to a XenApp Zone Data Collector
Set-XADefaultComputerName -Scope CurrentUser -ComputerName $XenAppZDC

#Get all Published Resources
$CTXApplications = Get-XAApplication

Foreach ($CTXApp in $CTXApplications)
{
  If ($CTXApp.Enabled -eq $True)
	{
    #Initializing
    $output=""
    $totalcount = 0

    #Get AD Users and groups of the published resource
    $Appaccounts = Get-XAApplicationReport -Browsername $CTXApp.Browsername | select Accounts
    $Accountlist = $Appaccounts.accounts

    foreach ($account in $accountlist)
    {
      $output = $output + ";" + $account

      #If an AD Group is used, count all enabled AD user accounts
      #If an AD User is used, check if enabled, and count if so
      
      if ($account.AccountType -eq "Group")
      {
        $groupmembers = (Get-ADGroupMember -Recursive -Identity $account.AccountName)
        Foreach ($groupmember in $groupmembers)
        {
          $groupuser = get-aduser -Identity $groupmember.SamAccountName
          if ($groupuser.enabled -eq $true)
          {
            $totalcount = $totalcount + 1
          }
        }
      }
      Else
      {
        $ADUSer = get-aduser -Identity $account.AccountName
        if ($ADUSer.Enabled -eq $True)
        {
          $totalcount = $totalcount + 1
        }
      }

    }

    #When running interactive, get some running output
    #write-host $CTXApp.Browsername, $accountlist, $totalcount

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
