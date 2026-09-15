<#
.SYNOPSIS
  Runs a T-SQL query against a local SQL Server without requiring sqlcmd.

.DESCRIPTION
  A winget-installed SQL Server Express does not put sqlcmd on PATH, so the
  "does the database already exist?" and "did the restore work?" checks in the
  shesha-get-started skill cannot rely on it. This script connects through
  System.Data.SqlClient (present in Windows PowerShell) instead.

  Defaults to localhost with Windows authentication and automatically retries
  localhost\SQLEXPRESS, which is the instance a winget SQL Server Express
  install actually creates.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/sql-query.ps1 `
    -Query "SELECT name FROM sys.databases WHERE database_id > 4;"

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/sql-query.ps1 `
    -Database Membership -Query "SELECT TOP 5 * FROM dbo.Core_Persons;"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Query,
    [string]$Server = 'localhost',
    [string]$Database = 'master',
    [string]$User,
    [string]$Password,
    [int]$TimeoutSeconds = 15
)

$ErrorActionPreference = 'Stop'

function New-ConnectionString {
    param([string]$TargetServer)

    $builder = "Server=$TargetServer;Database=$Database;TrustServerCertificate=True;Connect Timeout=$TimeoutSeconds;"
    if ($User) {
        $builder += "User ID=$User;Password=$Password;"
    }
    else {
        $builder += 'Integrated Security=True;'
    }
    return $builder
}

function Invoke-Query {
    param([string]$TargetServer)

    $connection = New-Object System.Data.SqlClient.SqlConnection (New-ConnectionString -TargetServer $TargetServer)
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Query
        $command.CommandTimeout = 0   # imports and large selects can run long

        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
        $table = New-Object System.Data.DataTable
        [void]$adapter.Fill($table)
        # The leading comma stops PowerShell unrolling the DataTable into DataRows
        # on return. Without it a single-row result arrives as one DataRow, whose
        # .Rows is $null, so Rows.Count reads 0 and the caller reports "no rows"
        # for a query that in fact matched — e.g. the "does this database already
        # exist?" check silently returning false.
        return ,$table
    }
    finally {
        $connection.Dispose()
    }
}

# Try the requested server first; fall back to the Express instance only when
# the caller did not name a specific one.
$candidates = @($Server)
if ($Server -eq 'localhost') {
    $candidates += 'localhost\SQLEXPRESS'
}

$lastError = $null
foreach ($candidate in $candidates) {
    try {
        $result = Invoke-Query -TargetServer $candidate
        # Unwrap the single-element array the comma-return produces.
        if ($result -is [System.Array]) { $result = $result[0] }
        Write-Output "-- connected to $candidate (database: $Database)"
        if ($result.Rows.Count -eq 0) {
            Write-Output '-- query returned no rows'
        }
        else {
            $result.Rows | Format-Table -AutoSize | Out-String -Width 4096 | Write-Output
        }
        exit 0
    }
    catch {
        $lastError = $_
        Write-Output "-- could not use $candidate : $($_.Exception.Message)"
    }
}

Write-Output '-- SQL Server is not reachable on any candidate instance.'
Write-Output '-- Confirm the SQL Server service is running, then retry.'
if ($lastError) { Write-Output "-- last error: $($lastError.Exception.Message)" }
exit 1
