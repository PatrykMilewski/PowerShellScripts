[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False, Position=1)]
	 [Int]$sleepTime = 10,
	[Parameter(Mandatory=$False, Position=2)]
	 [Int]$maxMemorySize = 500,
	[Parameter(Mandatory=$False)]
	 [String]$sortBy = "WS",
	[Parameter(Mandatory=$False)]
	 [String]$memberName = "WorkingSet",
	[Parameter(Mandatory=$False)]
	 [Switch]$showPopUpWindows = $True
)

$wshell = New-Object -ComObject Wscript.Shell

while($True) {
	$process = get-process | Sort-Object -Descending $sortBy | select -first 1
	$memoryUsage = $process.WS
	$memoryUsage /= 1048576

	if ($memoryUsage -gt $maxMemorySize) {
		Stop-Process $process.Id
		if ($showPopUpWindows -eq $True) {
			$wshell.Popup(("Killed process " + $process.Name + " with ID: " + $process.Id),0,"Memory leak prevention",0x0)
		}
		echo ("Killed process " + $process.Name + " with ID: " + $process.Id)
	}
	Start-Sleep -Seconds $sleepTime
}
