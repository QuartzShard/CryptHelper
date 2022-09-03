#!/bin/bash

######################
# cryptsetup helper  #
# by solunareclipse1 #
######################

## Variables defining
doRootCheck=true
doDepCheck=true
doConfirms=true
encDev=""
mapperName=""
mountPoint=""
privUtil=""
scriptMode=2

# Help print
function PrintHelp() {
    echo "A shell script to streamline the use of cryptsetup"
    echo
    echo "Usage: crypthelper [options]"
    echo "Options:"
    echo "-d     Specify the device name (eg: /dev/sda)"
    echo "-D     Bypasses the dependancy check (careful!)"
    echo "-h     Displays this help message"
    echo "-l     Specify the mount location (eg: '/mnt/cryptdrive')"
    echo "-m     Specify the mapper name (eg: 'cryptdrive')"
    echo "-M     Mount Mode"
    echo "-R     Allows you to run the script as the root user (careful!)"
    echo "-S     (if both sudo and doas are installed) forces the use of sudo"
    echo "-U     Unmount Mode"
    echo "-y     Skip confirmation dialogs / splash text"
}


## Commandline options handling
while getopts ":hd:Dl:m:MRSUy" opt; do
    case $opt in
        h) # help
            PrintHelp
            exit 0;;
        d) # device name
            encDev=${OPTARG};;
        D) # bypass dep check
            echo "WARN: Bypassing dependancy check!"
            echo "This may cause errors, I hope you know what you're doing!"
            doDepCheck=false;;
        l) # mount point
            mountPoint=${OPTARG};;
        m) # mapper name
            mapperName=${OPTARG};;
        M) # mount mode
            if [[ $scriptMode != 2 ]]; then
                echo "ERROR: M and U options are mutually exclusive"
                echo "Please remove one, or use 'cryptsetup -h' for help"
                exit 1
            fi
            scriptMode=1;;
        R) # bypass root check
            echo "WARN: Bypassing root user check!"
            echo "This is not recommended, proceed with caution"
            doRootCheck=false;;
        S) # use sudo over doas
            if [[ $(which doas | grep -c "not found") != 0 ]]; then
                echo "NOTE: doas not found, -S option ignored"
            elif [[ $(which sudo | grep -c "not found") != 0 ]]; then
                echo "NOTE: sudo not found, -S option ignored"
            else
                privUtil="sudo "
            fi;;
        U) # unmount mode
            if [[ $scriptMode != 2 ]]; then
                echo "ERROR: M and U options are mutually exclusive"
                echo "Please remove one, or use 'cryptsetup -h' for help"
                exit 1
            fi
            scriptMode=0;;
        y) # skip confirms
            doConfirms=false;;
        :)
            echo "ERROR: -${OPTARG} requires an argument"
            echo "Use 'cryptsetup -h' for help"
            exit 1;;
        ?)
            echo "ERROR: Unknown option -${OPTARG}"
            echo "Use 'cryptsetup -h' for help"
            exit 1;;
    esac
done

## Main functions defining
# Checks some very basic stuff (root & dependencies)
function SanityCheck() {
    if [[ $EUID == 0 && $doRootCheck == true ]]; then
	    echo "ERROR: This script is being run as root!"
	    echo "This is (probably) unnecessary, as the script will automatically ask for a password when necessary."
	    echo "THE SCRIPT WILL NOW TERMINATE!"
	    exit 1
    fi

    if [[ $(which cryptsetup | grep -c "not found") != 0 && $doDepCheck == true ]]; then
        echo "ERROR: cryptsetup does not appear to be installed!"
        echo "This script requires it to be installed, please do so, then try again."
	    echo "THE SCRIPT WILL NOW TERMINATE!"
        exit 1
    fi

    if [[ $EUID == 0 ]]; then
        if [[ $doConfirms == true ]]; then
            clear
            echo "WARN: This script is running as root!"
            echo "!! MAKE SURE YOU KNOW WHAT YOU ARE DOING !!"
            echo
            echo "Enter to continue"
            read -r
        fi
    elif [[ $doDepCheck == false ]]; then
        if [[ $privUtil == "sudo " ]]; then
            echo -n
        else
            privUtil="doas "
        fi
    else
        if [[ $(which doas 2>&1 | grep -c "which: no") == 0 ]]; then # prefer doas
            privUtil="doas " # it is less common, so user will probably want to use it over sudo
        elif [[ $(which sudo 2>&1 | grep -c "which: no") == 0 ]]; then
            privUtil="sudo "
        fi
    fi

}

