##
## Clears /App_Data/cache.dat, /App_Data/Sites/Default/mappings.bin, and /App_Data/Logs/*.log
function Orchard-Clear-AppCaches {
    param(
        [parameter(mandatory=$true)][ValidateNotNullOrEmpty()][string]$siteName
        , [string]$appRoot  = ""
        , [string]$iisRoot = "c:\sites\"
    )
    ## If $appRoot isn't specified, assume it is same as $siteName: 
    if ($siteName -and !($appRoot)) {
        Write-Warning "  No value was specified for the property, `$appRoot. Setting `$appRoot to: $siteName"
        $appRoot = $siteName 
    }
    
    $appRoot = Resolve-Path $appRoot
    Write-Host "  Deployment target path: '$appRoot'"
    $appDataPath = Resolve-Path "$appRoot\App_Data"
    Write-Host "  App_Data path: '$appDataPath'"

    ## 
    ## Validate parameters before continuing: 
    if (!($siteName)) {
        write-error "  Error! You must specify a value for property `$siteName."
        return 
    }
    if (!(get-website | where-object { $_.name -eq $siteName })) {
        write-error "  Error! Site, '$siteName' does not exist"
        return 
    }
    if (!($appRoot) -or !(test-path $appRoot)) {
        write-Error "  Error! Target path (appRoot), '$appRoot' not found."
        return 
    }

    Write-Host ""
    Write-Host "Clearing application caches for $appRoot."

    ## Delete mappings.bin, cache.dat, and logs:
    Get-ChildItem $appDataPath * -Recurse -File -Include cache.dat,mappings.bin | Remove-Item 
    Get-ChildItem "$appDataPath\Logs" * -Recurse -File -Include *.log | Remove-Item 

    Write-Host "Done clearing application caches for $appRoot."
}
function Get-ScriptDirectory {
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}