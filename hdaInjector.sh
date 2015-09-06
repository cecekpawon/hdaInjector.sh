#!/bin/bash
# hdaInjector.sh - Script to create an AppleHDA injector for audio codecs common on several desktop motherboards

# Initialize global variables

## The script version
gScriptVersion="0.2-desktop"

## The user ID
gID=$(id -u)

## The audio codec
gCodec="Unknown"
## The audio codec's hex identifier
gCodecIDHex="0x00000000"
## The audio codec's decimal identifier
gCodecIDDec="000000000"
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

## Styling stuff
STYLE_RESET="\e[0m"
STYLE_BOLD="\e[1m"
STYLE_UNDERLINED="\e[4m"

## Color stuff
COLOR_BLACK="\e[1m"
COLOR_RED="\e[1;31m"
COLOR_GREEN="\e[32m"
COLOR_DARK_YELLOW="\e[33m"
COLOR_MAGENTA="\e[1;35m"
COLOR_PURPLE="\e[35m"
COLOR_CYAN="\e[36m"
COLOR_BLUE="\e[1;34m"
COLOR_ORANGE="\e[31m"
COLOR_GREY="\e[37m"
COLOR_END="\e[0m"

function _printError()
{
	# Initialize variables
	text="$1"

	# Print the error text and exit
	printf "${COLOR_RED}${STYLE_BOLD}ERROR: ${STYLE_RESET}${STYLE_BOLD}$text${STYLE_RESET} Exiting...\n"
	exit 1
}

function _getAudioCodec()
{
	# Initialize variables
	gCodecIDHex=$(ioreg -rxn IOHDACodecDevice | grep VendorID | awk '{ print $4 }' | sed 's/ffffffff//' | grep '0x10ec')
	gCodecIDDec=$(echo $((16#$(echo $gCodecIDHex | sed 's/0x//'))))

	# Identify the codec
	if [[ ! -z $gCodecIDHex ]]; then
		case $gCodecIDDec in
			283904146) gCodec="Realtek ALC892";;
			283904153) gCodec="Realtek ALC898";;
			283904256) gCodec="Realtek ALC1150";;
			285606977) gCodec="VIA VT2021";;
			*) _printError "Unsupported audio codec ($gCodecIDHex / $gCodecIDDec)!";;
		esac
	else
		_printError "No audio codec found in IORegistry!"
	fi

	# Initialize more variables
	gCodecShort=$(echo $gCodec | cut -d ' ' -f 2)
	gCodecModel=$(echo $gCodecShort | tr -d '[:alpha:]')
	gInjectorKextPath="AppleHDA$gCodecModel.kext"

	printf "Detected audio codec: ${STYLE_BOLD}${COLOR_CYAN}$gCodec ${STYLE_RESET}($gCodecIDHex / $gCodecIDDec)\n"
	echo "--------------------------------------------------------------------------------"
}

function _downloadCodecFiles()
{
	# Initialize variables
	fileName="$gCodecShort.zip"

	# Download the ZIP containing the codec XML/plist files
	printf "${STYLE_BOLD}Downloading $gCodec XML/plist files:${STYLE_RESET}\n"
	curl --output "/tmp/$fileName" --progress-bar --location https://github.com/theracermaster/hdaInjector.sh/blob/master/Codecs/$fileName?raw=true
	# Download the plist containing the kext patches
	printf "${STYLE_BOLD}Downloading $gCodec kext patches:${STYLE_RESET}\n"
	curl --output "/tmp/ktp.plist" --progress-bar --location https://github.com/theracermaster/hdaInjector.sh/blob/master/Patches/$gCodecShort.plist?raw=true
	printf "${STYLE_BOLD}Creating $gCodec injector kext ($gInjectorKextPath):${STYLE_RESET}\n"
	# Extract the codec XML/plist files
	unzip "/tmp/$fileName" -d /tmp

	# Check that the command executed successfully
	if [ $? -ne 0 ]; then
		_printError "Failed to download $gCodec files!"
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

	printf "\n${STYLE_BOLD}Installing $gInjectorKextPath:${STYLE_RESET}"
	# Move the kext to /Library/Extensions
	mv "$kext" "$gExtensionsDir"
}

function main()
{
	echo "OS X hdaInjector.sh script v$gScriptVersion by theracermaster"
	echo "Heavily based off Piker-Alpha's AppleHDA8Series script"
	echo "HDA Config files, XML files & kext patches by toleda, Mirone, lisai9093 & others"
	echo "--------------------------------------------------------------------------------"

	_getAudioCodec
	_downloadCodecFiles

	# If a kext already exists, ask the user if we should delete it or keep it
	if [ -d "$gExtensionsDir/$gInjectorKextPath" ]; then
		printf "\n$gInjectorKextPath already exists. Do you want to overwrite it (y/n)? "
		read choice
		case "$choice" in
			y|Y)
				echo "Removing directory..."
				rm -rf "$gExtensionsDir/$gInjectorKextPath";;
			*)
				echo "Exiting..."
				exit 0;;
		esac
	fi

	_createKext
	_createInfoPlist
	_installKext "$gInjectorKextPath"

	printf "${STYLE_BOLD} installation complete, exiting...${STYLE_RESET}\n"

	# Delete the temp files
	sudo rm -f /tmp/$gCodecShort.zip
	sudo rm -rf /tmp/$gCodecShort
	sudo rm -rf "$gInjectorKextPath"
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
