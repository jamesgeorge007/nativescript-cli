
# A PowerShell script to set up Windows machine for NativeScript development
# NOTE: The scripts requires at least a version 4.0 .NET framework installed
# To run it inside a COMMAND PROMPT against the production branch (only one supported with self-elevation) use
# @powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((new-object net.webclient).DownloadString('https://raw.githubusercontent.com/NativeScript/nativescript-cli/production/setup/native-script.ps1'))"
# To run it inside a WINDOWS POWERSHELL console against the production branch (only one supported with self-elevation) use
# iex ((new-object net.webclient).DownloadString('https://raw.githubusercontent.com/NativeScript/nativescript-cli/production/setup/native-script.ps1'))

# Check if latest .NET framework installed is at least 4
$dotNetVersions = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse | Get-ItemProperty -name Version,Release -EA 0 | Where { $_.PSChildName -match '^(?!S)\p{L}'} | Select Version
$latestDotNetVersion = $dotNetVersions.GetEnumerator() | Sort-Object Version | Select-Object -Last 1
$latestDotNetMajorNumber = $latestDotNetVersion.Version.Split(".")[0]
if ($latestDotNetMajorNumber -lt 4) {
	Write-Host -ForegroundColor Red "To run this script, you need .NET 4.0 or later installed"
	if ((Read-Host "Do you want to open Microsoft Download Center (y/n)") -eq 'y') {
		Start-Process -FilePath "https://www.microsoft.com/en-us/download/search.aspx?q=.net%20framework&p=0&r=10&t=&s=Relevancy~Descending"
	}

	exit 1
}

# Self-elevate
$isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
if (-not $isElevated) {
	start-process -FilePath PowerShell.exe -Verb Runas -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command iex ((new-object net.webclient).DownloadString('https://raw.githubusercontent.com/NativeScript/nativescript-cli/production/setup/native-script.ps1'))"
	exit 0
}

# Help with installing other dependencies
$script:answer = ""
function Install($programName, $message, $script, $shouldExit) {
	if ($script:answer -ne "a") {
		Write-Host -ForegroundColor Green "Allow the script to install $($programName)?"
		Write-Host "Tip: Note that if you type a you won't be prompted for subsequent installations"
		do {
			$script:answer = (Read-Host "(Y)es/(N)o/(A)ll").ToLower()
		} until ($script:answer -eq "y" -or $script:answer -eq "n" -or $script:answer -eq "a")

		if ($script:answer -eq "n") {
			Write-Host -ForegroundColor Yellow "You have chosen not to install $($programName). Some features of NativeScript may not work correctly if you haven't already installed it"
			return
		}
	}

	Write-Host $message
	Invoke-Expression($script)
	if ($LASTEXITCODE -ne 0) {
		Write-Host -ForegroundColor Yellow "WARNING: $($programName) not installed"
	}
}

function Pause {
	Write-Host "Press any key to continue..."
	[void][System.Console]::ReadKey($true)
}

# Actually installing all other dependencies
# Install Chocolately
Install "Chocolately(It's mandatory for the rest of the script)" "Installing Chocolately" "iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))"

if ((Get-Command "cinst" -ErrorAction SilentlyContinue) -eq $null) {
	Write-Host -ForegroundColor Red "Chocolatey is not installed or not configured properly. Download it from https://chocolatey.org/, install, set it up and run this script again."
	Pause
	exit 1
}

# Install dependenciess with Chocolately

Install "Google Chrome" "Installing Google Chrome (required to debug NativeScript apps)" "cinst googlechrome --force --yes"

Install "Java Development Kit" "Installing Java Development Kit" "cinst jdk8 --force --yes"

Install "Android SDK" "Installing Android SDK" "cinst android-sdk --force --yes"

# setup android sdk
echo yes | cmd /c "$env:localappdata\Android\android-sdk\tools\android" update sdk --filter "tools,platform-tools,android-23" --all --no-ui
echo yes | cmd /c "$env:localappdata\Android\android-sdk\tools\android" update sdk --filter "build-tools-23.0.1,extra-android-m2repository" --all --no-ui

# setup environment

if (!$env:ANDROID_HOME) {
	[Environment]::SetEnvironmentVariable("ANDROID_HOME", "$env:localappdata\Android\android-sdk", "User")
	$env:ANDROID_HOME = "$env:localappdata\Android\android-sdk";
}

if (!$env:JAVA_HOME) {
	$curVer = (Get-ItemProperty "HKLM:\SOFTWARE\JavaSoft\Java Development Kit").CurrentVersion
	$javaHome = (Get-ItemProperty "HKLM:\Software\JavaSoft\Java Development Kit\$curVer").JavaHome
	[Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "User")
	$env:JAVA_HOME = $javaHome;
}

Write-Host -ForegroundColor Green "This script has modified your environment. You need to log off and log back on for the changes to take effect."
Pause