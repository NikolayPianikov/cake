<#
.SYNOPSIS
This is a Powershell script to bootstrap a Cake build.
.DESCRIPTION
This Powershell script will download NuGet if missing, restore NuGet tools (including Cake)
and execute your Cake build script with the parameters you provide.
.PARAMETER Target
The build script target to run.
.PARAMETER Configuration
The build configuration to use.
.PARAMETER Verbosity
Specifies the amount of information to be displayed.
.PARAMETER WhatIf
Performs a dry run of the build script.
No tasks will be executed.
.PARAMETER ScriptArgs
Remaining arguments are added here.
.LINK
http://cakebuild.net
#>

[CmdletBinding()]
Param(
    [string]$Target = "Default",
    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release",
    [ValidateSet("Quiet", "Minimal", "Normal", "Verbose", "Diagnostic")]
    [string]$Verbosity = "Verbose",
    [switch]$WhatIf,
    [Parameter(Position=0,Mandatory=$false,ValueFromRemainingArguments=$true)]
    [string[]]$ScriptArgs
)

$CakeVersion = "0.15.2"
$DotNetChannel = "preview";
$DotNetVersion = "1.0.0-preview2-003121";
$DotNetInstallerUri = "https://raw.githubusercontent.com/dotnet/cli/rel/1.0.0-preview2/scripts/obtain/dotnet-install.ps1";
$NugetUrl = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"

# Make sure tools folder exists
$PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
$ToolPath = Join-Path $PSScriptRoot "tools"
if (!(Test-Path $ToolPath)) {
    Write-Verbose "Creating tools directory..."
    New-Item -Path $ToolPath -Type directory | out-null
}

###########################################################################
# INSTALL .NET CORE CLI
###########################################################################

# Get .NET Core CLI path if installed.
$DotNetCliPath = $null;
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    $Version = dotnet --version;
    if($Version -eq $DotNetVersion) {
        $DotNetCliPath = (Get-Command dotnet).Path; 
    }
}

# Install .NET Core CLI?
if([string]::IsNullOrWhiteSpace($DotNetCliPath)) {
    if (!(Test-Path $InstallPath)) {
        mkdir -Force $InstallPath | Out-Null;
    }
    Invoke-WebRequest $DotNetInstallerUri -OutFile "$InstallPath\dotnet-install.ps1"
    & $InstallPath\dotnet-install.ps1 -Channel $DotNetChannel -Version $DotNetVersion -InstallDir $InstallPath -NoPath;
    $DotNetCliPath = "$InstallPath\dotnet.exe";
}

###########################################################################
# INSTALL NUGET
###########################################################################

# Make sure nuget.exe exists.
$NugetPath = Join-Path $ToolPath "nuget.exe" 
if (!(Test-Path $NugetPath)) {
    Write-Host "Downloading NuGet.exe..."
    (New-Object System.Net.WebClient).DownloadFile($NugetUrl, $NugetPath);
}

###########################################################################
# INSTALL CAKE
###########################################################################

# Make sure Cake has been installed.
$CakePath = Join-Path $ToolPath "Cake.$CakeVersion/Cake.exe"
if (!(Test-Path $CakePath)) {
    Write-Host "Installing Cake..."
    Invoke-Expression "&`"$NugetPath`" install Cake -Version $CakeVersion -OutputDirectory `"$ToolPath`"" | Out-Null;
    if ($LASTEXITCODE -ne 0) {
        Throw "An error occured while restoring Cake from NuGet."
    }
}

###########################################################################
# RUN BUILD SCRIPT
###########################################################################

# Build the argument list.
$Arguments = @{
    target=$Target;
    configuration=$Configuration;
    verbosity=$Verbosity;
    dryrun=$WhatIf;
    dotnet=$DotNetCliPath;
}.GetEnumerator() | %{"--{0}=`"{1}`"" -f $_.key, $_.value };

# Start Cake
Write-Host "Running build script..."
Invoke-Expression "& `"$CakePath`" `"build.cake`" $Arguments $ScriptArgs"
exit $LASTEXITCODE