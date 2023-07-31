# AzOidcAppRegistration
Sample PowerShell module to create Azure App with Federated Credential

To use this script:

1. Use `Connect-AzAccount` to authenticate to the Azure Account (if not already done)
2. Use `Import-Module ./AzOidcAppRegistration.psm1` to load the module into memory
3. Call `New-GhAzOidcApplication -Name 'Your App Name' -Subject `repo:MyOrg/MyRepo:environment:demo`, configuring the parameters as appropriate for your application.
4. The script will return the identifiers for the application and service principal.
