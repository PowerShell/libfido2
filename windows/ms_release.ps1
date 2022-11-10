# Copyright (c) 2021 Yubico AB. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

$ErrorActionPreference = "Stop"
$Architectures = @('x64', 'Win32', 'ARM64', 'ARM')
$InstallPrefixes =  @('Win64', 'Win32', 'ARM64', 'ARM')
$Types = @('static')
$Config = 'Release'
$LibCrypto = '46'
$SDK = '142'

. "$PSScriptRoot\ms_const.ps1"

Remove-Item -Recurse -Force -Path "${OUTPUT}" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -Path "${BUILD}" -ErrorAction SilentlyContinue

foreach ($Arch in $Architectures) {
	foreach ($Type in $Types) {
		./ms_build.ps1 -Arch ${Arch} -Type ${Type} -Config ${Config}
	}
}

foreach ($InstallPrefix in $InstallPrefixes) {
	foreach ($Type in $Types) {
		New-Item -Type Directory `
		    "${OUTPUT}/pkg/${InstallPrefix}/${Config}/${Type}"
	}
}

Function Package-Headers() {
	Copy-Item "${OUTPUT}\x64\dynamic\include" -Destination "${OUTPUT}\pkg" `
	    -Recurse -ErrorAction Stop
}

Function Package-StaticHeaders() {
	Copy-Item "${OUTPUT}\x64\static\include" -Destination "${OUTPUT}\pkg" `
	    -Recurse -Force -ErrorAction Stop
}

Function Package-Dynamic(${SRC}, ${DEST}) {
	Copy-Item "${SRC}\bin\cbor.dll" "${DEST}"
	Copy-Item "${SRC}\lib\cbor.lib" "${DEST}"
	Copy-Item "${SRC}\bin\zlib1.dll" "${DEST}"
	Copy-Item "${SRC}\lib\zlib.lib" "${DEST}"
	Copy-Item "${SRC}\bin\crypto-${LibCrypto}.dll" "${DEST}"
	Copy-Item "${SRC}\lib\crypto-${LibCrypto}.lib" "${DEST}"
	Copy-Item "${SRC}\bin\fido2.dll" "${DEST}"
	Copy-Item "${SRC}\lib\fido2.lib" "${DEST}"
}

Function Package-Static(${SRC}, ${DEST}) {
	Copy-Item "${SRC}/lib/cbor.lib" "${DEST}"
	Copy-Item "${SRC}/lib/fido2_static.lib" "${DEST}/fido2.lib"
}

Function Package-PDBs(${SRC}, ${DEST}) {
	Copy-Item "${SRC}\${LIBRESSL}\crypto\crypto.dir\${Config}\vc${SDK}.pdb" `
	    "${DEST}\crypto-${LibCrypto}.pdb"
	Copy-Item "${SRC}\${LIBCBOR}\src\cbor.dir\${Config}\vc${SDK}.pdb" `
	    "${DEST}\cbor.pdb"
	Copy-Item "${SRC}\${ZLIB}\zlib.dir\${Config}\vc${SDK}.pdb" `
	    "${DEST}\zlib.pdb"
	Copy-Item "${SRC}\src\fido2_shared.dir\${Config}\vc${SDK}.pdb" `
	    "${DEST}\fido2.pdb"
}

Function Package-StaticPDBs(${SRC}, ${DEST}) {
	Copy-Item "${SRC}\libcbor\src\cbor.dir\Release\cbor.pdb" `
	    "${DEST}\cbor.pdb"
	Copy-Item "${SRC}\src\fido2.dir\Release\fido2.pdb" `
	    "${DEST}\fido2.pdb"
}

Function Package-Tools(${SRC}, ${DEST}) {
	Copy-Item "${SRC}\tools\${Config}\fido2-assert.exe" `
	    "${DEST}\fido2-assert.exe"
	Copy-Item "${SRC}\tools\${Config}\fido2-cred.exe" `
	    "${DEST}\fido2-cred.exe"
	Copy-Item "${SRC}\tools\${Config}\fido2-token.exe" `
	    "${DEST}\fido2-token.exe"
}

for ($i = 0; $i -lt $Architectures.Length; $i++) {
	$Arch = $Architectures[$i]
	$InstallPrefix = $InstallPrefixes[$i]

    # remove cbor headers from libfido2 release
    Remove-Item -Recurse -Path "${OUTPUT}\${Arch}\static\include" -Include "cbor*"

    if ($Types -contains 'dynamic')
    {
        Package-Dynamic "${OUTPUT}\${Arch}\dynamic" `
            "${OUTPUT}\pkg\${InstallPrefix}\${Config}\dynamic"
        Package-PDBs "${BUILD}\${Arch}\dynamic" `
            "${OUTPUT}\pkg\${InstallPrefix}\${Config}\dynamic"
        Package-Tools "${BUILD}\${Arch}\dynamic" `
            "${OUTPUT}\pkg\${InstallPrefix}\${Config}\dynamic"

        Package-Headers
    }

    if ($Types -contains 'static')
    {
        Package-Static "${OUTPUT}\${Arch}\static" `
            "${OUTPUT}\pkg\${InstallPrefix}\${Config}\static"
        Package-StaticPDBs "${BUILD}\${Arch}\static" `
            "${OUTPUT}\pkg\${InstallPrefix}\${Config}\static"

        Package-StaticHeaders
    }
}
