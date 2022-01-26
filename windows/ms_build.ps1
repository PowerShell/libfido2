# Copyright (c) 2021 Yubico AB. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

param(
	[string]$CMakePath = "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe",
	[string]$GitPath = "C:\Program Files\Git\bin\git.exe",
	[string]$SevenZPath = "C:\Temp\7z-1\7-Zip\7z.exe",
	[string]$GPGPath = "C:\Program Files (x86)\GnuPG\bin\gpg.exe",
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

# Find 7z.
$SevenZ = $(Get-Command 7z -ErrorAction Ignore | `
    Select-Object -ExpandProperty Source)
if ([string]::IsNullOrEmpty($SevenZ)) {
	$SevenZ = $SevenZPath
}
if (-Not (Test-Path $SevenZ)) {
	throw "Unable to find 7z at $SevenZ"
}

# Find GPG.
$GPG = $(Get-Command gpg -ErrorAction Ignore | `
    Select-Object -ExpandProperty Source)
if ([string]::IsNullOrEmpty($GPG)) {
	$GPG = $GPGPath
}
if (-Not (Test-Path $GPG)) {
	throw "Unable to find GPG at $GPG"
}

# Override CMAKE_SYSTEM_VERSION if $WinSDK is set.
if (-Not ([string]::IsNullOrEmpty($WinSDK))) {
	$CMAKE_SYSTEM_VERSION = "-DCMAKE_SYSTEM_VERSION='$WinSDK'"
} else {
	$CMAKE_SYSTEM_VERSION = ''
}

Write-Host "WinSDK: $WinSDK"
Write-Host "Config: $Config"
Write-Host "Arch: $Arch"
Write-Host "Type: $Type"
Write-Host "Git: $Git"
Write-Host "CMake: $CMake"
Write-Host "7z: $SevenZ"
Write-Host "GPG: $GPG"

# Create build directories.
New-Item -Type Directory "${BUILD}" -Force
New-Item -Type Directory "${BUILD}\${Arch}" -Force
New-Item -Type Directory "${BUILD}\${Arch}\${Type}" -Force
#New-Item -Type Directory "${STAGE}\${LIBRESSL}" -Force
New-Item -Type Directory "${STAGE}\${LIBCBOR}" -Force
#New-Item -Type Directory "${STAGE}\${ZLIB}" -Force

# Create output directories.
New-Item -Type Directory "${OUTPUT}" -Force
New-Item -Type Directory "${OUTPUT}\${Arch}" -Force
New-Item -Type Directory "${OUTPUT}\${Arch}\${Type}" -force

# Fetch and verify dependencies.
Push-Location ${BUILD}
try {
	<#if (-Not (Test-Path .\${LIBRESSL})) {
		if (-Not (Test-Path .\${LIBRESSL}.tar.gz -PathType leaf)) {
			Invoke-WebRequest ${LIBRESSL_URL}/${LIBRESSL}.tar.gz `
			    -OutFile .\${LIBRESSL}.tar.gz
		}
		if (-Not (Test-Path .\${LIBRESSL}.tar.gz.asc -PathType leaf)) {
			Invoke-WebRequest ${LIBRESSL_URL}/${LIBRESSL}.tar.gz.asc `
			    -OutFile .\${LIBRESSL}.tar.gz.asc
		}

		Copy-Item "$PSScriptRoot\libressl.gpg" -Destination "${BUILD}"
		& $GPG --list-keys
		& $GPG --quiet --no-default-keyring --keyring ./libressl.gpg `
		    --verify .\${LIBRESSL}.tar.gz.asc .\${LIBRESSL}.tar.gz
		if ($LastExitCode -ne 0) {
			throw "GPG signature verification failed"
		}
		& $SevenZ e .\${LIBRESSL}.tar.gz
		& $SevenZ x .\${LIBRESSL}.tar
		Remove-Item -Force .\${LIBRESSL}.tar
	}#>
    #Start-Sleep -Seconds 20
    #if (-Not (Test-Path .\${LIBRESSL})) {
        Invoke-WebRequest ${LIBRESSL_BIN_URL} -OutFile .\${LIBRESSL}.zip
        Expand-Archive -Path .\${LIBRESSL}.zip -DestinationPath "." -Force
        Remove-Item -Force .\${LIBRESSL}.zip
    #}
	#if (-Not (Test-Path .\${LIBCBOR})) {
		GitClone "${LIBCBOR_GIT}" "${LIBCBOR_BRANCH}" ".\${LIBCBOR}"
	#}
	<#if (-Not (Test-Path .\${ZLIB})) {
		GitClone "${ZLIB_GIT}" "${ZLIB_BRANCH}" ".\${ZLIB}"
	}#>
        Invoke-WebRequest ${ZLIB_BIN_URL} -OutFile .\${ZLIB}.zip
        Expand-Archive -Path .\${ZLIB}.zip -DestinationPath "." -Force
        Remove-Item -Force .\${ZLIB}.zip
} catch {
	throw "Failed to fetch and verify dependencies"
} finally {
	Pop-Location
}

# Build LibreSSL.

<#Push-Location ${BUILD}
try {
    Invoke-WebRequest ${LIBRESSL_BIN_URL} -OutFile .\${LIBRESSL}.zip
    Expand-Archive -Path .\${LIBRESSL}.zip -DestinationPath .
    Remove-Item .\${LIBRESSL}.zip
} catch {
	throw "Failed to fetch binary  dependencies"
} finally {
	Pop-Location
}#>


<#Push-Location ${STAGE}\${LIBRESSL}
try {
	& $CMake ..\..\..\${LIBRESSL} -A "${Arch}" `
	    -DBUILD_SHARED_LIBS="${SHARED}" -DLIBRESSL_TESTS=OFF `
	    -DCMAKE_C_FLAGS_DEBUG="${CFLAGS_DEBUG}" `
	    -DCMAKE_C_FLAGS_RELEASE="${CFLAGS_RELEASE}" `
	    -DCMAKE_INSTALL_PREFIX="${PREFIX}" "${CMAKE_SYSTEM_VERSION}"; `
	    ExitOnError
	& $CMake --build . --config ${Config} --verbose; ExitOnError
	& $CMake --build . --config ${Config} --target install --verbose; `
	    ExitOnError
} catch {
	throw "Failed to build LibreSSL"
} finally {
	Pop-Location
}#>

# Build libcbor.
Push-Location ${STAGE}\${LIBCBOR}
try {
	& $CMake ..\..\..\${LIBCBOR} -A "${Arch}" `
	    -DWITH_EXAMPLES=OFF `
	    -DBUILD_SHARED_LIBS="${SHARED}" `
	    -DCMAKE_C_FLAGS_DEBUG="${CFLAGS_DEBUG}" `
	    -DCMAKE_C_FLAGS_RELEASE="${CFLAGS_RELEASE}" `
	    -DCMAKE_INSTALL_PREFIX="${PREFIX}" "${CMAKE_SYSTEM_VERSION}"; `
	    ExitOnError
	& $CMake --build . --config ${Config} --verbose; ExitOnError
	& $CMake --build . --config ${Config} --target install --verbose; `
	    ExitOnError
} catch {
	throw "Failed to build libcbor"
} finally {
	Pop-Location
}

# Build zlib.

<#Push-Location ${BUILD}
try {
    Invoke-WebRequest ${ZLIB_BIN_URL} -OutFile .\${ZLIB}.zip
    Expand-Archive -Path .\${ZLIB}.zip -DestinationPath .
    Remove-Item .\${ZLIB}.zip
} catch {
	throw "Failed to fetch binary  dependencies"
} finally {
	Pop-Location
}#>

<#Push-Location ${STAGE}\${ZLIB}
try {
	& $CMake ..\..\..\${ZLIB} -A "${Arch}" `
	    -DBUILD_SHARED_LIBS="${SHARED}" `
	    -DCMAKE_C_FLAGS_DEBUG="${CFLAGS_DEBUG}" `
	    -DCMAKE_C_FLAGS_RELEASE="${CFLAGS_RELEASE}" `
	    -DCMAKE_INSTALL_PREFIX="${PREFIX}" "${CMAKE_SYSTEM_VERSION}"; `
	    ExitOnError
	& $CMake --build . --config ${Config} --verbose; ExitOnError
	& $CMake --build . --config ${Config} --target install --verbose; `
	    ExitOnError
	# Patch up zlib's resulting names when built with --config Debug.
	if ("${Config}" -eq "Debug") {
		if ("${Type}" -eq "Dynamic") {
			Copy-Item "${PREFIX}/lib/zlibd.lib" `
			    -Destination "${PREFIX}/lib/zlib.lib" -Force
			Copy-Item "${PREFIX}/bin/zlibd1.dll" `
			    -Destination "${PREFIX}/bin/zlib1.dll" -Force
		} else {
			Copy-Item "${PREFIX}/lib/zlibstaticd.lib" `
			    -Destination "${PREFIX}/lib/zlib.lib" -Force
		}
	}
} catch {
	throw "Failed to build zlib"
} finally {
	Pop-Location
}#>

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
	    -DCMAKE_INSTALL_PREFIX="${PREFIX}" "${CMAKE_SYSTEM_VERSION}"; `
	    ExitOnError
	& $CMake --build . --config ${Config} --verbose; ExitOnError
	& $CMake --build . --config ${Config} --target install --verbose; `
	    ExitOnError
} catch {
	throw "Failed to build libfido2"
} finally {
	Pop-Location
}
