$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "I accept the license agreement."
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "I do not accept and wish to stop execution."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$title = "Agreement"
$message = "By typing [Y], I hereby confirm that I have read the license ( available at https://github.com/microsoft/Azure-Analytics-and-AI-Engagement/blob/main/license.md ) and disclaimers ( available at https://github.com/microsoft/Azure-Analytics-and-AI-Engagement/blob/main/README.md ) and hereby accept the terms of the license and agree that the terms and conditions set forth therein govern my use of the code made available hereunder. (Type [Y] for Yes or [N] for No and press enter)"
$result = $host.ui.PromptForChoice($title, $message, $options, 1)

if ($result -eq 1) {
    Write-Host "Thank you. Please ensure you delete the resources created with template to avoid further cost implications."
}
else {
    function RefreshTokens() {
        # Copy external blob content
        $global:powerbitoken = ((az account get-access-token --resource https://analysis.windows.net/powerbi/api) | ConvertFrom-Json).accessToken
        $global:synapseToken = ((az account get-access-token --resource https://dev.azuresynapse.net) | ConvertFrom-Json).accessToken
        $global:graphToken = ((az account get-access-token --resource https://graph.microsoft.com) | ConvertFrom-Json).accessToken
        $global:managementToken = ((az account get-access-token --resource https://management.azure.com) | ConvertFrom-Json).accessToken
        $global:purviewToken = ((az account get-access-token --resource https://purview.azure.net) | ConvertFrom-Json).accessToken
        $global:fabric = ((az account get-access-token --resource https://api.fabric.microsoft.com) | ConvertFrom-Json).accessToken
    }

    function Check-HttpRedirect($uri) {
        $httpReq = [system.net.HttpWebRequest]::Create($uri)
        $httpReq.Accept = "text/html, application/xhtml+xml, */*"
        $httpReq.method = "GET"
        $httpReq.AllowAutoRedirect = $false;

        # use them all...
        # [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Ssl3 -bor [System.Net.SecurityProtocolType]::Tls;

        $global:httpCode = -1;
        $response = "";

        try {
            $res = $httpReq.GetResponse();

            $statusCode = $res.StatusCode.ToString();
            $global:httpCode = [int]$res.StatusCode;
            $cookieC = $res.Cookies;
            $resHeaders = $res.Headers;
            $global:rescontentLength = $res.ContentLength;
            $global:location = $null;

            try {
                $global:location = $res.Headers["Location"].ToString();
                return $global:location;
            }
            catch {
            }

            return $null;
        }
        catch {
            $res2 = $_.Exception.InnerException.Response;
            $global:httpCode = $_.Exception.InnerException.HResult;
            $global:httperror = $_.exception.message;

            try {
                $global:location = $res2.Headers["Location"].ToString();
                return $global:location;
            }
            catch {
            }
        }

        return $null;
    }

    function ReplaceTokensInFile($ht, $filePath) {
        $template = Get-Content -Raw -Path $filePath

        foreach ($paramName in $ht.Keys) {
            $template = $template.Replace($paramName, $ht[$paramName])
        }

        return $template;
    }
}


Write-Host "------------Prerequisites------------"
Write-Host "-An Azure Account with the ability to create Fabric Workspace."
Write-Host "-A Power BI with Fabric License to host Power BI reports."
Write-Host "-Make sure the user deploying the script has atleast a 'Contributor' level of access on the 'Subscription' on which it is being deployed."
Write-Host "-Make sure your Power BI administrator can provide service principal access on your Power BI tenant."
Write-Host "-Make sure to register the following resource providers with your Azure Subscription:"
Write-Host "-Microsoft.StorageAccount"

Write-Host "-Make sure you use the same valid credentials to log into Azure and Power BI."

Write-Host "    -----------------   "
Write-Host "    -----------------   "
Write-Host "If you fulfill the above requirements please proceed otherwise press 'Ctrl+C' to end script execution."
Write-Host "    -----------------   "
Write-Host "    -----------------   "

Start-Sleep -s 10

az login

$subscriptionId = (az account show --query 'id' -o tsv)
 
#for powershell...
Connect-AzAccount -DeviceCode -SubscriptionId $subscriptionId

# $starttime = get-date

# $response = az ad signed-in-user show | ConvertFrom-Json
# $date = get-date
# $demoType = "Ignite-25"
# $body = '{"demoType":"#demoType#","userPrincipalName":"#userPrincipalName#","displayName":"#displayName#","companyName":"#companyName#","mail":"#mail#","date":"#date#"}'
# $body = $body.Replace("#userPrincipalName#", $response.userPrincipalName)
# $body = $body.Replace("#displayName#", $response.displayName)
# $body = $body.Replace("#companyName#", $response.companyName)
# $body = $body.Replace("#mail#", $response.mail)
# $body = $body.Replace("#date#", $date)
# $body = $body.Replace("#demoType#", $demoType)

# $uri = "https://registerddibuser.azurewebsites.net/api/registeruser?code=pTrmFDqp25iVSxrJ/ykJ5l0xeTOg5nxio9MjZedaXwiEH8oh3NeqMg=="
# $result = Invoke-RestMethod  -Uri $uri -Method POST -Body $body -Headers @{} -ContentType "application/json"

$starttime = get-date
#download azcopy command
if ([System.Environment]::OSVersion.Platform -eq "Unix") {
    $azCopyLink = Check-HttpRedirect "https://aka.ms/downloadazcopy-v10-linux"

    if (!$azCopyLink) {
        $azCopyLink = "https://azcopyvnext.azureedge.net/release20200709/azcopy_linux_amd64_10.5.0.tar.gz"
    }

    Invoke-WebRequest $azCopyLink -OutFile "azCopy.tar.gz"
    tar -xf "azCopy.tar.gz"
    $azCopyCommand = (Get-ChildItem -Path ".\" -Recurse azcopy).Directory.FullName

    if ($azCopyCommand.count -gt 1) {
        $azCopyCommand = $azCopyCommand[0];
    }

    cd $azCopyCommand
    chmod +x azcopy
    cd ..
    $azCopyCommand += "\azcopy"
}
else {
    $azCopyLink = Check-HttpRedirect "https://aka.ms/downloadazcopy-v10-windows"

    if (!$azCopyLink) {
        $azCopyLink = "https://azcopyvnext.azureedge.net/release20200501/azcopy_windows_amd64_10.4.3.zip"
    }

    Invoke-WebRequest $azCopyLink -OutFile "azCopy.zip"
    Expand-Archive "azCopy.zip" -DestinationPath ".\" -Force
    $azCopyCommand = (Get-ChildItem -Path ".\" -Recurse azcopy.exe).Directory.FullName

    if ($azCopyCommand.count -gt 1) {
        $azCopyCommand = $azCopyCommand[0];
    }

    $azCopyCommand += "\azcopy"
}

$tenantId = (Get-AzContext).Tenant.Id
& $azCopyCommand login --tenant-id $tenantId

Start-Transcript -Path ./log.txt
$subscriptionId = (Get-AzContext).Subscription.Id
$signedinusername = az ad signed-in-user show | ConvertFrom-Json
$signedinusername = $signedinusername.userPrincipalName


[string]$suffix = -join ((48..57) + (97..122) | Get-Random -Count 7 | % { [char]$_ })
$rgName = "rg-ignite-25-$suffix"
$Region = read-host "Enter the region for deployment"
$subscriptionId = (Get-AzContext).Subscription.Id
$tenantId = (Get-AzContext).Tenant.Id
$databricks_workspace_name = "adb-fabric-$suffix"
$databricks_managed_resource_group_name = "rg-managed-adb-$suffix"
$userAssignedIdentities_ami_databricks_build = "ami-databricks-$suffix"
$dbdataLakeAccountName = "stigniteadb$suffix"
$keyVaultName = "kv-adb-$suffix"
$location_1 = read-host "Enter the location for OpenAI with gpt-4 "
$openAIResource = "openAIResource$suffix"
$aiServicesName = "AIhub-$suffix"

Write-Host "Deploying Resources on Microsoft Azure Started ..."
Write-Host "Creating $rgName resource group in $Region ..."
New-AzResourceGroup -Name $rgName -Location $Region | Out-Null
Write-Host "Resource group $rgName creation COMPLETE"
    
Write-Host "Creating resources in $rgName..."
New-AzResourceGroupDeployment -ResourceGroupName $rgName `
    -TemplateFile "mainTemplate.json" `
    -Mode Complete `
    -location $Region `
    -databricks_workspace_name $databricks_workspace_name `
    -databricks_managed_resource_group_name $databricks_managed_resource_group_name `
    -userAssignedIdentities_ami_databricks_build $userAssignedIdentities_ami_databricks_build `
    -datalake_account_name $dbdataLakeAccountName `
    -vaults_kv_databricks_prod_name $keyVaultName `
    -aiServicesName $aiServicesName `
    -azure_open_ai $openAIResource `
    -openAI_location_1 $location_1 `
    -Force
    
$templatedeployment = Get-AzResourceGroupDeployment -Name "mainTemplate" -ResourceGroupName $rgName
$deploymentStatus = $templatedeployment.ProvisioningState
Write-Host "Deployment in $rgName : $deploymentStatus"

# Write-Host "deploying OpenAI models gpt-4 in $openAIResource ..."
# $openAIModel1 = az cognitiveservices account deployment create -g $rgName -n $openAIResource --deployment-name "gpt-4" --model-name "gpt-4" --model-version "turbo-2024-04-09" --model-format OpenAI --sku-capacity 120 --sku-name "GlobalStandard"


Write-Host "---------AZURE DATABRICKS---------"
Write-Host "---Deploying Resources on Azure Databricks..."
$dbswsId = $(az resource show `
        --resource-type Microsoft.Databricks/workspaces `
        -g "$rgName" `
        -n "$databricks_workspace_name" `
        --query id -o tsv)

$dbsId = $(az resource show `
        --resource-type Microsoft.Databricks/workspaces `
        -g "$rgName" `
        -n "$databricks_workspace_name" `
        --query properties.workspaceId -o tsv)

$workspaceUrl = $(az resource show `
        --resource-type Microsoft.Databricks/workspaces `
        -g "$rgName" `
        -n "$databricks_workspace_name" `
        --query properties.workspaceUrl -o tsv)

# Get a token for the global Databricks application.
# The resource ID is fixed and never changes.
$token_response = $(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --output json) | ConvertFrom-Json
$token = $token_response.accessToken

# Get a token for the Azure management API
$token_response = $(az account get-access-token --resource https://management.core.windows.net/ --output json) | ConvertFrom-Json
$azToken = $token_response.accessToken

$uri = "https://$($workspaceUrl)/api/2.0/token/create"
$baseUrl = 'https://' + $workspaceUrl
# You can also generate a PAT token. Note the quota limit of 600 tokens.
$body = '{"lifetime_seconds": 1000000, "comment": "catalog" }';
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer $token")
$headers.Add("X-Databricks-Azure-SP-Management-Token", "$azToken")
$headers.Add("X-Databricks-Azure-Workspace-Resource-Id", "$dbswsId")
$pat_token = Invoke-RestMethod -Uri $uri -Method Post -Body $body -Header $headers 
$pat_token = $pat_token.token_value

$pattokenvalidation = if ($pat_token -ne $null) { "Pat token created" }Else { "Failed to create pat token" }
write-host $pattokenvalidation

$requestHeaders = @{
    Authorization  = "Bearer" + " " + $pat_token
    "Content-Type" = "application/json"
}

##Analytics with ADB

$body = '{
  "path": "/Workspace/Shared/Analytics with ADB"
}'

$endPoint = $baseURL + "/api/2.0/workspace/mkdirs"
$volume = Invoke-RestMethod $endPoint `
    -Method Post `
    -Headers $requestHeaders `
    -Body $body

Write-Host "Directory created successfully in shared folder."
Start-Sleep -Seconds 5
#uploading Notebooks
Write-Host "Uploading Notebooks in shared folder..."
$files = Get-ChildItem -path "artifacts/databricks"  -File -Recurse  #all files uploaded in one folder change config paths in python jobs
Set-Location "./artifacts/databricks"
foreach ($file in $files) {
    if ($file.Name -eq "01.1-DLT-fraud-detection-SQL.ipynb") {
        $fileContent = Get-Content -Raw $file.FullName
        $fileContentBytes = [System.Text.Encoding]::UTF8.GetBytes($fileContent)
        $fileContentEncoded = [System.Convert]::ToBase64String($fileContentBytes)

        # Extract the name without extension
        $nameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $body = '{"content": "' + $fileContentEncoded + '",  "path": "/Workspace/Shared/Analytics with ADB/' + $nameWithoutExtension + '",  "language": "PYTHON","overwrite": true,  "format": "JUPYTER"}'
        #get job list
        $endPoint = $baseURL + "/api/2.0/workspace/import"
        $result = Invoke-RestMethod $endPoint `
            -ContentType 'application/json' `
            -Method Post `
            -Headers $requestHeaders `
            -Body $body
    }
}
Set-Location ../../

###Azure Databricks End here##

