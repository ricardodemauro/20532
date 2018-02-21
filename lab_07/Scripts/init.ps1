Import-Module -Name AzureRM

$subscriptionName = "AzurePass"

$defaultLocation = "eastus"
$defaultResourceGroup = "student"
$defaultStorage = "stor20532instrutor"
$defaultSku = "Standard_LRS"
$defaultContainer = "example"

Function Init() {
    $rg = CreateResoureGroup -name $defaultResourceGroup
    if($rg -eq $null) {
        return
    }
    $storage = CreateStorage -storageName $defaultStorage -resourceGroupName $defaultResourceGroup
    if($storage -eq $null) {
        return
    }
    CreateContainerStorage -containerName $defaultContainer -storageContext $storage.Context

    $storageKeys = GetStorageAccessKey -storage $storage
    write-host -Object "These are the keys of storage account $($storage.Name)"
    write-host -Object "Key 0 $($keys[0].Value)"
    write-host -Object "Key 1 $($keys[1].Value)"

    UploadSampleBlob -container $defaultContainer -blobContext $storage.Context
}

Function GetLocations() {
    Get-AzureRmLocation | select Location, DisplayName
}

Function LoginAndSelectSubscription($subName) {
    Write-Host -NoNewline -ForegroundColor Yellow -Object "Your subscriptions"
    
    $sub = Get-AzureRmSubscription | select Name, Id
    
    $subscriptionId = ""

    foreach($s in $sub) {
        Write-Host -Object $s.Name
        if($s.Name -eq $subName) {
            $subscriptionId = $s.Id
        }
    }
    if($subscriptionId -eq "") {
        Write-Host -ForegroundColor Red -Object "Subscription not found"
        return
    }
    Write-Host -Object "Selecting $($subName) - $($subscriptionId) subscription to work"
    Select-AzureRmSubscription -Subscription
}

Function CreateStorage($storageName, $resourceGroupName) {
    Write-Host "creating storage account named $($storageName)"

    $st = Get-AzureRmStorageAccount -Name $storageName -ErrorAction Ignore -ResourceGroupName $resourceGroupName
    if($st -ne $null) {
        Write-Host -ForegroundColor Red -Object "Warning. Storage account $($storageName) already exists."
        return $st
    }
    $storage = New-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -Name $storageName -Location $defaultLocation -Kind Storage -EnableHttpsTrafficOnly $true -SkuName $defaultSku
    return $storage
}

Function CreateContainerStorage($containerName, $storageContext) {
    $ct = Get-AzureStorageContainer -Name $containerName -Context $storageContext
    if($ct -ne $null) {
        Write-Host -ForegroundColor Red -Object "Warning. Container already $($containerName) exist."
        if($ct.Permission -ne [Microsoft.WindowsAzure.Storage.Blob.BlobContainerPublicAccessType]::Container) {
            
            Write-Host -ForegroundColor Yellow -Object "Permissions of container are being updated"
            $ct = Set-AzureStorageContainerAcl -Name $containerName -Permission Container -PassThru -Context $storageContext
        }
        return $ct
    }
    $ct = New-AzureStorageContainer -Context $storageContext -Name $containerName -Permission Container
    return $ct
}

Function GetStorageAccessKey($storage) {
    $keys = $storage | Get-AzureRmStorageAccountKey
    return $keys
}

Function UploadSampleBlob($container, $blobContext) {
    Write-Host "Uploading sample blob"
    Set-AzureStorageBlobContent -File "..\samplefile.txt" -Container $container -Blob "samplefile.txt" -Context $blobContext
}

Function CreateResoureGroup($name, $ignoreIfExist) {
    Write-Host -Object "creating resource group"

    $rg = Get-AzureRmResourceGroup -Name $name -ErrorAction Ignore
    if($rg -ne $null) {
        Write-Host -ForegroundColor Red -Object "Warning. Resource group already exist"
        return $rg
    }
    else {
        $rg = New-AzureRmResourceGroup -Name $name -Location $defaultLocation
    }
    return $rg
}

Init