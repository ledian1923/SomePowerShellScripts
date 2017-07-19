<# 
SET THE TASK SCHEDULER FOR AUTOMATIC EXECUTION
Action = Start a program 
Program/Script = powershell.exe
Arguments = -ExecutionPolicy Bypass -File C:\PSscripts\BACKUP-v4.ps1 -WindowStyle hidden
#>


#DATABASE
$dbBackupDest = 'C:\backup\Database'
$mySqlDir = 'C:\Program Files (x86)\Parallels\Plesk\MySQL\bin'
$mongoDir = 'C:\Program Files\MongoDB\Server\3.0\bin'

#BackupRetention
$numberofBackups = 5

#FILES DIR
$fileDir = @(
                "path of the directory to be copied it can be multiple path separated by comma each path"
            )
$fileDest = 'Destination path'

#Timestamp
$date = get-date -Format yyyy-MM-dd

#LOGS VARIABLES#
$logName = "backuplogs"+$date+".txt"
$logPath = "C:\logpath\$logName"

#Zip archive variable
$archiveFolder = 'C:\archive'
$winRarPath = 'C:\Program Files\WinRAR'

#MAIL REPORT VARIABLES#
$emailUser = "user@email.com"
$to = "to@email.com"
$smtpServer = "mail.domain.com"
$senderAddress = "sender@email.com"



# Creates a record of all or part of a Windows PowerShell session in a text file
Start-Transcript -Path $logPath -Force

#Check if required directories are already created if not, this will create the directory that is missing
  if (!(Test-Path $fileDest) ) {
    New-Item -ItemType directory -Path $fileDest  
  }

  if (!(Test-Path $dbBackupDest) ) {
        New-Item -ItemType directory -Path $dbBackupDest
  }

  if (!( Test-Path $archiveFolder ) ) {
        New-Item -ItemType directory -Path $archiveFolder
  }

  if (! (Test-Path 'C:\logpath\logs') ) {
    New-Item -ItemType directory -Path 'C:\backup\logs'
  }

# Create files directory if not yet created and copy all mytacobellfoundation.com files to files directory
function Copy-Files {

  foreach ($dir in $fileDir) {

    Copy-Item -Path $dir -Destination $fileDest -Recurse  -Verbose
  
  }
   
}

# Executes mysqldump 
function Dump-MySQLDB {

$dbUser = 'user'
$dbNames = @('db1','db2')
$dbPass = '123'


    Set-Location -Path $mySqlDir -Verbose
    
    foreach ($dbName in $dbNames) {

    cmd.exe /c mysqldump.exe -B $dbName --user=$dbUser --password=$dbPass | Out-File $dbBackupDest\$dbName$date.sql -verbose
    
    } 
    
}

#Executes mongodump
function Dump-MongoDB {

$dbname = 'db1'

    Set-Location -Path $mongoDir
    cmd.exe /c mongodump.exe -d $dbname --out $dbBackupDest\$dbname$date 
}

#Executes winrar archive
function Compress-File {
 
    
    Set-Location -Path $winRarPath -Verbose
    cmd.exe /c winrar.exe a  -afzip -m3 -df -r -ep1 "$archiveFolder\Database$date" "$dbBackupDest\*"
    cmd.exe /c winrar.exe a  -afzip -m3 -df -r -ep1 "$archiveFolder\files$date" "C:\files\*"
    cmd.exe /c winrar.exe a  -afzip -m3 -df -r -ep1 "$archiveFolder\logs$date" "C:\logs\*"

}

#definening mail function
function Send-BackupReport {
<#
.SYNOPSIS


.DESCRIPTION

.PARAMETER

.EXAMPLE

#>

$currentBackup = Get-ChildItem -Path $archiveFolder | Select-Object -Property FullName,CreationTime | 
Sort-Object -Property CreationTime -Descending| ConvertTo-Html | Out-String
$attachment1 = "$archiveFolder\logs$date.zip"
$head = "<style> body { background-color:white; font-family:Tahoma; font-size:12pt; } td, 
th { border:1px solid black; border-collapse:collapse; } 
th { color:black; background-color:white; } table, tr, td, 
th { padding: 2px; margin: 0px } table { margin-left:50px; width:90%} </style>"
$body = $head +"List of Backups `n" +$currentBackup+ "`n The number of backups is set to $numberofBackups days"
$password = Get-Content -Path 'C:\emailpass.txt' | ConvertTo-SecureString
$creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $emailUser, $password
    
    $params = @{'To'          = $to;
                'From'        = $emailUser;
                'Subject'     = 'Backup Successfull';
                'Body'        = $body;
                'SmtpServer'  = $smtpServer;
                'BodyAsHtml'  = $true;
                'Attachments' = $attachment1
                'Port'        = 25;
                'Credential'  = $creds  
    }

    Send-MailMessage @params
}

##Define BackupRotation
function Run-BackupRotation {
$maxBackupAge = (Get-Date).AddDays(-$numberofBackups)


# Delete files older than the $maxBackupAge.
Get-ChildItem -Path $archiveFolder -Recurse -Force |
Where-Object{ !$_.PSIsContainer -and $_.CreationTime -le $maxBackupAge } | 
Remove-Item -Force -Verbose

# Delete any empty directories left behind after deleting the old files.
Get-ChildItem -Path $archiveFolder -Recurse -Force | 
Where-Object { $_.PSIsContainer -and (Get-ChildItem -Path $_.FullName -Recurse -Force | 
Where-Object { !$_.PSIsContainer }) -eq $null } | Remove-Item -Force -Recurse -Verbose

}

#region Main
#Call Rotate function
Run-BackupRotation
#Call MysqlDump function
Dump-MySQLDB
#Call MongoDB Function
Dump-MongoDB
#Call Copy files function
Copy-Files
#Stopping the transcript and put the output to $logpath
Stop-Transcript
#Call Compress function
Compress-File
#Call send email function
Send-BackupReport
#endregion Main
