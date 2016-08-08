# Thanks to Andrew Lock for help with this script
# http://andrewlock.net/publishing-your-first-nuget-package-with-appveyor-and-myget/

param (
  [switch]$buildRelease = $false,
  [switch]$build = $false,
  [switch]$test = $false,
  [switch]$skipNtCore = $false,
  [switch]$updatexml = $false,
  [switch]$pack = $false,
  [switch]$debug = $false
)

<#  
.SYNOPSIS
    You can add this to you build script to ensure that psbuild is available before calling
    Invoke-MSBuild. If psbuild is not available locally it will be downloaded automatically.
#>
function EnsurePsbuildInstalled{  
    [cmdletbinding()]
    param(
        [string]$psbuildInstallUri = 'https://raw.githubusercontent.com/ligershark/psbuild/master/src/GetPSBuild.ps1'
    )
    process{
        if(-not (Get-Command "Invoke-MsBuild" -errorAction SilentlyContinue)){
            'Installing psbuild from [{0}]' -f $psbuildInstallUri | Write-Verbose
            (new-object Net.WebClient).DownloadString($psbuildInstallUri) | iex
        }
        else{
            'psbuild already loaded, skipping download' | Write-Verbose
        }

        # make sure it's loaded and throw if not
        if(-not (Get-Command "Invoke-MsBuild" -errorAction SilentlyContinue)){
            throw ('Unable to install/load psbuild from [{0}]' -f $psbuildInstallUri)
        }
    }
}

# Taken from psake https://github.com/psake/psake

<#  
.SYNOPSIS
  This is a helper function that runs a scriptblock and checks the PS variable $lastexitcode
  to see if an error occcured. If an error is detected then an exception is thrown.
  This function allows you to run command-line programs without having to
  explicitly check the $lastexitcode variable.
.EXAMPLE
  exec { svn info $repository_trunk } "Error executing SVN. Please verify SVN command-line client is installed"
#>
function Exec  
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][scriptblock]$cmd,
        [Parameter(Position=1,Mandatory=0)][string]$errorMessage = ($msgs.error_bad_command -f $cmd)
    )
    & $cmd
    if ($lastexitcode -ne 0) {
        throw ("Exec: " + $errorMessage)
    }
}

if ($buildRelease) {
 $revision =  ""
} else {
 $revision = @{ $true = $env:APPVEYOR_BUILD_NUMBER; $false = 1 }[$env:APPVEYOR_BUILD_NUMBER -ne $NULL];
 $revision = "--version-suffix={0:D4}" -f [convert]::ToInt32($revision, 10)
}

if ($debug) {
 $configuration = "-c=Debug"
} else {
 $configuration = "-c=Release"
}

if ($debug) {
     $libLoc = "bin\Debug"
    } else {
     $libLoc = "bin\Release"
    }
    
    
$updatedxml = $false

