# An Azure DevOps WIP bot similar to https://github.com/wip/app
# Runs on PowerShell 5.1 (Azure Function currently only support PowerShell 5.1)
# See https://github.com/herohua/azure-devops-wip-bot
$BotName = $env:AZURE_DEVOPS_BOTNAME
$ApiUser = $env:AZURE_DEVOPS_USERNAME
$ApiPassword = $env:AZURE_DEVOPS_USERSECRET

$SupportedEvents = @('git.pullrequest.created*', 'git.pullrequest.updated*')
$FilteredStatuses = @('completed', 'abandoned')
$WipKeyWords = @('wip', 'work in progress', 'do not merge')

# POST method: requestBody - $req, responseBody - $res
if ($req)
{
    $requestBody = Get-Content $req -Raw | ConvertFrom-Json
}
else
{
    if ($reqPath)
    {
        $requestBody = Get-Content -Path $reqPath -Raw | ConvertFrom-Json
    }
    else
    {
        throw "{req} and {reqPath} are both empty."
    }
}

$eventType = $requestBody.eventType
$pullRequestTitle = $requestBody.resource.title
$pullRequestStatus = $requestBody.resource.status
$statusApiUrl = $requestBody.resource._links.statuses.href + '?api-version=4.0-preview'
Write-Output "Received service hook of pull request, title: $pullRequestTitle, type: $eventType, status: $pullRequestStatus"

# For PowerShell 6, pass in '-Credential $ApiCredential'
$ApiPasswordSecureString = ConvertTo-SecureString -String $ApiPassword -AsPlainText -Force
$ApiCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ApiUser, $ApiPasswordSecureString

# Workaround Basic authentication in PowerShell 5.1
$ApiUserPassWord = "${ApiUser}:${ApiPassword}"
$ApiUserPassWordBytes = [System.Text.Encoding]::ASCII.GetBytes($ApiUserPassWord)
$ApiUserPassWordBase64 = [System.Convert]::ToBase64String($ApiUserPassWordBytes)

foreach ($supportedEvent in $SupportedEvents)
{
    if ($eventType -like $supportedEvent)
    {
        $isFilteredStatus = $false
        foreach ($filteredStatus in $FilteredStatuses)
        {
            if ($pullRequestStatus -eq $filteredStatus)
            {
                $isFilteredStatus = $true
                break
            }
        }
        if ($isFilteredStatus)
        {
            continue
        }

        $statusToUpdate = 'succeeded'
        $descriptionToUpdate = 'WIP: ready for review'
        foreach ($wipKeyWord in $WipKeyWords)
        {
            $wipKeyWord = '*' + $wipKeyWord + '*'
            if ($pullRequestTitle -like $wipKeyWord)
            {
                $statusToUpdate = 'pending'
                $descriptionToUpdate = 'WIP: work in progress'
                break
            }
        }

        Write-Output "Set PR status: $statusToUpdate, description: $descriptionToUpdate"
        $statusApiRequestHeader = @{
            Authorization = "Basic $ApiUserPassWordBase64"
        }
        $statusApiRequestHeader.Add('Content-Type', 'application/json')
        $statusApiRequestBody = @{
            state = $statusToUpdate
            description = $descriptionToUpdate
            context = @{
                name = $BotName
            }
        }
        $statusApiRequestBodyInJsonString = ConvertTo-Json $statusApiRequestBody

        try
        {
            # For PowerShell 6, pass in '-Credential $ApiCredential'
            Invoke-RestMethod -Method 'Post' -Uri $statusApiUrl -Header $statusApiRequestHeader -Body $statusApiRequestBodyInJsonString -ContentType 'application/json' -OutFile $res
        }
        catch
        {
            if (-not ($_.Exception.Message -like '*The requested pull request status cannot be updated as it requires an active pull request*'))
            {
                throw
            }
        }

        break
    }
}
