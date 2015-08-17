#!/bin/bash
# hdaInjector.sh - Script to create an AppleHDA injector for desktop audio codecs common on several Gigabyte boards

# Initialize global variables

## The script version
gScriptVersion="0.1"

## The user ID
gID=$(id -u)

## The audio codec
gCodec="Unknown"
## The audio codec's hex identifier
gCodecHex="0x00000000"
## The audio codec's decimal identifier
gCodecDec="000000000"
## The audio codec's short name (e.g. Realtek ALC898 > ALC898)
gCodecShort="Unknown"
## The audio codec's model (e.g. Realtek ALC898 > 898)
gCodecModel="0000"

## Path to /Library/Extensions
gExtensionsDir="/Library/Extensions"
## Path to /System/Library/Extensions
gSystemExtensionsDir="/System/Library/Extensions"
## Path to AppleHDA.kext
gKextPath="$gSystemExtensionsDir/AppleHDA.kext"

## Name of the injector kext that will be created & installed
gInjectorKextPath="AppleHDAUnknown.kext"

function _getAudioCodec()
{
	# Initialize variables
	gCodecHex=$(ioreg -rxn IOHDACodecDevice | grep VendorID | awk '{ print $4 }' | sed 's/ffffffff//' | grep '0x10ec\|0x1106')
	gCodecDec=$(echo $((16#$(echo $gCodecHex | sed 's/0x//'))))

	# Identify the codec
	if [[ ! -z $gCodecHex ]]; then
		case $gCodecDec in
			283904146) gCodec="Realtek ALC892";;
			283904153) gCodec="Realtek ALC898";;
			283904256) gCodec="Realtek ALC1150";;
			285606977) gCodec="VIA VT2021";;
			*) echo "ERROR: Unsupported audio codec ($gCodecHex / $gCodecDec)." && exit 1;;
		esac
	else
		echo "ERROR: No audio codec found in IORegistry." && exit 1
	fi

	# Initialize more variables
	gCodecShort=$(echo $gCodec | cut -d ' ' -f 2)
	gCodecModel=$(echo $gCodecShort | tr -d '[:alpha:]')
	gInjectorKextPath="AppleHDA$gCodecModel.kext"

	# Print information about the codec
	echo "$gCodec ($gCodecHex) / ($gCodecDec) detected."
}

function _downloadCodecFiles()
{
	# Initialize variables
	fileName="$gCodecShort.zip"
	# Download the ZIP containing the codec XML/plist files
	curl --output "/tmp/$fileName" --progress-bar --location https://github.com/theracermaster/hdaInjector.sh/blob/master/Codecs/$fileName?raw=true
	# Download the plist containing the kext patches
	curl --output "/tmp/ktp.plist" --progress-bar --location https://github.com/theracermaster/hdaInjector.sh/blob/master/Patches/$gCodecShort.plist?raw=true
	# Extract the codec XML/plist files
	unzip "/tmp/$fileName" -d /tmp
	# Check that the command executed successfully
	if [ $? -ne 0 ]; then
		echo "ERROR: Failed to download codec files." && exit 1
	fi
}

