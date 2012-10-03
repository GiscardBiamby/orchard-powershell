## Performs a backup of the SQL Server database associated with a given Orchard instance. 
## It is assumed that you are running this from the parent folder of the Orchard instance's app Root 
## (e.g., for a given site with app root, c:\inetpub\wwwroot\MyOrchardSite\, you must be in 
## c:\inetpub\wwwroot\ before calling this function). 
function Backup-OrchardDatabase {
    param(
        [parameter(mandatory=$true)][ValidateNotNullOrEmpty()][string]$siteName
        , [parameter(mandatory=$true)][ValidateNotNullOrEmpty()][string]$siteBackupDir
    )
    
    write-host ""
    $settingsPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\\$siteName\App_Data\Sites\Default\Settings.txt")
    if (!($settingsPath) -or !(test-path $settingsPath)) {
        write-error "Unable to load settings.txt. Searched at '$settingsPath'"
        return
    }

    write-host "  Reading values from '$settingsPath'..."
    gc $settingsPath | %{$settings = @{}} {if ($_ -match "(.*):(.*)") {$settings[$matches[1].Trim()]=$matches[2].Trim();}} 
    $connectionString = $settings["DataConnectionString"]
    $tablePrefix = $settings["DataPrefix"]
    $dbName = ""
    write-host "    DataPrefix: '$tablePrefix'"
    write-host "    DataConnectionString: '$connectionString'"

    if ($connectionString -match "Initial Catalog(\s*)=(\s*)(?<DbName>.[^;]*)\s*;") {
        $dbName = $matches["DbName"]
    } 
    if (!($dbName) -or !($connectionString) -or !($tablePrefix) ) {
        Write-Error "    Unable to get database settings from App_Data\...\Settings.txt"
        return
    }
    if (!($siteBackupDir) -or !(test-path $siteBackupDir)) {
        write-error "    Backup destination directory, '$siteBackupDir', not found."
        return
    }

    Write-Host "DbName: $dbName"
    Backup-SQLDatabase -dbName $dbName -Dest $siteBackupDir

}

## ///TODO: Need to update all the functions to return true or false. Either that or find a way to make errors bubble up all the way to the original context 
## (e.g., end script execution and throw error from any function to the command line)
## Full + Log Backup of MS SQL Server databases with SMO. 
## Based on code from: http://social.technet.microsoft.com/wiki/contents/articles/900.how-to-sql-server-databases-backup-with-powershell-en-us.aspx
function Backup-SQLDatabase {
    param(
        [string]$Server = "(local)"
        , [string]$dbName = ""
        , [string]$Dest = ""
    )

    ## Load SQL Server SMO assemblies: 
    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo');
    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Management.Sdk.Sfc');
    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO');
    # Requiered for SQL Server 2008 (SMO 10.0).
    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended');

    if (!($dbName)) {
        Write-Error "Required parameter, '$dbName' was not specified, or no value was provided."
        return 
    }

    $srv = New-Object Microsoft.SqlServer.Management.Smo.Server $Server;
    # If missing set default backup directory.
    if (!( ($Dest) -and (test-path $Dest))) {
        write-error "Invalid destination path ('$Dest')"
        return
    } else {
        $Dest = resolve-path $Dest 
        if (!$Dest.EndsWith("\")) { $Dest += "\"; }
    }
    If (!($Dest) -or $Dest.Trim() -eq "") { 
        $Dest = $server.Settings.BackupDirectory + "\" 
    };
    Write-Output ("Started at: " + (Get-Date -format yyyy-MM-dd-HH:mm:ss));
    Write-Output "Backing up database: '$dbName', on server: '$Server', to location: '$Dest'"

    $databaseFound = $false 
    # Full-backup for every database
    foreach ($db in $srv.Databases) {
        If($db.Name -eq $dbName) {
            $databaseFound = $true 
            $timestamp = Get-Date -format yyyy-MM-dd-HH-mm-ss;
            $backupFileName = $Dest + $db.Name + "_" + $env:COMPUTERNAME.ToUpper() + "_full_" + $timestamp + ".bak"
            $backup = New-Object ("Microsoft.SqlServer.Management.Smo.Backup");
            $backup.Action = "Database";
            $backup.Database = $db.Name;
            $backup.Devices.AddDevice($backupFileName, "File");
            $backup.BackupSetDescription = "Full backup of " + $db.Name + " " + $timestamp;
            $backup.Incremental = 0;
            $backup.CompressionOption = 1;
            # Starting full backup process.
            $backup.SqlBackup($srv);
            Write-Output "Finished writing backup: '$backupFileName'"

            # For db with recovery mode <> simple: Log backup.
            If ($db.RecoveryModel -ne 3 -and 1 -eq 2) {
                $timestamp = Get-Date -format yyyy-MM-dd-HH-mm-ss;
                $backup = New-Object ("Microsoft.SqlServer.Management.Smo.Backup");
                $backup.Action = "Log";
                $backup.Database = $db.Name;
                $backup.Devices.AddDevice($Dest + $db.Name + "_log_" + $timestamp + ".trn", "File");
                $backup.BackupSetDescription = "Log backup of " + $db.Name + " " + $timestamp;
                #Specify that the log must be truncated after the backup is complete.
                $backup.LogTruncation = "Truncate";
                # Starting log backup process
                $backup.SqlBackup($srv);
            };
        };
    };

    if (!($databaseFound)) {
        write-error "    Error! No database with name '$dbName' was found on server '$Server'"
        return
    }
    Write-Output ("Finished at: " + (Get-Date -format  yyyy-MM-dd-HH:mm:ss));
    return $true
}

## 
## Sample use of the function: 
## Backup-SQLDatabase -dbName "orchard1x" -Dest "C:\sites\Archive\MyOrchardSite\"