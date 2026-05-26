# Take a CSV with columns ID, containing an employee ID number, and Sname, 
# containing an employee's surname, and uploads the ID number to that 
# employee's entra user profile.

# NOTE: Only works in the case that no surnames are duplicated in the list.

[CmdletBinding()]
param(
    [parameter (Position=0, Mandatory=$true)]
    [string]$file_path
)

$file = import-csv $file_path -delimiter ";"

$users = Get-EntraUser -All | Where-Object {$_.Surname -in $file.Sname}

foreach ($row in $file) {
    $matchedUsers = $users | Where-Object { $_.Surname -eq $row.Sname }

    foreach ($user in $matchedUsers) {
        Set-EntraUser -Id $user.Id -EmployeeId $row.ID
    }
}
