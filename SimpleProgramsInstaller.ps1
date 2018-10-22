<#

.PARAMETER installFolder
Localisation of exe installators.

.PARAMETER logFileName
Name of log file.

.PARAMETER logFileLocation
Localisation of log file.

.PARAMETER programsListName
Name of .ini file with programs list.

.PARAMETER installatorsListName
Name of .ini file with installators list.

.PARAMETER argumentsListName
Name of .ini file with arguments list for installation.

.OUTPUTS
1 - one of .ini files does not exist.
2 - one of .ini files has different amount of lines inside it (they should be equal).

#>

[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False)]
	 [String]$installFolder = "\\serwer\install\exe",
	 [String]$logFileName = "silentInstallLogs.txt",
	 [String]$logFileLocation = $PSScriptRoot + "\" + $logFileName,
	 [String]$porgramsListName = "programsList.ini",
	 [String]$installatorsListName = "installatorsList.ini",
	 [String]$argumentsListName = "argumentsList.ini"
)

if ($PSVersionTable.PSVersion.major -lt 4) {
	addLog "PowerShell version is less than 4. Can't install programs."
    exit
}

$programsList = [System.IO.File]::OpenText($PSScriptRoot + "\$porgramsListName")
$installatorsList = [System.IO.File]::OpenText($PSScriptRoot + "\$installatorsListName")
$argumentsList = [System.IO.File]::OpenText($PSScriptRoot + "\$argumentsListName")
$programsListLines = Get-Content $PSScriptRoot\programsList.ini |  Measure-Object -Line
$installatorsListLines = Get-Content $PSScriptRoot\installatorsList.ini | Measure-Object -Line
$argumentsListLines = Get-Content $PSScriptRoot\argumentsList.ini | Measure-Object -Line

if ($programsList -eq $null -or $installatorsList -eq $null -or $argumentsList -eq $null) {
	addLog "One of .ini files does not exist. Script will now exit."
	exit 1
}
if ($programsListLines.lines -ne $installatorsListLines.lines -or $programsListLines.lines -ne $argumentsListLines.lines) {
	addLog "One of files programsList.ini, installatorsList.ini or argumentsList.ini has different amount of lines than others. Script will now exit."
	exit 2
}

function addLog($newLog) {
	"[" + (Get-Date) + "] " + $newLog | Add-Content $logFileLocation
}

function Get-InstalledApps {
	#check if system is x86 or x64
    if ([IntPtr]::Size -eq 4) {
        $regpath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    }
    else {
        $regpath = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
    }
    Get-ItemProperty $regpath | .{process{if($_.DisplayName -and $_.UninstallString) { $_ } }} | Select DisplayName, Publisher, InstallDate, DisplayVersion, UninstallString |Sort DisplayName
}

if (!(Test-Path $logFileLocation) -and (Test-Path -Path $installFolder)) {
	addLog "Log file created."
}

$installedApps = Get-InstalledApps

while ($null -ne ($program = $programsList.ReadLine())) {
	$installator = $installatorsList.ReadLine();
	$arguments = $argumentsList.ReadLine();
	if (!($installedApps | where {$_.DisplayName -like $program})) {
		$result = Start-Process -FilePath $installFolder\$installator -ArgumentList $arguments -Wait -PassThru
		if ($result.ExitCode -ne 0) {
			$errorCode = $result.ExitCode
			addLog "Process install program $program returned error code: $errorCode"
		}
		else {
			addLog "Successfully installed program $program."
		}
	}
}
