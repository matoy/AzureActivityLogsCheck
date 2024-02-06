using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

#####
#
# TT 20222803 AzureActivityLogsCheck
# This script is executed by an Azure Function App
# It checks if there are activity logs made by some people on resources of
# a given subscription.
#
# It can be triggered by any monitoring system to get the results and status
#
# "subscriptionid" GET parameter allows to specify the subscription to check
#
# "exclusionRg" GET parameter can be passed with comma separated resource group
# names that should be excluded from the check
#
# "exclusionOperation" GET parameter can be passed with comma separated
# operation names that should be excluded from the check
#
# used AAD credentials needs read access to the specified subscription
#
#
#####

$exclusionRg = [string] $Request.Query.exclusionRg
if (-not $exclusionRg) {
    $exclusionRg = ""
}
[System.Collections.ArrayList] $exclusionRgTab = $exclusionRg.split(",")
foreach ($current in ($env:AzureActivityLogsCheckRgGlobalExceptions).split(",")) {
	$exclusionRgTab.Add($current)
}

$exclusionOperation = [string] $Request.Query.exclusionOperation
if (-not $exclusionOperation) {
    $exclusionOperation = ""
}
[System.Collections.ArrayList] $exclusionOperationTab = $exclusionOperation.split(",")
foreach ($current in ($env:AzureActivityLogsCheckOperationGlobalExceptions).split(",")) {
	$exclusionOperationTab.Add($current)
}

$subscriptionid = [string] $Request.Query.Subscriptionid
if (-not $subscriptionid) {
    $subscriptionid = "00000000-0000-0000-0000-000000000000"
}

$numberOfDays = [int] $env:DaysToLookBack
$numberOfDaysUri = [string] $Request.Query.DaysToLookBack
if ($numberOfDaysUri) {
    $numberOfDays = $numberOfDaysUri
}

# init variables
$signature = $env:Signature

# connect with SPN account creds
$tenantId = $env:TenantId
$applicationId = $env:AzureActivityLogsCheckApplicationID
$password = $env:AzureActivityLogsCheckSecret
$securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $applicationId, $securePassword
Connect-AzAccount -Credential $credential -Tenant $tenantId -ServicePrincipal

# logs
Write-Host "tenantId: $tenantId`napplicationId: $applicationId`nsubscriptionid: $subscriptionid`nnumberOfDays: $numberOfDays`nexclusionRgTab: $exclusionRgTab`nexclusionOperationTab: $exclusionOperationTab"

# get token
$azContext = Get-AzContext
$azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
$profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
$token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)

# create http headers
$headers = @{}
$headers.Add("Authorization", "bearer " + "$($Token.Accesstoken)")
$headers.Add("contenttype", "application/json")

Try {
	$logs = @()
	$dateStart = (Get-Date).AddDays(-$numberOfDays).ToString("yyyy-MM-dd")
	$dateEnd = (Get-Date).ToString("yyyy-MM-dd")
	$filter = "eventTimestamp ge '$($dateStart)T00:00:00Z' and eventTimestamp le '$($dateEnd)T23:59:59Z' and status eq 'Succeeded'"
	$uri = "https://management.azure.com/subscriptions/$subscriptionid/providers/Microsoft.Insights/eventtypes/management/values?api-version=2015-04-01&`$filter=$filter"
	$results = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
	$logs += $results.value | where {$exclusionRgTab -notcontains $_.resourceGroupName -and $_.caller -like "*@*" -and $exclusionOperationTab -notcontains $_.operationName.value -and ($_.operationName.value -like "*write" -or $_.operationName.value -like "*delete")}
	while ($results.nextLink) {
			$uri = $results.nextLink
			$results = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
			$logs += $results.value | where {$exclusionRgTab -notcontains $_.resourceGroupName -and $_.caller -like "*@*" -and $exclusionOperationTab -notcontains $_.operationName.value -and ($_.operationName.value -like "*write" -or $_.operationName.value -like "*delete")}
	}
	if ($logs.count -eq 0) {
		$out = "OK - No manual activity log found`n"
	}
	else {
		$out = "CRITICAL - $($logs.count) activity log(s) found`n"
		foreach ($log in $logs) {
			$out += "--`nRG: $($log.resourceGroupName)`nResource: $($log.resourceid.split('/')[-1])`nCaller: $($log.caller)`nOperation: $($log.operationName.value)`nTimestamp: $($log.eventTimestamp)`n"
		}
	}
}
Catch {
    if($_.ErrorDetails.Message) {
		$out = "CRITICAL - $($_.ErrorDetails.Message)"
    }
}

# add signature
$body = $out + "$signature"
Write-Host $body

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
