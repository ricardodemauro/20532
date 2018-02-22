Import-Module -Name AzureRM

$subscriptionName = "AzurePass"

$rand = Get-Random

$defaultLocation = "eastus"
$defaultResourceGroup = "student$($rand)"
$defaultStorage = "stor20532lab$($rand)"
$defaultSku = "Standard_LRS"
$defaultContainer = "example"

$sqluser = "student"
$sqlpass = "AzurePa`$`$w0rd"
$sqlStartIP = "0.0.0.0"
$sqlEndIP = "255.255.255.255"
$sqlSvcName = "stor20532lab$($rand)"
$sqlDbName = "EventsContextModule7Lab"

$webname = "events$($rand)"

Function Init() {
    Login

    SelectSubscription

    $rg = CreateResoureGroup -name $defaultResourceGroup
    if($rg -eq $null) {
        return
    }
    $storage = CreateStorage -storageName $defaultStorage -resourceGroupName $defaultResourceGroup
    if($storage -eq $null) {
        return
    }
    CreateContainerStorage -containerName $defaultContainer -storageContext $storage.Context

    UploadSampleBlob -container $defaultContainer -blobContext $storage.Context

    CreateSqlServer -name $sqlSvcName -resourceGroup $defaultResourceGroup -dbName $sqlDbName

    CreateAppService -name $webname -resourceGroup $defaultResourceGroup

    UpdateSettings

    Write-Host -BackgroundColor Yellow -ForegroundColor Red "Done"
}

function Login
{
    $needLogin = $true
    Try 
    {
        $content = Get-AzureRmContext
        if ($content) 
        {
            $needLogin = ([string]::IsNullOrEmpty($content.Account))
        } 
    } 
    Catch 
    {
        if ($_ -like "*Login-AzureRmAccount to login*") 
        {
            $needLogin = $true
        } 
        else 
        {
            throw
        }
    }

    if ($needLogin)
    {
        Login-AzureRmAccount
    }
}

Function UpdateSettings() {
    Write-Host "------------------------------------------------------------------------------"
    Write-Host "Updating appsettings and connectionstrings for web apps created"

    $storageKeys = GetStorageAccessKey -name $defaultStorage -resourceGroup $defaultResourceGroup
    $storageZeroKey = $storageKeys[0].Value

    $dbConnStr = "Server=tcp:$($sqlSvcName).database.windows.net,1433;Initial Catalog=EventsContextModule7Lab;Persist Security Info=False;User ID=$($sqluser);Password=$($sqlpass);MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    Write-Host "Database ConnectionString: $($dbConnStr)"

    $accountName = $defaultStorage
    $storageConnString = "DefaultEndpointsProtocol=https;AccountName=$($defaultStorage);AccountKey=$($storageZeroKey);EndpointSuffix=core.windows.net"
    Write-Host "Storage ConnectionString: $($storageConnString)"
    Write-Host "------------------------------------------------------------------------------"
    
    $appSettings = @{}
    $appSettings["Microsoft.WindowsAzure.Storage.ConnectionString"] = $storageConnString

    $connectionStrings = @{}
    $connectionStrings["EventsContextConnectionString"] = $dbConnStr

    $evtName = "$($webname)"
    Write-Host "Updating settings from webapp $($evtName)"
    UpdateAppSettings -webAppName $evtName -resourceGroup $defaultResourceGroup -appSettings $appSettings -connectionStrings $connectionStrings

    $evtAdmName = "admin$($webname)"
    Write-Host "Updating settings from webapp $($evtAdmName)"
    UpdateAppSettings -webAppName $evtAdmName -resourceGroup $defaultResourceGroup -appSettings $appSettings -connectionStrings $connectionStrings
}

Function GetLocations() {
    Get-AzureRmLocation | select Location, DisplayName
}

Function SelectSubscription() {
    Write-Host -ForegroundColor Yellow -Object "Your subscriptions:"
    Get-AzureRmSubscription | select Name, Id
    
    $subscriptionId = Read-Host -Prompt 'Subscription to use'

    if($subscriptionId -eq "") {
        Write-Host -ForegroundColor Red -Object "None selected"
        return
    }
    Write-Host -Object "Selecting $($subName) - $($subscriptionId) subscription to work"
    Select-AzureRmSubscription -Subscription $subscriptionId
}

Function CreateStorage($storageName, $resourceGroupName) {
    Write-Host "creating storage account named $($storageName)"

    $st = Get-AzureRmStorageAccount -Name $storageName -ErrorAction Ignore -ResourceGroupName $resourceGroupName
    if($st -ne $null) {
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "INFO Storage account $($storageName) already exists."
        return $st
    }
    $storage = New-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -Name $storageName -Location $defaultLocation -Kind Storage -EnableHttpsTrafficOnly $true -SkuName $defaultSku
    return $storage
}

Function CreateContainerStorage($containerName, $storageContext) {
    $ct = Get-AzureStorageContainer -Name $containerName -Context $storageContext -ErrorAction Ignore
    if($ct -ne $null) {
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "INFO Container $($containerName) already exist."
        if($ct.Permission -ne [Microsoft.WindowsAzure.Storage.Blob.BlobContainerPublicAccessType]::Container) {
            
            Write-Host -ForegroundColor Yellow -BackgroundColor Black "Permissions of container are being updated"
            $ct = Set-AzureStorageContainerAcl -Name $containerName -Permission Container -PassThru -Context $storageContext
        }
        return $ct
    }
    $ct = New-AzureStorageContainer -Context $storageContext -Name $containerName -Permission Container
    return $ct
}

