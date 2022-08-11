#!/bin/bash

# v1.1
# Complete script meant for running via FileWave as early in the enrollment process as possible. This will download
# and install Dialog on the fly before opening Dialog.
# 
# The logging to /var/tmp/deploy.log is useful when getting started but
# arguably is not needed.
#
# Display a Dialog with a list of applications and indicate when they've been installed
# Reads the FileWave log and updates the Dialog progress text with relevant info
# 
# Requires Dialog v1.9.1 or later https://github.com/bartreardon/swiftDialog/

# *** begin definable variables

# Reference file to make sure filewave-dialog runs only once. This file will be created at the end by the finalise function.
bom_file=/private/var/db/receipts/fw.provisioning.done.bom

# List of apps/installs to process
# Provide the display name as you prefer and the path to the app/file. ex: "Google Chrome,/Applications/Google Chrome.app"
# A comma separates the display name from the path. Do not use commas in your display name text.
# Tip: Check for something like print drivers using the pkg receipt, like "Konica-Minolta drivers,/var/db/receipts/jp.konicaminolta.print.package.C759.plist"
apps=(
    "Google Chrome,/Applications/Google Chrome.app"
    "TeamViewer QuickSupport,/Applications/TeamViewerQS.app"
)

# Microsoft Office variables
# Microsoft fwlink product ID, e.g. "525133" for Office Suite, found at the end of Microsoft's FW link
linkID="2009112"
url="https://go.microsoft.com/fwlink/?linkid=$linkID"
# serializerURL="https://qwerty.domain.net/OfficeForMac/Microsoft_Office_LTSC_2021_VL_Serializer.pkg" # Replace with the URL to your serializer PKG, Comment line 6-8 if you're not serializing
# UNAME=abc # Replace with the username, if needed, to curl your PKG. Comment line 33-35 if you're not serializing
# PWORD=xyz # Replace with the password, if needed, to curl your PKG. Comment line 33-35 if you're not serializing
expectedTeamID="UBF8T346G9" # '/usr/sbin/spctl -a -vv -t install package.pkg' to get the expected Team ID
workDirectory=$( /usr/bin/basename "$0" )
tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )


# Dialog display settings, change as desired
title="Setting up your Mac"
message="Please wait while we download and install apps"
icon="SF=gear"
# location of dialog, dialog command file and FileWave log
dialogApp="/usr/local/bin/dialog"
dialog_command_file="/var/tmp/dialog.log"
filewave_log="/private/var/log/fwcld.log"

# *** end definable variables

# *** functions

function dialog_command(){
	echo "$1"
	echo "$1"  >> $dialog_command_file
}

function finalise(){
   	dialog_command "icon: "SF=gear.badge.checkmark,palette=green,auto""
	dialog_command "progresstext: Setup complete."
	dialog_command "button1text: Done"
	dialog_command "button1: enable"
	echo "Setup complete" >> $filewave_log
	/usr/bin/touch $bom_file
	exit 0
}

function filewave_dialog {
tail -1 -f $filewave_log | while read line
do
	case "$line" in
		*"Downloading Fileset"*|*"Done activating"*|*"Activate all"*)
		echo "progresstext: "${line##*|} | awk -F "(,)+" '{print $1}'"" >> $dialog_command_file
		;;
		*"Setup complete"*)
		exit 0
		;;
	esac 
done
}

function filewave_dialog_list {

tail -1 -f $filewave_log | while read line               
do
	case "$line" in
		*"Downloading Fileset"*|*"Done activating"*|*"Activate all"*)
		echo "progresstext: "${line##*|} | awk -F "(,)+" '{print $1}'"" >> $dialog_command_file
		;;
		*"Running Installer"*)
		echo "listitem: add, title: $( echo ${line##*: } | awk -F "(.pkg)+" '{print $1}' ), statustext: Installing..., status: wait" >> $dialog_command_file
		until grep "$( echo ${line##*: } | awk -F "(.pkg)+" '{print $1}' ).pkg. Result" "$filewave_log" ; do
		sleep 1
		done
		result="$(grep "$( echo ${line##*: } | awk -F "(.pkg)+" '{print $1}' ).pkg. Result" "$filewave_log" | tail -1)"
		resultcode="$(echo "$result" | grep -Eo '[0-9]+$')"
		if [[ $resultcode -eq 0 ]]; then
		echo "listitem: title: $( echo ${line##*: } | awk -F "(.pkg)+" '{print $1}' ), status: success" >> $dialog_command_file
		else
		echo "listitem: title: $( echo ${line##*: } | awk -F "(.pkg)+" '{print $1}' ), status: error, statustext: Error $resultcode" >> $dialog_command_file
		fi
		;;
		*"Setup complete"*)
		exit 0
		;;
	esac
done
}

