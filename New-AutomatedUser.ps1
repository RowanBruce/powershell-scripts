# Creates a new user and fills in all necessary fields
# Requires Powershell 7 to correctly pass umlaute to Entra
# First run 'Connect-Entra -scopes User.ReadWrite.All, Group.ReadWrite.All' and 'Connect-ExchangeOnline'

[CmdletBinding()]
param(
    # Collect parameter to fill in (Name, Job Title, Manager, City und optionally Username, Enabled and Remote)
    [Parameter(Position=0, Mandatory=$true)]
    [string]$FullName,

    [Parameter(Position=1, Mandatory=$true)]
    [string]$jobTitle, 

    [Parameter(Position=2, Mandatory=$true)]
    [string]$Manager,

    [Parameter(Position=3, Mandatory=$true)]
    [ValidateSet("Location1","Location2")]
    [string]$City,

    # Username as "name.surname" if it is different to full name (because of special characters: ö, ü, ä, š, etc)
    [string]$UserName,

    # Accounts made far in advance can be created as disabled by adding -Disabled 
    [switch]$Disabled,

    # For primarily remote workers adding -Remote changes Office Location to 'Remote'
    [switch]$Remote
)

# Set a default password and require change at first login
$passwordProfile = New-Object -TypeName 'Microsoft.Open.AzureAD.Model.PasswordProfile'
$passwordProfile.Password = 'AVerySecretPassword123'
$passwordProfile.ForceChangePasswordNextLogin = $true

# Split first and last names and create mail nickname
$names = $FullName -split " "
$givenName = $names[0]
$surname = $names[-1]

if ($UserName) {
        $mailNickname = $UserName
}
else {   
    $mailNickname = "$($givenName.ToLower()).$($surname.ToLower())"
}

# Get Manager ID and Department 
$managerID = $(Get-EntraUser -SearchString $Manager).Id
$Department = $(Get-EntraUser -SearchString $Manager).Department

# Get address and Usage Location
switch ($City) {
    "Location1" {
        $street = "Address 1"
        $country = "Country 1"
        $postCode = "Postcode 1"
        $usageLocation = "1"
    }
    "Location2" {
        $street = "Address 2"
        $country = "Country 2"
        $postCode = "Postcode 2"
        $usageLocation = "2"
    }
}

# Get office location

if ($Remote) {
    $OfficeLocation = 'Remote'
}
else {
    $OfficeLocation = $City
}

# Add parameters to a hashtable
$UserParams = @{
    GivenName = $givenName
    Surname = $surname
    DisplayName = $FullName
    AccountEnabled = -not $Disabled
    PasswordProfile = $passwordProfile
    UserPrincipalName = "$mailNickname@domain.com"
    MailNickname = $mailNickname
    JobTitle = $JobTitle
    Department = $Department
    CompanyName = 'Company Name Ltd.'
    StreetAddress = $street
    City = $City
    State = $City
    PostalCode = $postCode
    Country = $country
    UsageLocation = $usageLocation
}

# Create the user
$user = New-EntraUser @UserParams

# Set Manager and Office Location
Set-EntraUserManager -UserId $user.Id -ManagerId $managerID
Update-MgUser -UserId $user.Id -OfficeLocation $OfficeLocation

# Group Section
$groupIdList = [System.Collections.ArrayList]@()

# Get group ID's (ex. dynamic groups) from a non-manager department member in the same location
$departmentMember = Get-EntraUser -All | Where-Object {$_.Department -eq $Department -and $_.Id -ne $managerID -and $_.Id -ne $user.Id -and $_.City -eq $City} | Select-Object -First 1
$groupIdList.AddRange((Get-EntraUserGroup -UserId $departmentMember.Id | Where-Object {$_.DisplayName -notlike '*DYN*'}).Id)

# Remove mail distribution list from group list and add via exchange online
$mailGroups = Get-EntraGroup -All | Where-Object {$_.DisplayName -like '*Distribution_List*'}
foreach ($mailGroup in $mailgroups) {
    if ($mailGroup.Id in $groupIdList) {
        $groupIdList.Remove($mailGroup.Id)
        Add-DistributionGroupMember -Identity $mailGroup.Id -Member $user.Id
        break
    }
}

# Remove groups based on remote and enabled status
$groupsToRemove = [System.Collections.ArrayList]@()

if ($Remote) {
    $groupsToRemove.AddRange((Get-EntraGroup -All | Where-Object {$_.DisplayName -like '*In_Office_Groups*'}).Id)
} 
if ($Disabled) {
    $groupsToRemove.AddRange((Get-EntraGroup -All | Where-Object {$_.DisplayName -like '*M365_Licence*'}).Id)   
}
foreach ($groupId in $groupsToRemove) {
    $groupIdList.Remove($groupId)
}

# Add User to groups
foreach ($groupId in $groupIdList) {
    Add-EntraGroupMember -GroupId $groupId -MemberId $user.Id
}
