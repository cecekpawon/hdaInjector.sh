#!/bin/bash
# hdaInjector.sh - Script to create an AppleHDA injector for audio codecs common on several desktop motherboards

# Initialize global variables

## The script version
gScriptVersion="0.2-desktop"
gDebug=0

## The user ID
gID=$(id -u)

## The audio codec
gCodec=""
## The audio codec's hex identifier
gCodecIDHex=""
## The audio codec's decimal identifier
gCodecIDDec=""
## The audio codec's short name (e.g. Realtek ALC898 > ALC898)
gCodecShort=""
## The audio codec's model (e.g. Realtek ALC898 > 898)
gCodecModel=""
## Layout-id
gLayID=0

gOSVer="$(sw_vers -productVersion | sed -e 's/\.\([0-9]\)$//g')"
gDesktopDir="/Users/$(who am i | awk '{print $1}')/Desktop"

## Path to /Library/Extensions
if (( $gDebug )); then
	gExtensionsDir=$gDesktopDir
else
	gExtensionsDir="/Library/Extensions"
fi

## Path to /System/Library/Extensions
gSystemExtensionsDir="/System/Library/Extensions"
## Path to AppleHDA.kext
gKextPath="${gSystemExtensionsDir}/AppleHDA.kext"

## Name of the injector kext that will be created & installed
gInjectorKext=""

## URL Sources
gUrlCodec[1]="https://github.com/toleda/audio_ALC%d/blob/master/%d.zip?raw=true"
gUrlCodec[2]="https://github.com/Mirone/AppleHDA_10.11/blob/master/Desktop's/AppleHDA-272.50-ALC%d.zip?raw=true"

gRepo="cecekpawon"
gUrlCloverPatch="https://github.com/${gRepo}/hdaInjector.sh/blob/master/Patches/${gOSVer}/%d.plist?raw=true"
gMethod=1 # 1: toleda | 2: mirone

gHdaClover="hda-clover-%d.plist"
gHdaTmp="/tmp/%d"
gInjectorKextTmp=""
gPlistBuddyCmd="/usr/libexec/plistbuddy -c"

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
	# Print the error text and exit
	printf "\n${STYLE_BOLD}${COLOR_RED}ERROR: ${STYLE_RESET}${STYLE_BOLD}${1}${STYLE_RESET}"
	_removeTemp
	printf "\n\nExiting..\n"
	exit 1
}

function _removeTemp()
{
	printf "\nCleaning up.."
	rm -rf "${gHdaTmp}"
}

