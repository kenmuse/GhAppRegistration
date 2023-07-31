#Requires –Modules Az.Accounts, Az.Resources
#Requires -Version 7.2
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction']='Stop'

New-Variable -Name DirectoryReadAllAppRoleId        -Value '7ab1d382-f21e-4acd-a863-ba3e13f7da61'        -Option Constant -Scope Script
New-Variable -Name MsGraphResourceId                -Value 'e51b873a-e178-4e6a-ab84-b07d68b33bc8'        -Option Constant -Scope Script
New-Variable -Name AzRoleUserAccessAdministrator    -Value '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'        -Option Constant -Scope Script
New-Variable -Name AzRoleContributor                -Value 'b24988ac-6180-42a0-ab88-20f7382dd24c'        -Option Constant -Scope Script
New-Variable -Name MicrosoftGraphApiId              -Value '00000003-0000-0000-c000-000000000000'        -Option Constant -Scope Script
New-Variable -Name FedCredentialName                -Value 'GitHub'                                      -Option Constant -Scope Script
New-Variable -Name GitHubIssuer                     -Value 'https://token.actions.githubusercontent.com' -Option Constant -Scope Script

<#
.SYNOPSIS
Creates an Azure AD application with Federated Credentials for GitHub    

.DESCRIPTION
Creates an Azure AD application and the associated Federated Credentials
required to integrate using OIDC

.PARAMETER Name
Specifies the name of the application.

.PARAMETER Subject
Specifies the subject for the OIDC integration, such as "repo:MyOrg/MyRepo:environment:dev"

.INPUTS
Pipe objects are not supported

.OUTPUTS
System.String. The application identifier

#>
function New-GhAzOidcApplication {
    [OutputType([System.Guid])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Name,
        
        [Parameter()]
        [string]
        $Subject
    )

    $spn = Get-AzADServicePrincipal -DisplayName $Name
    if ($spn) {
        return $spn.AppId
    }

    $spn = New-AzADServicePrincipal -DisplayName $Name
    $app = Get-AzADApplication -ApplicationId $spn.AppId
    $principalId = $spn.Id

    $AppPermissions = @{
        ObjectId = $app.id
        ApiId = $MicrosoftGraphApiId
        PermissionId = $DirectoryReadAllAppRoleId
        Type = 'Role'
    }
    Add-AzADAppPermission @AppPermissions

    $FedCredential = @{
        ApplicationObjectId = $app.Id
        Audience = @('api://AzureADTokenExchange')
        Issuer = $GitHubIssuer
        Name = $FedCredentialName
        Subject = $Subject
    }
    New-AzADAppFederatedCredential @FedCredential | Out-Null

    Set-AzGraphConsentedRole -PrincipalId $principalId -RoleId $DirectoryReadAllAppRoleId
    
    @{ 
        AppId = $app.Id
        SpnId = $spn.Id
    }
}

<#
.SYNOPSIS
Creates a role for the principal with administrative consent

.DESCRIPTION
Creates a role and applies administrative consent for a Graph Resource

.PARAMETER PrincipalId
The service principal ID associated with the application

.PARAMETER RoleId
The Microsoft Graph Role to be applied

.OUTPUTS
None

#>
function Set-AzGraphConsentedRole {
    [CmdletBinding()]
    param(
        [string]
        $PrincipalId,
        
        [string] 
        $RoleId
    )

    $oken = Get-AzAccessToken -ResourceTypeName MSGraph
    $headers = @{
        Authorization = "Bearer $($oken.Token)"
        'Content-Type' = 'application/json'
    }

    $AdminConsent  = @{
        Method = 'POST'
        Uri = "https://graph.microsoft.com/v1.0/servicePrincipals/$PrincipalId/appRoleAssignments"
        Body = @{
            principalId = $PrincipalId
            resourceId = $MsGraphResourceId
            appRoleId = $RoleId
        } | ConvertTo-Json
        Headers = $headers
    }

    Invoke-RestMethod @AdminConsent | Out-Null
}

Export-ModuleMember -Function New-GhAzOidcApplication, Set-AzGraphConsentedRole

