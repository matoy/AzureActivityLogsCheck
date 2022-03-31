# AzureActivityLogsCheck
  
## Why this function app ?
This function app automatically checks if you have users actions on Azure resources using activity logs API query on a given subscription.  
  
You can exclude specific resource group(s) and/or type of operations in activity logs.  

The purpose is to identify if anybody made MANUAL write or delete operations on your resources instead of going through IaC and CI/CD pipelines.

Coupled with a common monitoring system (nagios, centreon, zabbix, or whatever you use), you'll automatically get alerted as soon as a there is a modification made by user.  
</br>
</br>

## Requirements
* An "app registration" account (client id, valid secret and tenant id).  
* Reader RBAC role for this account on all subscriptions you want to monitor.  
</br>
</br>

## Installation
Once you have all the requirements, you can deploy the Azure function with de "Deploy" button below:  
  
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmatoy%2FAzureActivityLogsCheck%2Fmain%2Farm-template%2FAzureActivityLogsCheck.json) [![alt text](http://armviz.io/visualizebutton.png)](http://armviz.io/#/?load=https://raw.githubusercontent.com/matoy/AzureActivityLogsCheck/main/arm-template/AzureActivityLogsCheck.json)  
  
</br>
This will deploy an Azure app function with its storage account, app insights and "consumption" app plan.  
A keyvault will also be deployed to securely store the secret of your app principal.  
  
![alt text](https://github.com/matoy/AzureActivityLogsCheck/blob/main/img/screenshot1.png?raw=true)  
  
Choose you Azure subscription, region and create or select a resource group.  
  
* App Name:  
You can customize a name for resources that will be created.  
  
* Tenant ID:  
If your subscription depends on the same tenant than the account used to retrieve subscriptions information, then you can use the default value.  
Otherwise, enter the tenant ID of the account.  
  
* Subscription Reader Application ID:  
Client ID of the account used to retrieve subscriptions information.  
  
* Subscription Reader Secret:  
Secret of the account used to retrieve subscriptions information.  
   
* Zip Release URL:  
For testing, you can leave it like it.  
For more serious use, I would advise you host your own zip file so that you wouldn't be subject to release changes done in this repository.  
See below for more details.  
  
* Resource group exceptions:  
Resource group(s) you want to exclude from the check on a global basis. 
You can specify comma separated names.  
  
* Operation exceptions:  
Type of operation (in activity logs) you want to exclude from the check on a global basis. 
You can specify comma separated names.  

* Signature:  
When this function will be called by your monitoring system, you likely might forget about it.  
The signature output will act a reminder since you'll get it in the results to your monitoring system.  
  
</br>
When deployment is done, you can get your Azure function's URL in the output variables.  
  
Trigger it manually in your favorite browser and eventually look at the logs in the function.  
  
After you execute the function for the first time, it might (will) need 5-10 minutes before it works because it has to install Az module. You even might get an HTTP 500 error. Give the function some time to initialize, re-execute it again if necessary and be patient, it will work.  
  
Even after that, you might experience issue if Azure takes time to resolve your newly created keyvault:  
![alt text](https://github.com/matoy/AzureActivityLogsCheck/blob/main/img/kv-down.png?raw=true)  
Wait a short time and then restart your Azure function, your should have something like:  
![alt text](https://github.com/matoy/AzureActivityLogsCheck/blob/main/img/kv-up.png?raw=true)  
</br>
</br>

## Monitoring integration  
From there, you just have to call your function's URL from your monitoring system.  
  
You can find a script example in "monitoring-script-example" folder which makes a GET request, outputs the result, looks for "CRITICAL" or "WARNING" in the text and use the right exit code accordingly.  
  
Calling the function once a day should be enough.  
  
You have make 1 function call per subscription by specifying the subscriptionid in the GET parameters: &subscriptionid=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  
  
You can also specify comma separated resource names to exclude with &exclusions=vm1,snapshotXXX,nic-abcdef  
  
Be sure to have an appropriate timeout (30s or more) because if you have many resources, the function might need some time to execute.  
  
This is an example of what you'd get in Centreon:  
![alt text](https://github.com/matoy/AzureActivityLogsCheck/blob/main/img/screenshot2.png?raw=true)  
</br>
</br>

## How to stop relying on this repository's zip  
To make your function to stop relying on this repo's zip and become independant, follow these steps:  
* remove zipReleaseURL app setting and restart app  
* in "App files" section, edit "requirements.psd1" and uncomment the line: 'Az' = '7.*'  
* in "Functions" section, add a new function called "AzureActivityLogsCheck" and paste in it the content of the file release/AzureActivityLogsCheck/run.ps1 in this repository  