function _getAudioCodec()
{
	# Identify the codec
	if [[ -z $gCodecIDHex ]]; then
		# Initialize variables
		gCodecIDHex=$(ioreg -rxn IOHDACodecDevice | grep VendorID | awk '{ print $4 }' | sed 's/ffffffff//' | grep '0x10ec')
		gCodecIDDec=$(echo $((16#$(echo $gCodecIDHex | sed 's/0x//'))))
	fi

	if [[ ! -z $gCodecIDHex ]]; then
		case $gCodecIDDec in
			#283904133) gCodec="Realtek ALC885";;
			#283904135) gCodec="Realtek ALC887";;
			#283904136) gCodec="Realtek ALC888";;
			#283904137) gCodec="Realtek ALC889";;
			283904146) gCodec="Realtek ALC892";;
			#283904153) gCodec="Realtek ALC898";;
			#283904256) gCodec="Realtek ALC1150";;
			#285606977) gCodec="VIA VT2021";;
			*) _printError "Unsupported audio codec (${gCodecIDHex} / ${gCodecIDDec})!";;
		esac
	else
		_printError "No audio codec found in IORegistry!"
	fi

	# Initialize more variables
	gCodecShort=$(echo $gCodec | cut -d ' ' -f 2)
	gCodecModel=$(echo $gCodecShort | tr -d '[:alpha:]')
	gHdaTmp=$(printf $gHdaTmp $gCodecModel)
	gInjectorKext="AppleHDA${gCodecModel}.kext"
	gInjectorKextTmp="${gHdaTmp}/${gInjectorKext}"
	gInjectorKextPath="${gExtensionsDir}/${gInjectorKext}"

	gFixedLayID=$((( $gLayID )) && echo $gLayID || echo "All")
	gFixedMethod=$((( $gMethod == 2)) && echo "Mirone" || echo "Toleda")

	printf "${STYLE_BOLD}Set Layout-id: ${COLOR_CYAN}${gFixedLayID}${STYLE_RESET}\n"
	printf "${STYLE_BOLD}Set Method: ${COLOR_CYAN}${gMethod} by ${gFixedMethod}${STYLE_RESET}\n"
	printf "${STYLE_BOLD}Set Codec-id: ${COLOR_CYAN}${gCodec} ${STYLE_RESET}(${gCodecIDHex} / ${gCodecIDDec})\n"
	echo "--------------------------------------------------------------------------------"
}

function _downloadCodecFiles()
{
	printf "\n\n${STYLE_BOLD}Downloading required files:${STYLE_RESET}\n"

	# Initialize variables
	fileName="/tmp/${gMethod}_${gCodecModel}.zip"

	gUrlCodec=$(printf ${gUrlCodec[$gMethod]} $gCodecModel $gCodecModel)

	# Download the ZIP containing the codec XML/plist files
	if [ ! -e $fileName ]; then
		printf "\n${STYLE_BOLD}${gCodec}${STYLE_RESET} XML/plist files:\n"
		curl --output $fileName --progress-bar --location $gUrlCodec
	fi

	gHdaClover="${gDesktopDir}/$(printf $gHdaClover $gCodecModel)"
	gUrlCloverPatch=$(printf $gUrlCloverPatch $gCodecModel)

	# Download the plist containing the kext patches
	if [ ! -e "${gHdaClover}" ]; then
		printf "\n${STYLE_BOLD}${gCodec}${STYLE_RESET} Clover KextsToPatch:\n"
		curl --output "${gHdaClover}" --progress-bar --location $gUrlCloverPatch
	fi

	if [ -e "${gHdaClover}" ]; then
		printf "\n${STYLE_BOLD}${COLOR_GREEN}Clover KextsToPatch is ready: ${STYLE_RESET}${COLOR_BLUE}${gHdaClover}${STYLE_RESET}\nDo you want to open it (y/n)? "
		read choice
		case "$choice" in
			y|Y) open -a textEdit "${gHdaClover}";;
		esac
	fi

	# Extract the codec XML/plist files
	unzip -oq $fileName -d $gHdaTmp && f=($gHdaTmp/*) && mv $gHdaTmp/*/* $gHdaTmp && rmdir "${f[@]}"

	zlibs=("Platforms")
  if (( $gLayID )); then
  	zlibs+=($gLayID)
  fi

	case $gMethod in
		1) # Toleda
	  	gMethodPath=$gHdaTmp
		  if (( ! $gLayID )); then
		  	zlibs+=(1 2 3)
		  fi
			;;
		2) # Mirone
	  	gMethodPath="${gHdaTmp}/AppleHDA.kext/Contents"
		  if (( ! $gLayID )); then
		  	zlibs+=(5 7 9)
		  fi

		  cp "${gMethodPath}/PlugIns/AppleHDAHardwareConfigDriver.kext/Contents/Info.plist" $gHdaTmp
		  $gPlistBuddyCmd "Copy ':IOKitPersonalities:HDA Hardware Config Resource:HDAConfigDefault' ':Tmp:HDAConfigDefault'" "${gHdaTmp}/Info.plist"
	    $gPlistBuddyCmd "Print :Tmp" "$gHdaTmp/Info.plist" -x > "${gHdaTmp}/hdacd.tmp"
    	mv "${gHdaTmp}/hdacd.tmp" "${gHdaTmp}/hdacd.plist"
	  	gMethodPath+="/Resources"
			;;
	esac

	mkdir "${gHdaTmp}/tmp" && mv $gMethodPath/*.zlib "${gHdaTmp}/tmp"
  for xml in "${zlibs[@]}"
  do
    xml=$((($xml == "Platforms"))  && echo $xml || echo "layout${xml}")
    cp "${gHdaTmp}/tmp/${xml}.xml.zlib" $gHdaTmp
  done

	# Check that the command executed successfully
	if [ ! -e "${gHdaTmp}/Platforms.xml.zlib" ]; then
		_printError "Failed to download ${gCodec} files!"
	fi
}

function _createKext()
{
	# Create kext directories
	mkdir -p "${gInjectorKextTmp}/Contents/MacOS"
	mkdir -p "${gInjectorKextTmp}/Contents/Resources"

	# Create a symbolic link to AppleHDA
	ln -s "${gKextPath}/Contents/MacOS/AppleHDA" "${gInjectorKextTmp}/Contents/MacOS"

	# Copy XML files to kext directory
	cp $gHdaTmp/*.zlib "${gInjectorKextTmp}/Contents/Resources"
}

# Worst method, just work: skip unmatched codec
function _getMatchedCodec()
{
  LINES=($(echo $($gPlistBuddyCmd "Print :HDAConfigDefault" $1 -x) | grep -o '<dict>'))

  let cid=0
  for i in "${LINES[@]}"
  do
  	let gLayIDOK=0
		codecID=$($gPlistBuddyCmd "Print :HDAConfigDefault:${cid}:CodecID" $1 2>&1)
		LayoutID=$($gPlistBuddyCmd "Print :HDAConfigDefault:${cid}:LayoutID:" $1 2>&1)

    if [ $codecID -eq $gCodecIDDec ]; then
    	case $gLayID in
    							0) let gLayIDOK++;;
    		1|2|3|5|7|9) if [ $gLayID -eq $LayoutID ]; then let gLayIDOK++; fi;;
    	esac
    fi

    if [ $gLayIDOK -ne 0 ]; then
    	let cid++
    	continue
		else
			$gPlistBuddyCmd "Delete :HDAConfigDefault:${cid}" $1
			_getMatchedCodec $1
    fi
  	return
  done
}

function _createInfoPlist()
{
	printf "\nWorking..\n"

	# Initialize variables
	plist="${gInjectorKextTmp}/Contents/Info.plist"
	hdacd="${gHdaTmp}/hdacd.plist"
	tmphdacd="${gHdaTmp}/tmphdacd.plist"

	# Copy plist from AppleHDA
	cp "${gKextPath}/Contents/Info.plist" "${plist}"

	# Change version number of AppleHDA injector kext so it is loaded instead of stock AppleHDA
	replace=`$gPlistBuddyCmd "Print :NSHumanReadableCopyright" $plist | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
	$gPlistBuddyCmd "Set :NSHumanReadableCopyright '$replace'" $plist
	replace=`$gPlistBuddyCmd "Print :CFBundleGetInfoString" $plist | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
	$gPlistBuddyCmd "Set :CFBundleGetInfoString '$replace'" $plist
	replace=`$gPlistBuddyCmd "Print :CFBundleVersion" $plist | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
	$gPlistBuddyCmd "Set :CFBundleVersion '$replace'" $plist
	replace=`$gPlistBuddyCmd "Print :CFBundleShortVersionString" $plist | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
	$gPlistBuddyCmd "Set :CFBundleShortVersionString '$replace'" $plist

	# Merge the HDA Config Default from the codec's hdacd.plist into the injector's Info.plist
	$gPlistBuddyCmd "Add ':HardwareConfigDriver_Temp' dict" $plist
	$gPlistBuddyCmd "Merge /${gKextPath}/Contents/PlugIns/AppleHDAHardwareConfigDriver.kext/Contents/Info.plist ':HardwareConfigDriver_Temp'" $plist
	$gPlistBuddyCmd "Copy ':HardwareConfigDriver_Temp:IOKitPersonalities:HDA Hardware Config Resource' ':IOKitPersonalities:HDA Hardware Config Resource'" $plist
	$gPlistBuddyCmd "Delete ':HardwareConfigDriver_Temp'" $plist
	$gPlistBuddyCmd "Delete ':IOKitPersonalities:HDA Hardware Config Resource:HDAConfigDefault'" $plist
	$gPlistBuddyCmd "Delete ':IOKitPersonalities:HDA Hardware Config Resource:PostConstructionInitialization'" $plist
	$gPlistBuddyCmd "Add ':IOKitPersonalities:HDA Hardware Config Resource:IOProbeScore' integer" $plist
	$gPlistBuddyCmd "Set ':IOKitPersonalities:HDA Hardware Config Resource:IOProbeScore' 2000" $plist
	#$gPlistBuddyCmd "Merge ${hdacd} ':IOKitPersonalities:HDA Hardware Config Resource'" $plist

	cp $hdacd $tmphdacd
	_getMatchedCodec $tmphdacd
	$gPlistBuddyCmd "Merge ${tmphdacd} ':IOKitPersonalities:HDA Hardware Config Resource'" $plist
}

function _installKext()
{
	printf "\n${STYLE_BOLD}Installing ${gInjectorKext}: ${STYLE_RESET}${COLOR_BLUE}${gInjectorKextPath}${STYLE_RESET}"

	# Install to Extensions Dir
	cp -R "${gInjectorKextTmp}" "${gInjectorKextPath}"

	_removeTemp

	if (( ! $gDebug )); then
		_repairPermissions
	fi
}

function _repairPermissions()
{
	printf "\nRepairing Permissions..\n"

	# Correct the permissions
	#chmod -R 755 "${gInjectorKextPath}"
	chown -R 0:0 "${gInjectorKextPath}"

	sudo touch "${gExtensionsDir}"
	sudo chmod -R 755 "${gExtensionsDir}"
	sudo kextcache -system-prelinked-kernel
	sudo kextcache -system-caches
}

function _checkLayoutId()
{
	case $gLayID in
    		0) return;;
    1|2|3) if [ $gMethod == 1 ]; then return; fi;;
    5|7|9) if [ $gMethod == 2 ]; then return; fi;;
	esac

  _printError "Layout-id not supported (1/2/3/5/7/9)!"
}

function main()
{
	echo "OS X hdaInjector.sh script v${gScriptVersion} by theracermaster"
	echo "Heavily based off Piker-Alpha's AppleHDA8Series script"
	echo "HDA Config files, XML files & kext patches by toleda, Mirone, lisai9093 & others"
	echo "--------------------------------------------------------------------------------"
	echo "Usage: Params fully optional"
	echo "Method: ${0##*/} -m 1 (1: Toleda | 2: Mirone)"
	echo "Layout-id: ${0##*/} -l 3 (-m 1: -l: 1/2/3 | -m 2: -l: 5/7/9)"
	echo "Codec-id: ${0##*/} -c 892"
	echo "--------------------------------------------------------------------------------"

	# Native AppleHDA check
	if [ ! -d "${gKextPath}" ]; then
		_printError "${gKextPath} not found!"
	fi

	while true ; do
		case "$1" in
			-l)
					case "$2" in
            1|2|3|5|7|9) gLayID=$2;;
					esac
					shift 2;;
			-c)
					case "$2" in
						892) #885|887|888|889|892|898|1150
							gCodecIDHex="0x10ec0${2}";
						 	gCodecIDDec=`echo $((16#${gCodecIDHex:2}))`
						  ;;
            *)
              _printError "Codec not supported (manually edit source)!"
              ;;
					esac
					shift 2;;
			-m)
					case "$2" in
            1|2)
              gMethod=$2
              ;;
            *)
              _printError "Method not supported (1: Toleda | 2: Mirone)!"
              ;;
					esac
					shift 2;;
       *) break;;
		esac
	done

	_checkLayoutId
	_getAudioCodec

	# If a kext already exists, ask the user if we should delete it or keep it
	if [ -d "${gInjectorKextPath}" ]; then
		printf "\n${COLOR_RED}${gInjectorKext} already exists: ${STYLE_RESET}${COLOR_BLUE}${gInjectorKextPath}${STYLE_RESET}\nDo you want to overwrite it (y/n)? "
		read choice
		case "$choice" in
			y|Y) rm -rf "${gInjectorKextPath}";;
			  *) echo "Exiting.."
				   exit;;
		esac
	fi

	printf "\n${STYLE_BOLD}Creating ${gCodec} injector kext ($gInjectorKext):${STYLE_RESET}"

	_removeTemp
	_downloadCodecFiles
	_createKext
	_createInfoPlist
	_installKext

	printf "\n\n${STYLE_BOLD}Installation complete!${STYLE_RESET}"

	if (( ! $gDebug )); then
		printf "\n\nReboot now (y/n)? "
		read choice
		case "$choice" in
			y|Y) sudo reboot;;
		esac
	fi

	printf "\n\nExiting..\n"
}

clear

# Check if we are root
if [ $gID -ne 0 ]; then
	# Re-run the script as root
	echo "This script needs to be run as root."
	sudo "${0}" "$@"
else
	# We are root, so just call the main function
	main "$@"
fi

exit 0
