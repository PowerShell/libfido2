# Copyright (c) 2021 Yubico AB. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

param(
	[string]$CMakePath = "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe",
	[string]$GitPath = "C:\Program Files\Git\bin\git.exe",
	[string]$WinSDK = "",
	[string]$Config = "Release",
	[string]$Arch = "x64",
	[string]$Type = "dynamic",
	[string]$Fido2Flags = ""
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

. "$PSScriptRoot\ms_const.ps1"

Function ExitOnError() {
	if ($LastExitCode -ne 0) {
		throw "A command exited with status $LastExitCode"
	}
}

Function GitClone(${REPO}, ${BRANCH}, ${DIR}) {
	Write-Verbose -Verbose "Cloning ${REPO}..."
	& $Git -c advice.detachedHead=false clone --quiet --depth=1 `
	    --branch "${BRANCH}" "${REPO}" "${DIR}"
    Write-Verbose -Verbose "${REPO}'s ${BRANCH} HEAD is:"
	& $Git -C "${DIR}" show -s HEAD
}

# Find Git.
$Git = $(Get-Command git -ErrorAction Ignore | `
    Select-Object -ExpandProperty Source)
if ([string]::IsNullOrEmpty($Git)) {
	$Git = $GitPath
}
if (-Not (Test-Path $Git)) {
	throw "Unable to find Git at $Git"
}

# Find CMake.
$CMake = $(Get-Command cmake -ErrorAction Ignore | `
    Select-Object -ExpandProperty Source)
if ([string]::IsNullOrEmpty($CMake)) {
	$CMake = $CMakePath
}
if (-Not (Test-Path $CMake)) {
	throw "Unable to find CMake at $CMake"
}

# Override CMAKE_SYSTEM_VERSION if $WinSDK is set.
<#if (-Not ([string]::IsNullOrEmpty($WinSDK))) {
	$CMAKE_SYSTEM_VERSION = "-DCMAKE_SYSTEM_VERSION='$WinSDK'"
} else {
	$CMAKE_SYSTEM_VERSION = ''
}#>

Write-Host "WinSDK: $WinSDK"
Write-Host "Config: $Config"
Write-Host "Arch: $Arch"
Write-Host "Type: $Type"
Write-Host "Git: $Git"
Write-Host "CMake: $CMake"

# Create build directories.
New-Item -Type Directory "${BUILD}" -Force
New-Item -Type Directory "${BUILD}\${Arch}" -Force
New-Item -Type Directory "${BUILD}\${Arch}\${Type}" -Force
New-Item -Type Directory "${STAGE}\${LIBCBOR}" -Force

# Create output directories.
New-Item -Type Directory "${OUTPUT}" -Force
New-Item -Type Directory "${OUTPUT}\${Arch}" -Force
New-Item -Type Directory "${OUTPUT}\${Arch}\${Type}" -force

# Fetch and verify dependencies.
Push-Location ${BUILD}
try {
    Invoke-WebRequest ${LIBRESSL_BIN_URL} -OutFile .\${LIBRESSL}.zip
    Expand-Archive -Path .\${LIBRESSL}.zip -DestinationPath "." -Force
    Remove-Item -Force .\${LIBRESSL}.zip

    GitClone "${LIBCBOR_GIT}" "${LIBCBOR_BRANCH}" ".\${LIBCBOR}"

    Invoke-WebRequest ${ZLIB_BIN_URL} -OutFile .\${ZLIB}.zip
    Expand-Archive -Path .\${ZLIB}.zip -DestinationPath "." -Force
    Remove-Item -Force .\${ZLIB}.zip
} catch {
	throw "Failed to fetch and verify dependencies"
} finally {
	Pop-Location
}

# Build libcbor.
Push-Location ${STAGE}\${LIBCBOR}
try {
	& $CMake ..\..\..\${LIBCBOR} -A "${Arch}" `
	    -DWITH_EXAMPLES=OFF `
	    -DBUILD_SHARED_LIBS="${SHARED}" `
	    -DCMAKE_C_FLAGS_DEBUG="${CFLAGS_DEBUG}" `
	    -DCMAKE_C_FLAGS_RELEASE="${CFLAGS_RELEASE}" `
	    -DCMAKE_INSTALL_PREFIX="${PREFIX}"; `
	    ExitOnError
	& $CMake --build . --config ${Config} --verbose; ExitOnError
	& $CMake --build . --config ${Config} --target install --verbose; `
	    ExitOnError
} catch {
	throw "Failed to build libcbor"
} finally {
	Pop-Location
}

# Build libfido2.
Push-Location ${STAGE}
try {
	& $CMake ..\..\.. -A "${Arch}" `
        -DBUILD_EXAMPLES=OFF `
        -DBUILD_TOOLS=OFF `
	    -DCMAKE_BUILD_TYPE="${Config}" `
	    -DBUILD_SHARED_LIBS="${SHARED}" `
	    -DCBOR_INCLUDE_DIRS="${PREFIX}\include" `
	    -DCBOR_LIBRARY_DIRS="${PREFIX}\lib" `
	    -DCBOR_BIN_DIRS="${PREFIX}\bin" `
	    -DZLIB_INCLUDE_DIRS="${BUILD}\${ZLIB}\sdk" `
	    -DZLIB_LIBRARY_DIRS="${BUILD}\${ZLIB}\bin\${Arch}" `
	    -DZLIB_BIN_DIRS="${PREFIX}\bin" `
	    -DCRYPTO_INCLUDE_DIRS="${BUILD}\LibreSSL\sdk\include" `
	    -DCRYPTO_LIBRARY_DIRS="${PREFIX}\lib" `
	    -DCRYPTO_BIN_DIRS="${PREFIX}\bin" `
	    -DCMAKE_C_FLAGS_DEBUG="${CFLAGS_DEBUG} ${Fido2Flags}" `
	    -DCMAKE_C_FLAGS_RELEASE="${CFLAGS_RELEASE} ${Fido2Flags}" `
	    -DCMAKE_INSTALL_PREFIX="${PREFIX}"; `
	    ExitOnError
	& $CMake --build . --config ${Config} --verbose; ExitOnError
	& $CMake --build . --config ${Config} --target install --verbose; `
	    ExitOnError
} catch {
	throw "Failed to build libfido2"
} finally {
	Pop-Location
}
