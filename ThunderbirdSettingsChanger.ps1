<#

.SYNOPSIS
This script's function is to add, delete or reverse to persevious settings of Thunderbird.

.PARAMETER mode
You have to choose script's mode from list: add, delete, deleteadd, reverse (last action).

.PARAMETER destinationPath
Localisation of directory, where user's profiles data is stored.

.PARAMETER settingsToAddLoc
Localisation of directory, where are stored lines, that will be added to user's settings.

.PARAMETER settingsToDelLoc
Localisation of directory, where are stored lines, that will be deleted from user's settings.

.PARAMETER prefsLocation
Localisation where is stored prefs.js starting from destinationPath. You should use variable here, to make this directory dynamic. By default it's: \&USER_NAME&\Thunderbird\prefs.js. Script will swap &USER_NAME& with folder name from list, that is made from destinationPath.

.PARAMETER logFileName
Name of log file.

.PARAMETER logFileLocation
Localisation of log file.

.PARAMETER nameOfPrefsJsCopy
Name of copy of prefs.js file.

.PARAMETER outFileEncoding
Encoding type of all prefs.js files. By default it's: UTF8, but you can choose from all that Out-File and Add-Content functions handle.

.OUTPUTS
This script only returns error codes.
Error codes are organised by binary number, if there is error code number 1, then the youngest bit of return code will be "1", for example:
000001 - error code number 1,
010001 - error codes number 1 and 5,
000000 - no errors.
Error codes list:
1 - couldn't read settings from settingsToAddLoc file, because this file doesn't exist.
2 - exception in addSettings function.
3 - couldn't read settings from settingsToDelLoc file, because this file doesn't exist.
4 - exception in deleteSettings function.
5 - destinationPath is unreachable.
6 - unknown script mode was choosen.

#>

[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True, Position=1)]
	[ValidateSet('add', 'delete', 'deleteadd', 'deletelogs', 'reverse')]
	 [String]$mode,
	[Parameter(Mandatory=$True, Position=2)]
	 [String]$destinationPath,
	[Parameter(Mandatory=$False)]
	 [String]$settingsToAddLoc = (Join-Path $PSScriptRoot "settingsToAdd.ini"),
	 [String]$settingsToDelLoc = (Join-Path $PSScriptRoot "settingsToDelete.ini"),
	 [String]$prefsLocation = (Join-Path $destinationPath '\&USER_NAME&\Thunderbird\prefs.js'),
	 [String]$logsLocation = (Join-Path $destinationPath '\&USER_NAME&\Logs\thunderbirdProfilesLogs.txt'),
	 [String]$logFileName = "thunderbirdSettingsChanger.log",
	 [String]$logFileLocation = (Join-Path $PSScriptRoot $logFileName),
	 [String]$nameOfPrefsJsCopy = "prefsCopy.js",
	 [String]$outFileEncoding = "UTF8"
)

Set-Variable -Name exitCode -Value 0 -Scope script

function addLog($newLog) {
	"[" + (Get-Date) + "] " + $newLog | Add-Content $logFileLocation
}

function readSettings {
	Param(
		[Parameter(Mandatory=$True, Position=1)]
		[ValidateSet('add', 'delete')]
		 [String]$addOrDel
	)
	if (($addOrDel -eq 'add' -and (Test-Path $settingsToAddLoc)) -or ($addOrDel -eq 'delete' -and (Test-Path $settingsToDelLoc))) {
		if ($addOrDel -eq 'add') {
			$settings = Get-Content $settingsToAddLoc
		}
		elseif ($addOrDel -eq 'delete') {
			$settings = Get-Content $settingsToDelLoc
		}
		else {
			throw "Unknown function mode selected: $addOrDel."
		}

		return $settings
	}
	else {
		throw [System.IO.FileNotFoundException] "File with settings to $addOrDel not found!"
	}
}

function confirmAction() {
	Param(
		[Parameter(Mandatory=$True, Position=1)]
		[ValidateSet('add', 'delete', 'deleteadd', 'deletelogs', 'reverse')]
		 [String]$action
	)
	switch ($action) {
		'add' { $question = "This action will add following lines:`n" + (readSettings 'add') }
		'delete' { $question = "This action will delete following lines:`n" + (readSettings 'delete') }
		'deleteadd' { $question = "This action will delete following lines:`n" + (readSettings 'delete') + "`nand then add these lines:`n" + (readSettings 'add') }
		'deletelogs' { $question = "This action will delete all thunderbird dynamic profile script's logs." }
		'reverse' { $question = "This action will reverse last action, that was done by this script." }
		default { $question = "Unknown action. Please report a bug to author."}
	}

	$message  = 'Are you sure you want to proceed?'

	$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
	$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
	$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

	$decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
	if ($decision -eq 0) {
		return $True
	} 
	else {
		return $False
	}
}

