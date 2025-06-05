# Script to create a new active directory user based on parameters passed in

# Gets parameters
param(
    [parameter(Mandatory=$true)]
    [string]$FirstName

    [parameter(Mandatory=$true)]
    [string]$LastName

    [parameter(Mandatory=$true)]
    [string]$UserName

    [parameter(Mandatory=$true)]
    [string]$OU

    [parameter(Mandatory=$true)]
    [string]$Domain
)

# Generates a random password
$Password = -join((0x30..0x39)+(0x41..0x5A)+(0x61..0x7A) | Get-Random -Count 12 | ForEach-Object {[char]$_})
Write-Host "Password: $Password"
$SecurePassword = ($Password | ConvertTo-SecureString -AsPlainText -Force)

# Calls New-ADUser to create the user
New-ADUser `
    -SamAccountName $UserName `
    -UserPrincipalName "$UserName@$Domain" `
    -GivenName $FirstName `
    -Surname $LastName `
    -Name "$FirstName $LastName" `
    -AccountPassword $SecurePassword `
    -Enabled $true `
    # Path must be changed if the user should be created in a domain other than LAB.local
    -Path "OU = $OU, DC = LAB, DC = local" `
    -ChangePasswordAtLogon $true