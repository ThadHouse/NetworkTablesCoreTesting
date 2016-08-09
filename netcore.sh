#!/usr/bin/env bash

#exit if any command fails
set -e

debug=false
skipNtCore=false

if [ "$debug" = true ] ; then
  configuration="-c=Release"
else
  configuration="-c=Debug"
fi  

if [ "$debug" = true ] ; then
  libLoc="bin/Debug"
else
  libLoc="bin/Release"
fi  

function Build {
  dotnet restore

  dotnet build ./src/NetworkTables $configuration
  dotnet build ./src/NetworkTables.Core $configuration
}

function Test {
  dotnet restore
  
  # dotnet test ./test/NetworkTables.Test $configuration -f netcoreapp1.0
  
  #if [ "skipNtCore" = false ] ; then
    # dotnet test ./test/NetworkTables.Core.Test $configuration -f netcoreapp1.0
  #fi

 
  
  dotnet build ./test/NetworkTables.Test $configuration -f net451
  
   ls -R | grep ":$" | sed -e 's/:$//' -e 's/[^-][^\/]*\//--/g' -e 's/^/   /' -e 's/-/|/'
  
  mono test/NetworkTables.Test/$libLoc/net451/*/dotnet-test-nunit.exe test/NetworkTables.Test/$libLoc/net451/*/NetworkTables.Test.dll 
  
  #if [ "skipNtCore" = false ] ; then
   # dotnet build ./test/NetworkTables.Core.Test $configuration -f net451
  
    #mono \
    ./test/NetworkTables.Core.Test/$libLoc/net451/*/dotnet-test-nunit.exe \
    ./test/NetworkTables.Core.Test/$libLoc/net451/*/NetworkTables.Core.Test.dll 
  #fi
}

Build
Test
