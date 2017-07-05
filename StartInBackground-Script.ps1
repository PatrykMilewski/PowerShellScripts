[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False, Position=1)]
	 [String]$scriptName = "VirtualMemoryLeak-Preventer.ps1"
)

$path = Join-Path $env:SystemDrive Scripts\$scriptName
Start-Process PowerShell.exe -WindowStyle Hidden -ArgumentList "$path"