# Gets unspecified inputs
function AskForInputs() {
    while [[ $scriptMode -gt 1 || $scriptMode -lt 0 ]]; do
        clear
        echo "Please choose a mode"
        echo "1 to mount, 0 to unmount"
        echo
        echo -n "Mode: "
        read -r scriptMode
        if [[ $scriptMode -gt 1 || $scriptMode -lt 0 ]]; then
            echo "Invalid mode $scriptMode"
        fi
    done

    while [[ $encDev == "" && $scriptMode == 1 ]]; do
        clear
        echo "Enter the path to the encrypted volume"
        echo "Example: /dev/sde1, /dev/nvme0n1p2"
        echo
        echo -n "Path: "
        read -r encDev
    done

    while [[ $mapperName == "" ]]; do
        clear
        echo "Enter the mapper name"
        echo "Example: cryptdrive"
        echo
        echo -n "Mapper: "
        read -r mapperName
    done

    while [[ $mountPoint == "" ]]; do
        clear
        echo "Enter the mount point"
        echo "Example: /mnt/crypt"
        echo
        echo -n "Mount point: "
        read -r mountPoint
    done

    clear

    if [[ $scriptMode == 1 ]]; then
        echo "The encrypted device '$encDev' will be mapped to '$mapperName', then mounted at '$mountPoint'."
    elif [[ $scriptMode == 0 ]]; then
        echo "The encrypted device mapped to '$mapperName' will be unmounted from '$mountPoint', then unmapped."
    else
        echo "ERROR: Unknown mode $scriptMode"
        echo "If you see this message, you have found a bug!"
        echo "The script will now exit, please report the bug <3"
        exit 1
    fi
    echo
    if [[ $doConfirms == true ]]; then
        echo -n "Is this correct? [y/N] "
        read -r confirmVars
        if [[ $confirmVars != y && $confirmVars != Y ]]; then
            echo "Abort."
            exit 1
        fi
    fi
}

# Decrypts the device $1 to the mapper $2, then mounts it at $3
function CryptOpen() {
    commandToRun="${privUtil}cryptsetup open $1 $2 && ${privUtil}mkdir -p $3 && ${privUtil}mount /dev/mapper/$2 $3"
    echo "Mounting using the following command:"
    echo
    echo "$commandToRun"
    echo
    echo "Enter passwords/verify as needed"
    eval "$commandToRun"
}

# Unmounts device at $1, then closes the mapper $2
function CryptClose() {
    commandToRun="${privUtil}umount $1 && ${privUtil}cryptsetup close $2"
    echo "Unmounting using the following command:"
    echo
    echo "$commandToRun"
    echo
    echo "Enter passwords/verify as needed"
    eval "$commandToRun"
}


## Actually doing / running stuff
if [[ $doConfirms == true ]]; then
    echo "CryptHelper, a cryptsetup helper script"
    echo "by solunareclipse1"
    echo
    echo "Enter to continue"
    read -r
fi
clear
SanityCheck
AskForInputs
if [[ $scriptMode == 1 ]]; then
    CryptOpen "$encDev" "$mapperName" "$mountPoint"
else
    CryptClose "$mountPoint" "$mapperName"
fi
echo
echo "Finished!"
exit 0