function createListOfFolders() {
	return Get-ChildItem -Path $destinationPath | ?{ $_.PSIsContainer } | Select-Object Name
}

function addSettings([switch]$dontMakeCopy) {
	$counter = 0
	try {
		$settingsToAdd = readSettings 'add'
		$listOfFolders = createListOfFolders
		ForEach ($folder in $listOfFolders) {
			$singlePath = $prefsLocation -replace '&USER_NAME&', $folder.name
			if (Test-Path $singlePath) {
				$copyPath = Join-Path (Split-Path $singlePath -Parent) $nameOfPrefsJsCopy
				if ($dontMakeCopy -eq $False) {
					Copy-Item $singlePath -Destination $copyPath
				}
				ForEach ($setting in $settingsToAdd) {
					Add-Content $singlePath -Value $setting -Encoding $outFileEncoding
				}
				$counter++
			}
		}
	}
	catch [System.IO.FileNotFoundException] {
		addLog $error[0]
		$script:exitCode += 1
	}
	catch {
		addLog $error[0]
		$script:exitCode += 2
	}
	addLog "Succesfully added setting to $counter settings files."
}

function deleteSettings([switch]$dontMakeCopy) {
	$counter = 0
	try {
		$settingsToDel = readSettings 'delete'
		$listOfFolders = createListOfFolders
		ForEach ($folder in $listOfFolders) {
			$singlePath = $prefsLocation -replace '&USER_NAME&', $folder.name
			if (Test-Path $singlePath) {
				$copyPath = Join-Path (Split-Path $singlePath -Parent) $nameOfPrefsJsCopy
				if ($dontMakeCopy -eq $False) {
					Copy-Item $singlePath -Destination $copyPath -Force
				}
				$prefsJs = Get-Content $singlePath
				ForEach ($setting in $settingsToDel) {
					$prefsJs = $prefsJs -notlike $setting
				}
				$prefsJs | Out-File $singlePath -Encoding $outFileEncoding -Force
				$counter++
			}
		}
	}
	catch [System.IO.FileNotFoundException] {
		addLog $error[0]
		$script:exitCode += 4
	}
	catch {
		addLog $error[0]
		$script:exitCode += 8
	}
	addLog "Succesfully deleted setting from $counter setting files."
}

function deleteLogs() {
	$counter = 0
	$listOfFolders = createListOfFolders
	ForEach ($folder in $listOfFolders) {
		$singlePath = $logsLocation -replace '&USER_NAME&', $folder.name
		if (Test-Path $singlePath) {
			Remove-Item $singlePath
			$counter++
		}
	}
	addLog "Succesfully deleted $counter log files."
}

function reverseSettings() {
	$counter = 0
	$listOfFolders = createListOfFolders
	ForEach ($folder in $listOfFolders) {
		$singlePath = $prefsLocation -replace '&USER_NAME&', $folder.name
		$copyPath = Join-Path (Split-Path $singlePath -Parent) $nameOfPrefsJsCopy
		if (Test-Path $copyPath) {
			if (Test-Path $singlePath) {
				Remove-Item $singlePath
			}
			Rename-Item $copyPath "prefs.js"
			$counter++
		}
	}
	addLog "Succesfully reversed $counter files with settings."
}

if (!(Test-Path $logFileLocation)) {
	addLog "Log file created."
}

if (!(Test-Path $destinationPath)) {
	addLog "Destination path is unreachable."
	return 16
}

switch ($mode) {
	'add' { 
		if ((confirmAction 'add') -eq $True) {
			addSettings
		} 
	}
	'delete' {
		if ((confirmAction 'delete') -eq $True) {
			deleteSettings
		}
	}
	'deleteadd' {
		if ((confirmAction 'deleteadd') -eq $True) {
			deleteSettings
			if ($mode -eq 'deleteadd') {
				addSettings -dontMakeCopy
			}
		}
	}
	'deletelogs' {
		if ((confirmAction 'deletelogs') -eq $True) {
			deleteLogs
		}
	}
	'reverse' {
		if ((confirmAction 'reverse') -eq $True) {
			reverseSettings
		}
	}
	default {
		addLog "Unknown mode choosen."
		$script:exitCode += 32
	}
}

if ($script:exitCode -ne 0) {
	addLog "Script exited with error code: $script:exitCode"
}

return $script:exitCode