Function GetStorageAccessKey($name, $resourceGroup) {
    $keys = Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroup -Name $name
    return $keys
}

Function UploadSampleBlob($container, $blobContext) {
    Write-Host "Uploading the sample blob"
    Set-AzureStorageBlobContent -File "..\samplefile.txt" -Container $container -Blob "samplefile.txt" -Context $blobContext
}

Function CreateResoureGroup($name, $ignoreIfExist) {
    Write-Host -Object "creating resource group with name $($name)"

    $rg = Get-AzureRmResourceGroup -Name $name -ErrorAction Ignore
    if($rg -ne $null) {
        Write-Host -ForegroundColor Yellow -BackgroundColor Black -Object "INFO. Resource group already exist"
        return $rg
    }
    else {
        $rg = New-AzureRmResourceGroup -Name $name -Location $defaultLocation
    }
    return $rg
}

Function CreateSqlServer($name, $dbName, $resourceGroup) {
    $sqlSvc = Get-AzureRmSqlServer -ResourceGroupName $resourceGroup -ServerName $name -ErrorAction Ignore
    if($sqlSvc -eq $null) {
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "INFO SQL Server not found. Creating a new one with name $($name)"
        $sqlSvc = New-AzureRmSqlServer -ResourceGroupName $resourceGroup `
            -ServerName $name `
            -Location $defaultLocation `
            -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sqluser, $(ConvertTo-SecureString -String $sqlpass -AsPlainText -Force))
    }
    Write-Host "INFO Defining sql server firewall rules"
    New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourceGroup `
        -ServerName $name `
        -FirewallRuleName "AllowAll" -StartIpAddress $sqlStartIP -EndIpAddress $sqlEndIP

    $sqlDb = Get-AzureRmSqlDatabase -DatabaseName $dbName -ServerName $name -ResourceGroupName $resourceGroup -ErrorAction Ignore
    if($sqlDb -eq $null) {
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "INFO Sql Database not found in dbserver $($name). Creating a new one with name $($dbName)"
        $sqlDb = New-AzureRmSqlDatabase -ResourceGroupName $resourceGroup `
            -ServerName $name `
            -DatabaseName $dbName `
            -CollationName "SQL_Latin1_General_CP1_CI_AS" `
            -Edition Basic
    }
}

Function CreateAppService($name, $resourceGroup) {
    $planName = "plan$($name)"

    $svcPlan = Get-AzureRmAppServicePlan -Name $planName -ResourceGroupName $resourceGroup -ErrorAction Ignore
    if($svcPlan -eq $null) {
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "INFO Service plan not found. Creating a new one with name $($planName)"
        $svcPlan = New-AzureRmAppServicePlan -Name $planName `
            -Location $defaultLocation `
            -ResourceGroupName $resourceGroup `
            -Tier Free    
    }
    

    $evtName = "$($name)"
    $webAppEvts = Get-AzureRmWebApp -Name $evtName -ResourceGroupName $resourceGroup -ErrorAction Ignore
    if($webAppEvts -eq $null) {
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "INFO Events Web App not found. Creating a new one with name $($evtName)"
        $webAppEvts = New-AzureRmWebApp -Name $evtName `
            -Location $defaultLocation `
            -ResourceGroupName $resourceGroup `
            -AppServicePlan $planName
    }

    $evtAdmName = "admin$($name)"
    $webAppAdminEvts = Get-AzureRmWebApp -Name $evtAdmName -ResourceGroupName $resourceGroup -ErrorAction Ignore
    if($webAppAdminEvts -eq $null) {
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "INFO Admin Events Web App not found. Creating a new one with name $($evtAdmName)"
        $webAppAdminEvts = New-AzureRmWebApp -Name $evtAdmName `
            -Location $defaultLocation `
            -ResourceGroupName $resourceGroup `
            -AppServicePlan $planName
    }

    Write-Host "Downloading publish settings to local disk"
    $folder = Read-Host -Prompt 'Folder path'
    $pub1 = "$($folder.TrimEnd('\'))\events.publishsettings"
    Get-AzureRmWebAppPublishingProfile -OutputFile $pub1 -Format WebDeploy -ResourceGroupName $resourceGroup -Name $evtName  | Out-Null

    $pub2 = "$($folder.TrimEnd('\'))\adminEvents.publishsettings"
    Get-AzureRmWebAppPublishingProfile -OutputFile $pub2 -Format WebDeploy -ResourceGroupName $resourceGroup -Name $evtAdmName | Out-Null
}

Function UpdateAppSettings($webAppName, $resourceGroup, $appSettings, $connectionStrings) {
    $webApp = Get-AzureRmWebApp -ResourceGroupName $resourceGroup -Name $webAppName
    $webAppSettings = $webApp.SiteConfig.AppSettings

    $appSettingsHash = @{}
    foreach($setting in $webAppSettings) {
        $appSettingsHash[$setting.Name] = $setting.Value
    }

    foreach($aKey in $appSettings.Keys) {
        Write-Host -ForegroundColor Gray -BackgroundColor Black "$($aKey) Value $($appSettings[$aKey])"

        $appSettingsHash[$aKey] = $appSettings[$aKey]
    }

    $connectionStrings = @{ EventsContextConnectionString = @{ Type = "SQLAzure"; Value=$connectionStrings["EventsContextConnectionString"]}}
    
    Set-AzureRmWebApp -ResourceGroupName $resourceGroup -Name $webAppName -AppSettings $appSettingsHash -PhpVersion Off -ConnectionStrings $connectionStrings
}

Init