function appCheck(){
currentapp=$(echo "$app" | cut -d ',' -f1)
dialog_command "listitem: title: $currentapp, status: wait"
while [ ! -e "$(echo "$app" | cut -d ',' -f2)" ]
do
    sleep 2
done
dialog_command "progresstext: \"$(echo "$app" | cut -d ',' -f1)\" complete"
dialog_command "listitem: title: $currentapp, status: success"
dialog_command "progress: increment"
}

function dialogCheck(){
  # Get the URL of the latest PKG From the Dialog GitHub repo
  dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
  # Expected Team ID of the downloaded PKG
  dialogExpectedTeamID="PWA5E9TQ59"

  # Check for Dialog and install if not found
  if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then
    echo "Dialog not found. Installing..."
    # Create temporary working directory
    workDirectory=$( /usr/bin/basename "$0" )
    tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
    # Download the installer package
    /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"
    # Verify the download
    teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
    # Install the package if Team ID validates
    if [ "$dialogExpectedTeamID" = "$teamID" ] || [ "$dialogExpectedTeamID" = "" ]; then
      /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
    else 
      dialogAppleScript
      exitCode=1
      exit $exitCode
    fi
    # Remove the temporary working directory when done
    /bin/rm -Rf "$tempDirectory"  
  else echo "Dialog already found. Proceeding..."
  fi
}

# If something goes wrong and Dialog isn't installed we want to notify the user using AppleScript and exit the script
function displayDialog(){
  message="A problem was encountered setting up this Mac. Please contact IT."
  currentUser=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ { print $3 }')
  if [[ "$currentUser" != "" ]]; then
    currentUserID=$(id -u "$currentUser")
    launchctl asuser "$currentUserID" /usr/bin/osascript <<-EndOfScript
      button returned of ¬
      (display dialog "$message" ¬
      buttons {"OK"} ¬
      default button "OK")
		EndOfScript
  fi
}

function serializeOffice(){
  # download the serializer package and capture the % percentage sign progress for Dialog display
  # We all know not to use cURL with a username and password in the script. Yada yada. Remove --user $UNAME:$PWORD if not required.
  /usr/bin/curl --user $UNAME:$PWORD -L "$serializerURL" -# -o "$tempDirectory/Microsoft_Office_LTSC_2021_VL_Serializer.pkg" 2>&1 | while IFS= read -r -n1 char; do
    [[ $char =~ [0-9] ]] && keep=1 ;
    [[ $char == % ]] && dialog_command "progresstext: Downloading Microsoft Office License ${progress}%" && progress="" && keep=0 ;
    [[ $keep == 1 ]] && progress="$progress$char" ;
  done

  # verify the serializer download
  teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Microsoft_Office_LTSC_2021_VL_Serializer.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
  echo "Team ID for downloaded package: $teamID"

  # install the serializer package if Team ID validates
  if [ "$expectedTeamID" = "$teamID" ] || [ "$expectedTeamID" = "" ]; then
    dialog_command "progresstext: Installing Microsoft Office License..."
    dialog_command "progress: 1"
    /usr/sbin/installer -pkg "$tempDirectory/Microsoft_Office_LTSC_2021_VL_Serializer.pkg" -target /
  else
    dialog_command "progresstext: Something went wrong. Please try again or contact IT. (Invalid License URL or License Team ID)"
    finalizeError
    exitCode=1
    exit $exitCode
  fi
}

function MS365Install(){
workDirectory=$( /usr/bin/basename "$0" )
tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

if [ -z "$serializerURL" ]
then
  echo "Microsoft Serializer not specified. Continuing on."
else
  serializeOffice
fi

# download the installer package and capture the % percentage sign progress for Dialog display
/usr/bin/curl --location "$url" -# -o "$tempDirectory/$linkID.pkg" 2>&1 | while IFS= read -r -n1 char; do
  [[ $char =~ [0-9] ]] && keep=1 ;
  [[ $char == % ]] && dialog_command "listitem: title: Microsoft Office 365, statustext: Downloading... ${progress}%, progress: ${progress}" && progress="" && keep=0 ;
  [[ $keep == 1 ]] && progress="$progress$char" ;
done

# verify the download
teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/$linkID.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
echo "Team ID for downloaded package: $teamID"

# install the package if Team ID validates
if [ "$expectedTeamID" = "$teamID" ] || [ "$expectedTeamID" = "" ]; then
  dialog_command "listitem: title: Microsoft Office 365, status: wait, statustext: installing..."
  /usr/sbin/installer -pkg "$tempDirectory/$linkID.pkg" -target /
#  dialog_command "icon: SF=checkmark.circle.fill,color1=green"
  dialog_command "listitem: title: Microsoft Office 365, status: success"
  dialog_command "progress: increment"
else
  dialog_command "progresstext: Something went wrong. Please try again or contact IT. (Invalid app URL or app Team ID)"
  dialog_command "listitem: title: Microsoft Office 365, status: error"
fi

# remove the temporary working directory when done
/bin/rm -Rf "$tempDirectory"
}