function _createKext()
{
	# Create kext directories
	mkdir -p "$gInjectorKextPath/Contents/MacOS"
	mkdir -p "$gInjectorKextPath/Contents/Resources"

	# Create a symbolic link to AppleHDA
	ln -s "$gKextPath/Contents/MacOS/AppleHDA" "$gInjectorKextPath/Contents/MacOS"

	# Copy XML files to kext directory
	cp /tmp/$gCodecShort/*.zlib "$gInjectorKextPath/Contents/Resources"
}

function _createInfoPlist()
{
	# Initialize variables
	plist="$gInjectorKextPath/Contents/Info.plist"
	hdacd="/tmp/$gCodecShort/hdacd.plist"

	# Copy plist from AppleHDA
	cp "$gKextPath/Contents/Info.plist" "$plist"

	# Change version number of AppleHDA injector kext so it is loaded instead of stock AppleHDA
	replace=`/usr/libexec/plistbuddy -c "Print :NSHumanReadableCopyright" $plist | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
	/usr/libexec/plistbuddy -c "Set :NSHumanReadableCopyright '$replace'" $plist
	replace=`/usr/libexec/plistbuddy -c "Print :CFBundleGetInfoString" $plist | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
	/usr/libexec/plistbuddy -c "Set :CFBundleGetInfoString '$replace'" $plist
	replace=`/usr/libexec/plistbuddy -c "Print :CFBundleVersion" $plist | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
	/usr/libexec/plistbuddy -c "Set :CFBundleVersion '$replace'" $plist
	replace=`/usr/libexec/plistbuddy -c "Print :CFBundleShortVersionString" $plist | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
	/usr/libexec/plistbuddy -c "Set :CFBundleShortVersionString '$replace'" $plist

	# Merge the HDA Config Default from the codec's hdacd.plist into the injector's Info.plist
	/usr/libexec/plistbuddy -c "Add ':HardwareConfigDriver_Temp' dict" $plist
	/usr/libexec/plistbuddy -c "Merge /$gKextPath/Contents/PlugIns/AppleHDAHardwareConfigDriver.kext/Contents/Info.plist ':HardwareConfigDriver_Temp'" $plist
	/usr/libexec/plistbuddy -c "Copy ':HardwareConfigDriver_Temp:IOKitPersonalities:HDA Hardware Config Resource' ':IOKitPersonalities:HDA Hardware Config Resource'" $plist
	/usr/libexec/plistbuddy -c "Delete ':HardwareConfigDriver_Temp'" $plist
	/usr/libexec/plistbuddy -c "Delete ':IOKitPersonalities:HDA Hardware Config Resource:HDAConfigDefault'" $plist
	/usr/libexec/plistbuddy -c "Delete ':IOKitPersonalities:HDA Hardware Config Resource:PostConstructionInitialization'" $plist
	/usr/libexec/plistbuddy -c "Add ':IOKitPersonalities:HDA Hardware Config Resource:IOProbeScore' integer" $plist
	/usr/libexec/plistbuddy -c "Set ':IOKitPersonalities:HDA Hardware Config Resource:IOProbeScore' 2000" $plist
	/usr/libexec/plistbuddy -c "Merge $hdacd ':IOKitPersonalities:HDA Hardware Config Resource'" $plist
}

function _installKext()
{
	# Initialize variables
	kext="$1"

	# Correct the permissions
	chmod -R 755 "$gInjectorKextPath"
	chown -R 0:0 "$gInjectorKextPath"

	echo "Installing $kext..."
	# Move the kext to /Library/Extensions
	mv "$kext" "$gExtensionsDir"
	# Trigger a kernel cache rebuild
	echo "Triggering a kernel cache rebuild..."
	touch "$gSystemExtensionsDir"
}

function main()
{
	echo "hdaInjector v$gScriptVersion by theracermaster"
	echo "Heavily based off Piker-Alpha's AppleHDA8Series script"
	echo "hdacd.plist & XML files by toleda & Mirone"
	echo "--------------------------------------------------------------------------------"

	_getAudioCodec

	# If a kext already exists, ask the user if we should delete it or keep it
	if [ -d "$gInjectorKextPath" ]; then
		printf "$gInjectorKextPath already exists. Do you want to overwrite it (y/n)? "
		read choice
		case "$choice" in
			y|Y)
				echo "Removing directory..."
				rm -rf "$gInjectorKextPath";;
		esac
	fi

	_downloadCodecFiles
	_createKext
	_createInfoPlist
	_installKext "$gInjectorKextPath"

	# Delete the temp files
	rm -f /tmp/$gCodecShort.zip
	rm -rf /tmp/$gCodecShort
	rm -rf "$gKext"
}

clear

# Check if we are root
if [ $gID -ne 0 ]; then
	# Re-run the script as root
	echo "This script needs to be run as root."
	sudo "$0"
else
	# We are root, so just call the main function
	main
fi

exit 0
