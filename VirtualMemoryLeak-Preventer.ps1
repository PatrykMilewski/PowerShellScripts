[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False, Position=1)]
	 [String]$processName = "splwow64",
	[Parameter(Mandatory=$False, Position=2)]
	 [Int]$maxMemorySize = 20000000,
	[Parameter(Mandatory=$False)]
	 [String]$memberName = "VM",
	[Parameter(Mandatory=$False)]
	 [Long]$memoryConst = 2147483648,
	[Parameter(Mandatory=$False)]
	 [Int]$memoryTreshold = 500000,
	[Parameter(Mandatory=$False)]
	 [Int]$sleepTime = 1,
	[Parameter(Mandatory=$False)]
	 [Int]$killCycles = 5
)

$counter = 0
$previousMemory = 0
$virtualMemory = 0

while ($true) {
	try {
		$process = Get-Process -Name $processName -ErrorAction Stop
		$previousMemory = $virtualMemory
		$virtualMemory = ($process.VM / 1024) - $memoryConst

		if ($virtualMemory -gt $maxMemorySize) {
			$process.Kill()
			$counter = 0
			echo ("Process killed with " + $virtualMemory + " VM.")
		}

		elseif ($virtualMemory -gt $memoryTreshold) {
			if ($previousMemory -eq $virtualMemory) {
				$counter++
			}

			if ($counter -gt $killCycles) {
				$process.Kill();
				$counter = 0
				echo ("Process killed with " + $virtualMemory + " VM.")
			}
		}
		else {
			$counter = 0
		}

	}
	catch {
		$counter = 0
	}

	Start-Sleep -Seconds $sleepTime
}