# *** end functions

# start 

# Make sure FileWaveStarterDialog has not been run already

if [ -f "$bom_file" ]; then
    echo "Device already provisioned. filewave-dialog will not run."
    exit 0
fi

# Get arguments

while test $# -gt 0 ; do
    case "$1" in
        --filewave) filewave="yes"
            ;;
        --filewave-list) filewavelist="yes"
            ;;
        --ms365) ms365="yes"
            ;;
    esac
    shift
done


setupAssistantProcess=$(pgrep -l "Setup Assistant")
until [ "$setupAssistantProcess" = "" ]; do
  echo "$(date "+%a %h %d %H:%M:%S"): Setup Assistant Still Running. PID $setupAssistantProcess." 2>&1 | tee -a /var/tmp/deploy.log
  sleep 1
  setupAssistantProcess=$(pgrep -l "Setup Assistant")
done
echo "$(date "+%a %h %d %H:%M:%S"): Out of Setup Assistant" 2>&1 | tee -a /var/tmp/deploy.log
echo "$(date "+%a %h %d %H:%M:%S"): Logged in user is $(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ { print $3 }')" 2>&1 | tee -a /var/tmp/deploy.log

finderProcess=$(pgrep -l "Finder")
until [ "$finderProcess" != "" ]; do
  echo "$(date "+%a %h %d %H:%M:%S"): Finder process not found. Assuming device is at login screen. PID $finderProcess" 2>&1 | tee -a /var/tmp/deploy.log
  sleep 1
  finderProcess=$(pgrep -l "Finder")
done
echo "$(date "+%a %h %d %H:%M:%S"): Finder is running" 2>&1 | tee -a /var/tmp/deploy.log
echo "$(date "+%a %h %d %H:%M:%S"): Logged in user is $(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ { print $3 }')" 2>&1 | tee -a /var/tmp/deploy.log


dialogCheck


# set progress total to the number of apps in the list
if [[ $ms365 == "yes" ]]; then
   progress_total=${#apps[@]}
   progress_total=$(($progress_total+1))
else
   progress_total=${#apps[@]}
fi


# set icon based on whether computer is a desktop or laptop
#hwType=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Model Identifier" | grep "Book")	
#if [ "$hwType" != "" ]; then
#	icon="SF=laptopcomputer.and.arrow.down,weight=thin,colour1=#51a3ef,colour2=#2F4A6A"
#	else
#	icon="SF=desktopcomputer.and.arrow.down,weight=thin,colour1=#51a3ef,colour2=#2F4A6A"
#fi

echo "$(date "+%a %h %d %H:%M:%S"): Logged in user is $(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ { print $3 }')" 2>&1 | tee -a /var/tmp/deploy.log

dialogCMD="$dialogApp --title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--progress $progress_total \
--button1text \"Please Wait\" \
--button1disabled \
--messagefont size=14"

# create the list of apps
listitems=""
for app in "${apps[@]}"; do
	listitems="$listitems --listitem '$(echo "$app" | cut -d ',' -f1)'"
done

# final command to execute

if [[ $ms365 == "yes" ]]; then
   echo "Installing Microsoft Office 365 Suite"
   dialogCMD="$dialogCMD --listitem 'Microsoft Office 365' $listitems"
   echo "$dialogCMD"
   eval "$dialogCMD" &
   sleep 2
   MS365Install
else
   dialogCMD="$dialogCMD $listitems"
   echo "$dialogCMD"
   eval "$dialogCMD" &
   sleep 2
fi

if [[ $filewave == "yes" ]]; then
   echo "Start reading FileWave Client log..."
   filewave_dialog & 
fi

if [[ $filewavelist == "yes" ]]; then
   echo "Start reading FileWave Client log..."
   filewave_dialog_list & 
fi

sleep 2

(for app in "${apps[@]}"; do
	appCheck &
done


wait)

# all done. close off processing and enable the "Done" button

echo "$(date "+%a %h %d %H:%M:%S"): Finalizing." 2>&1 | tee -a /var/tmp/deploy.log
finalise
echo "$(date "+%a %h %d %H:%M:%S"): Done." 2>&1 | tee -a /var/tmp/deploy.log