function UploadAppVeyorTestResults {
 # upload results to AppVeyor
  $wc = New-Object 'System.Net.WebClient'
  $wc.UploadFile("https://ci.appveyor.com/api/testresults/xunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path .\xunit-results.xml))
}

function Build {
  exec { & dotnet restore }
  
  exec { & dotnet build src\NetworkTables $configuration $revision }
  
  exec { & dotnet build src\NetworkTables.Core $configuration $revision }
}

function Test {
  exec { & dotnet restore }

  exec { & dotnet build test\NetworkTables.Test $configuration $revision }
  
  if ($skipNtCore -eq $false) {
    exec { & dotnet build test\NetworkTables.Core.Test $configuration $revision }
  }

  if ($env:APPVEYOR) {
    # Run CodeCov tests using full framework
    exec { & dotnet test test\NetworkTables.Test -f netcoreapp1.0 }
    
    if ($env:APPVEYOR) {
      UploadAppVeyorTestResults
    }
    
    exec { & dotnet test test\NetworkTables.Core.Test netcoreapp1.0 }
    
    if ($env:APPVEYOR) {
      UploadAppVeyorTestResults
    }
    
    $OpenCoverVersion = "4.6.519"
    
    
    # install CodeCov
    .\NuGet.exe install OpenCover -Version $OpenCoverVersion -OutputDirectory buildTemp
    
    .\buildTemp\OpenCover$OpenCoverVersion\tools\OpenCover.Console.exe -register:user -target:nunit3-console.exe -targetargs:".test\NetworkTables.Test\$libLoc\netcoreapp1.0\NetworkTables.Test.dll --framework=net-4.5.1 " -filter:"+[Network*]* -[NetworkTables.T*]*" -excludebyattribute:*.ExcludeFromCodeCoverage* -output:coverage.xml -mergeoutput -returntargetcode
    .\buildTemp\OpenCover$OpenCoverVersion\tools\OpenCover.Console.exe -register:user -target:nunit3-console.exe -targetargs:".test\NetworkTables.Core.Test\$libLoc\netcoreapp1.0\NetworkTables.Core.Test.dll --framework=net-4.5.1 " -filter:"+[Network*]* -[NetworkTables.Core.T*]*" -excludebyattribute:*.ExcludeFromCodeCoverage* -output:coverage.xml -mergeoutput -returntargetcode
    
    nunit3-console.exe test\NetworkTables.Core.Test\$libLoc\netcoreapp1.0\NetworkTables.Core.Test.dll --framework=net-4.5.1 --x86
    
    "SET PATH=C:\\Python34;C:\\Python34\\Scripts;%PATH%"
    
    pip install codecov
    
    codecov -f "coverage.xml"
    
    } else {
    echo "Starting Tests"
     # run all tests using dotnet test runner
    exec { & dotnet test test\NetworkTables.Test }
    
    if ($skipNtCore -eq $false) {
    exec { & dotnet test test\NetworkTables.Core.Test }
    }
  }
}

function Pack { 
  if (Test-Path .\artifacts) { Remove-Item .\artifacts -Force -Recurse }

  exec { & dotnet pack src\NetworkTables $configuration $revision --no-build -o .\artifacts }
  
  exec { & dotnet pack src\NetworkTables.Core $configuration $revision --no-build -o .\artifacts }

  if ($env:APPVEYOR) {
    Get-ChildItem .\artifacts\*.nupkg | % { Push-AppveyorArtifact $_.FullName -FileName $_.Name }
  }
}

function UpdateXml {    
    # Copy built files
    
 
  .\NuGet.exe install EWSoftware.SHFB -Version 2016.4.9 -o buildTemp

   .\NuGet.exe install EWSoftware.SHFB.NETFramework -Version 4.6 -o buildTemp
   
   Copy-Item src\NetworkTables\$libLoc\net451\NetworkTables.dll buildTemp\NetworkTables.dll
   Copy-Item src\NetworkTables\$libLoc\net451\NetworkTables.xml buildTemp\NetworkTables.xml
   
   Copy-Item src\NetworkTables.Core\$libLoc\net451\NetworkTables.Core.dll buildTemp\NetworkTables.Core.dll
   Copy-Item src\NetworkTables.Core\$libLoc\net451\NetworkTables.Core.xml buildTemp\NetworkTables.Core.xml
   
   EnsurePsbuildInstalled
   
   if ($debug) { 
   $sandConfig = "Debug"
   } else {
    $sandConfig = "Release"
   }
   
   Invoke-MsBuild Sandcastle\NetworkTables.NetCore.shfbproj -configuration $sandConfig
   
   Copy-Item Sandcastle\Help\NetworkTables.xml src\NetworkTables\$libLoc\net451\NetworkTables.xml
   Copy-Item Sandcastle\Help\NetworkTables.xml src\NetworkTables\$libLoc\netstandard1.3\NetworkTables.xml
   
   Invoke-MsBuild Sandcastle\NetworkTables.Core.NetCore.shfbproj -configuration $sandConfig
   
   Copy-Item Sandcastle\Help\NetworkTables.Core.xml src\NetworkTables.Core\$libLoc\net451\NetworkTables.Core.xml
   Copy-Item Sandcastle\Help\NetworkTables.Core.xml src\NetworkTables.Core\$libLoc\netstandard1.5\NetworkTables.Core.xml
}

function Zip {
#TODO
}

if ($build) {
 Build
}

if ($test) {
 Test
}

if ($updatexml) {
 UpdateXml
}

if ($pack) {
 Pack
}