orchard-powershell
==================

Some scripts to help backup and deploy Orchard websites. Usefull if you want to create an exact replica of an Orchard deployment from staging/production/etc environment, to practice migrations or reproduce issues on your local machine. 

Examples
--------
Do a file + SQL Server db backup backup of the orchard site, and deploy a new build from .zip

    cd \inetpub\wwwroot\
    .\Deploy-OrchardSite.ps1 -siteName "www.myorchardsite.com" -zipPath "www.myorchardsite.com-BUILD-v0.1.2.zip"

Do a file + SQL Server db backup backup of the orchard site: 

    cd \inetpub\wwwroot\
    .\Deploy-OrchardSite.ps1 -siteName "www.myorchardsite.com" -BackupOnly


Details
--------
 - Always run the script from the parent dir of the site's app root
 - Backups are stored relative to the current dir, in Archive\<$siteName-DATE__TIME>\ 
 - The script reads the info from $siteName\App_Data\Settings\Default\Settings.txt to figure out which database to backup. (sorry, no multi-tenancy support ATM)

