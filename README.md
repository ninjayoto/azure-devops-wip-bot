# Azure DevOps WIP Bot
A WIP Bot for Azure DevOps similar to https://github.com/wip/app

## Deploy to Azure Functions

1. Follow this [blog](https://www.brianbunke.com/blog/2018/02/27/powershell-in-azure-functions/) to create an Azure Function using PowerShell.

2. Set `run.ps1` with the content of `wip-bot.ps1`

## Set App Settings

Set following items in App Settings:

- AZURE_DEVOPS_BOTNAME: the bot name for Azure DevOps
- AZURE_DEVOPS_USERNAME: the user name of the account to access Azure DevOps API
- AZURE_DEVOPS_USERSECRET: the user secret of the account to access Azure DevOps API
