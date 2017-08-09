
function Run-Tasks {
    [CmdletBinding()]
    Param(
         [String]$PSScriptRoot = "C:\Work",
	     [String]$IniFileLocation = (Join-Path $PSScriptRoot "Run-Tasks.ini"),
         [String]$LogFileName = "Run-Tasks.log",
         [String]$LogFileLocation = (Join-Path $PSScriptRoot $LogFileName)
    )

    BEGIN {
        Write-Verbose ("Starting Run-Tasks script with parameters 1: " + $IniFileLocation + " 2: " + $LogFileName + " 3: " + $LogFileLocation)
        Write-Verbose "Declaring CustomProcess Class"
        Class CustomProcess {

            static [Int]$Counter = 0

            [String]$exeFileLocation
            [String]$arguments
            [Switch]$runRemotly
            [String]$remoteTarget
            [String]$stdout = (Join-Path $env:temp ("stdout" + [CustomProcess]::Counter + ".temp"))
            [String]$stderr = (Join-Path $env:temp ("stderr" + [CustomProcess]::Counter + ".temp"))
            [String]$stdoutContent
            [String]$stderrContent
            [Int]$errorCode
            [String]$errorText
            
            CustomProcess([String]$exeFileLocation, [String]$arguments, [String]$runRemotly, [String]$remoteTarget) {
                Write-Verbose ("Constructing CustomProcess Class instance number: " + [CustomProcess]::Counter + " with parameters 1: " + $exeFileLocation + " 2: " + $arguments + " 3: " + $runRemotly + " 4: " + $remoteTarget)
                [CustomProcess]::Counter++
                $this.exeFileLocation = $exeFileLocation
                $this.arguments = $arguments
                if ($runRemotly -like "true") {
                    $this.runRemotly = $True
                }
                else {
                    $this.runRemotly = $False
                }
                $this.remoteTarget = $remoteTarget
            }

            StartProcess() {
                Write-Verbose ("Starting process with exe: " + $this.exeFileLocation + " and arguments: " + $this.arguments)
                [System.Management.Automation.ScriptBlock]$scriptBlock = { 
                    Start-Process -NoNewWindow -FilePath $this.exeFileLocation -ArgumentList $this.arguments -RedirectStandardOutput $this.stdout -RedirectStandardError $this.stderr -ErrorAction Stop -Wait
                }
                $this.errorCode = Execute-Command $scriptBlock $this.remoteTarget $this.runRemotly
                if ($this.errorCode -ne 0) {
                    $this.errorText = $Error[0]
                }
                else {
                    $this.errorText = $null
                }
            }

            [String]ErrorsFound() {
                if ($this.errors -ne $null -and $this.errors -ne 0) {
                    Write-Verbose "Returning true on method call ErrorsFound"
                    return $True
                }
                else {
                    Write-Verbose "Returning false on method call ErrorsFound"
                    return $False
                }
            }

            [bool]CheckStdout([String]$searchFor) {
                if ((Execute-Command { Test-Path $this.stdout } $this.remoteTarget $this.runRemotly) -eq $True) {
                    $this.stdoutContent = Execute-Command { Get-Content $this.stdout } $this.remoteTarget $this.runRemotly
                    Write-Verbose ("Standard output content: " + $this.stdoutContent)
                    if ($this.stdoutContent -like $searchFor) {
                        Write-Verbose ("Stndard output content matches search for parameter: " + $searchFor)
                        return $True
                    }
                    else {
                        Write-Verbose ("Stndard output content NOT matches search for parameter: " + $searchFor)
                        return $False
                    }
                }
                Write-Verbose "Stdout file doesn't exists" 
                $this.stdoutContent = $null
                return $False
            }

            [bool]CheckStderr() {
                if ((Execute-Command { Test-Path $this.stderr } $this.remoteTarget $this.runRemotly) -eq $True) {
                    $this.stderrContent = Execute-Command { Get-Content $this.stderr } $this.remoteTarget $this.runRemotly
                    if ($this.stderrContent[0].Length -gt 1) {
                        Write-Verbose ("Standard error content: " + $this.stderrContent)
                        return $True
                    }
                    else {
                        Write-Verbose "Standard error content is empty"
                        return $False
                    }
                }
                Write-Verbose "Stderr file doesn't exists"
                $this.stderrContent = $null
                return $False
            }

            Cleanup() {
                if ((Execute-Command { Test-Path $this.stdout } $this.remoteTarget $this.runRemotly) -eq $True) {
                    Write-Verbose ("Removing " + $this.stdout + " file")
                    Execute-Command { Remove-Item $this.stdout } $this.remoteTarget $this.runRemotly
                }
                if ((Execute-Command { Test-Path $this.stderr } $this.remoteTarget $this.runRemotly) -eq $True) {
                    Write-Verbose ("Removing " + $this.stderr + " file")
                    Execute-Command { Remove-Item $this.stderr } $this.remoteTarget $this.runRemotly
                }
            }
        }

        function Execute-Command([ScriptBlock]$scriptBlock, [String]$target, [Switch]$runRemotly) {
            if ($runRemotly -eq $True) {
                Write-Verbose ("Executing remotly on: " + $this.remoteTarget + " script block: " + $scriptBlock)
                return (Invoke-Command -ComputerName $this.remoteTarget -ScriptBlock $scriptBlock)                    
            }
            else {
                Write-Verbose ("Executing locally script block: " + $scriptBlock)
                return (& $scriptBlock)
            }
        }

        Write-Verbose "Declaring Logger Class"
        Class Logger {
	        [String]$logFileName
	        [String]$logFileLocation

	        Logger([String]$logFIleName, [String]$logFileLocation) {
                Write-Verbose ("Constructing Logger Class instance with parameters 1: " + $logFileName + " 2: " + $logFileLocation)
		        $this.logFileName = $logFileName
		        $this.logFileLocation = $logFileLocation
		        $this.Initialize()
		        $this.AddLog("Log file created.")
	        }

	        Initialize() {
                Write-Verbose "Initializing Logger instance"
		        if (!(Test-Path $this.logFileLocation)) {
                    Write-Verbose "Log file not found, creating a new one"
			        New-item -ItemType File $this.logFileLocation -Force
		        }
	        }

	        AddLog([String]$newLog) {
                Write-Verbose ("Adding a new log: " + $newLog)
		        "[" + (Get-Date) + ":] " + $newLog | Add-Content $this.logFileLocation
	        }
        }

        function Print-Paremeters([System.Array]$input) {
            $log = ""
            $counter = 1;
            foreach ($parameter in $input) {
                $log += (" " + $counter + ": " + $parameter)
            }
            return $log
        }
    }

    PROCESS {
        [Logger]$logger = New-Object Logger($LogFileName, $LogFileLocation) 
        Write-Verbose "Getting content from ini file"
        $iniFile = Get-Content $IniFileLocation
        Write-Verbose "Starting for each loop"
        foreach ($line in $iniFile) {
            Write-Verbose ("Processing line: " + $line)
            $splittedLine = $line.Split("{&}")
            
            $exeFileLocation = $splittedLine[0]
            $arguments = $splittedLine[1]
            $executeRemotly = $splittedLine[2]
            $executionTarget = $splittedLine[3]
            $stdoutMatch = $splittedLine[4]

            [CustomProcess]$customProcess = New-Object CustomProcess($exeFileLocation, $arguments, $executeRemotly, $executionTarget)
            $customProcess.StartProcess()
            if ($customProcess.ErrorsFound() -eq $True) {
                $logger.AddLog("Error code: " + $customProcess.errorCode + ", error text: " + $customProcess.errorCode)
            }
            if ($customProcess.CheckStderr() -eq $True) {
                $logger.AddLog("Process with parameters" + (Print-Paremeters $splittedLine) + " exited with standard error: " + $customProcess.stderrContent)
            }
            if ($customProcess.CheckStdout($stdoutMatch)) {
                $logger.AddLog("Process with parameters" + (Print-Paremeters $splittedLine) + " not matching expected standard output content. Expected: " + $stdoutMatch + " found: " + $customProcess.stdoutContent)
            }
            $customProcess.Cleanup()
        }
    }

    END {
        Write-Verbose "The end of script execution"
    }
}
