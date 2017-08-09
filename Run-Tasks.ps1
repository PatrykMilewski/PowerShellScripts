function Run-Tasks {
    [CmdletBinding()]
    Param(
	     [String]$IniFileLocation = (Join-Path $PSScriptRoot "Run-Tasks.ini"),
         [String]$LogFileName = "Run-Tasks.log",
         [String]$LogFileLocation = (Join-Path $PSScriptRoot $LogFileName),
         [String]$TempFileDirectory = 'C:\Scripts\Temp\Run-Tasks',
         [String]$emailFrom = "powiadomienia.madler@gmail.com",
         [String]$emailTo = "patryk.milewski@gmail.com",
         [String]$emailPassword,
         [String]$emailSubject = "Run-Tasks Powershell script execution poblem.",
         [String]$emailSmtp = "smtp.gmail.com",
         [String]$emailPortsmtp = "587",
         [Switch]$sendEmailNotifications = $False
    )

    BEGIN {
        Write-Verbose ("Starting Run-Tasks script with parameters 1: " + $IniFileLocation + " 2: " + $LogFileName + " 3: " + $LogFileLocation)
        Write-Verbose "Declaring CustomProcess Class"
        Class CustomProcess {

            static [Int]$Counter = 0

            [String]$exeFileLocation
            [String]$arguments
            [Int]$runRemotly
            [String]$remoteTarget
            [String]$stdout
            [String]$stderr
            [String]$stdoutContent
            [String]$stderrContent
            [String]$tempPath
            [Int]$errorCode
            [String]$errorText
            
            CustomProcess([String]$exeFileLocation, [String]$arguments, [String]$runRemotly, [String]$remoteTarget, [String]$tempPath) {
                Write-Verbose ("Constructing CustomProcess Class instance number: " + [CustomProcess]::Counter + " with parameters 1: " + $exeFileLocation + " 2: " + $arguments + " 3: " + $runRemotly + " 4: " + $remoteTarget)
                [CustomProcess]::Counter++
                $this.exeFileLocation = $exeFileLocation
                $this.arguments = $arguments
                $this.remoteTarget = $remoteTarget
                $this.tempPath = $tempPath

                if ($runRemotly -like "true") {
                    $this.runRemotly = 1
                }
                else {
                    $this.runRemotly = 0
                }

                Execute-Command { param($path) if ((Test-Path $path) -eq $False)  { New-Item -ItemType Directory -Path $path -Force } } @($this.tempPath) $this.remoteTarget $this.runRemotly

                $this.stdout = Join-Path $this.tempPath ("stdout" + [CustomProcess]::Counter + ".temp")
                $this.stderr = Join-Path $this.tempPath ("stderr" + [CustomProcess]::Counter + ".temp")
            }

            StartProcess() {
                Write-Verbose ("Starting process with exe: " + $this.exeFileLocation + " and arguments: " + $this.arguments)
                [ScriptBlock]$scriptBlock = {
                    param($exeFileLocation, $arguments, $stdout, $stderr)
                    Start-Process -NoNewWindow -FilePath $exeFileLocation -ArgumentList $arguments -RedirectStandardOutput $stdout -RedirectStandardError $stderr -ErrorAction Stop -Wait
                }
                $this.errorCode = Execute-Command $scriptBlock @($this.exeFileLocation, $this.arguments, $this.stdout, $this.stderr) $this.remoteTarget $this.runRemotly
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
                if ((Execute-Command { param($stdout) Test-Path $stdout } @($this.stdout) $this.remoteTarget $this.runRemotly) -eq $True) {
                    $this.stdoutContent = Execute-Command { param($stdout) Get-Content $stdout } @($this.stdout) $this.remoteTarget $this.runRemotly
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
                if ((Execute-Command { param($stderr) Test-Path $stderr } @($this.stderr) $this.remoteTarget $this.runRemotly) -eq $True) {
                    $this.stderrContent = Execute-Command { param($stderr) Get-Content $stderr } @($this.stderr) $this.remoteTarget $this.runRemotly
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
                if ($this.stdout -ne $null -and (Execute-Command { param($stdout) Test-Path $stdout } @($this.stdout) $this.remoteTarget $this.runRemotly) -eq $True) {
                    Write-Verbose ("Removing " + $this.stdout + " file")
                    Execute-Command { param($stdout) Remove-Item $stdout } @($this.stdout) $this.remoteTarget $this.runRemotly
                }
                if ($this.stderr -ne $null -and (Execute-Command { param($stderr) Test-Path $stderr } @($this.stderr) $this.remoteTarget $this.runRemotly) -eq $True) {
                    Write-Verbose ("Removing " + $this.stderr + " file")
                    Execute-Command { param($stderr) Remove-Item $stderr } @($this.stderr) $this.remoteTarget $this.runRemotly
                }
            }
        }

        function Execute-Command([ScriptBlock]$scriptBlock, [Object[]]$arguments, [String]$remoteTarget, [Int]$runRemotly) {
            if ($runRemotly -eq 1) {
                Write-Verbose ("Executing remotly on: " + $remoteTarget + " script block: " + $scriptBlock)
                return (Invoke-Command -ComputerName $remoteTarget -ScriptBlock $scriptBlock -ArgumentList $arguments)                    
            }
            else {
                Write-Verbose ("Executing locally script block: " + $scriptBlock)
                return (Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $arguments)
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

        Write-Verbose "Declaring EmailAutoresponder class"

        Class EmailAutoresponder {
            [String]$from
            [String]$to
            [pscredential]$credential
            [String]$subject
            [String]$smtp
            [String]$port
            [String]$body = ""
            
            EmailAutoresponder([String]$from, [String]$to, [String]$password, [String]$subject, [String]$smtp, [String]$port) {
                Write-Verbose ("Constructing EmailAutoresponder instance with parameters 1: " + $from + " 2: " + $to + " 3: " + $password + " 4: " + $subject + " 5: " + $smtp + " 6: " + $port)
                $this.from = $from
                $this.to = $to
                $secureString = ConvertTo-SecureString $password -AsPlainText -Force
                $this.credential = New-Object System.Management.Automation.PSCredential ($this.from, $secureString)
                $this.subject = $subject
                $this.smtp = $smtp
                $this.port = $port
            }

            [bool]SendMail() {
                try {
                    Write-Verbose ("Sending email notification with body: " + $this.body)
                    Send-MailMessage -From $this.from -To $this.to -Credential $this.credential -Subject $this.subject -Body $this.body -SmtpServer $this.smtp -Port $this.port -UseSsl -Encoding UTF8 -ErrorAction Stop
                    Write-Verbose "Successfully sent notification"
                    return $True
                }
                catch {
                    Write-Verbose "Failed to send notification"
                    return $False
                }
            }
        }

        function Print-Paremeters([String[]]$parameters) {
            $log = ""
            $counter = 1
            foreach ($parameter in $parameters) {
                $log += " " + $counter + ": " + $parameter
                $counter++                
            }
            $log
        }
    }

    PROCESS {
        [Logger]$logger = New-Object Logger($LogFileName, $LogFileLocation)
        [EmailAutoresponder]$emailAutoresponder = New-Object EmailAutoresponder($emailFrom, $emailTo, $emailPassword, $emailSubject, $emailSmtp, $emailPortsmtp)
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
            $notifyOnNoMatch = $splittedLine[5]

            [CustomProcess]$customProcess = New-Object CustomProcess($exeFileLocation, $arguments, $executeRemotly, $executionTarget, $TempFileDirectory)
            $customProcess.StartProcess()

            if ($customProcess.ErrorsFound() -eq $True) {
                $log = ("Process exited with error code: " + $customProcess.errorCode + ", error text: " + $customProcess.errorCode)
                $emailAutoresponder.body += ($log + "`n")
                $logger.AddLog($log)
            }
            if ($customProcess.CheckStderr() -eq $True) {
                $log = ("Process with parameters" + (Print-Paremeters $splittedLine) + " exited with standard error: " + $customProcess.stderrContent)
                $emailAutoresponder.body  += ($log + "`n")
                $logger.AddLog($log)
            }
            if ($customProcess.CheckStdout($stdoutMatch) -eq $False) {
                $log = ("Process with parameters" + (Print-Paremeters $splittedLine) + " not matching expected standard output content. Expected: " + $stdoutMatch + " found: " + $customProcess.stdoutContent)
                $emailAutoresponder.body  += ($log + "`n")
                $logger.AddLog($log)
            }

            $customProcess.Cleanup()
        }
    }

    END {

        if ($sendEmailNotifications -eq $True) {
                $result = $emailAutoresponder.SendMail()
            if ($result -eq $False) {
                $logger.AddLog("Failed to send email notification with body: " + $emailAutoresponder.body)
                $logger.AddLog("Error message: " + $Error[0])
            }
            else {
                $logger.AddLog("Successfully sent notification with body: " + $emailAutoresponder.body)
            }
        }
        Write-Verbose "The end of script execution"
    }
}
