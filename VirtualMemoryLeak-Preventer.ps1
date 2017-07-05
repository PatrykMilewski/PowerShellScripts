[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False, Position=1)]
	 [String]$processName = "splwow64",
	[Parameter(Mandatory=$False, Position=2)]
	 [Int]$maxMemorySize = 20000000,
	[Parameter(Mandatory=$False)]
	 [String]$memberName = "VM",
	[Parameter(Mandatory=$False)]
	 [Int]$memoryConst = 2147483648,
	[Parameter(Mandatory=$False)]
	 [Int]$memoryTreshold = 5000000,
	[Parameter(Mandatory=$False)]
	 [Int]$sleepTime = 1,
	[Parameter(Mandatory=$False)]
	 [Int]$killCycles = 10
)

$counter = 0

while ($true) {
	try {
		$process = Get-Process -Name $processName -ErrorAction Stop
		$virtualMemory = ($process.VM / 1024) - $memoryConst

		if ($virtualMemory -gt $maxMemorySize) {
			$process.Kill()
			continue
		}

		if ($virtualMemory -gt $memoryTreshold) {
			$counter++
			if ($counter -gt $killCycles) {
				$process.Kill();
				echo "Process killed."
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