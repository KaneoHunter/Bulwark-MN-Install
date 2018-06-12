#!/bin/bash
# -------------------------------------------------------------------- #
# Crypto Beratung ogi / Oscar Gil  © 2018
# Update Bulwark (BWK)
# Version 1.3.0.0
# -------------------------------------------------------------------- #

coin_dir=$HOME/coins/bulwark
actual_dir=`pwd`
service_name="bulwark"

TARBALLURL="https://github.com/bulwark-crypto/Bulwark/releases/download/1.3.0/bulwark-1.3.0.0-linux64.tar.gz"
TARBALLNAME="bulwark-1.3.0.0-linux64.tar.gz"
BWKVERSION="1.3.0.0"

CHARS="/-\|"

continue_with_Enter()
{
#	read -p "Continue [Enter] " n
	echo ""
	read -p "Press Ctrl-C to abort or any other key to continue. " n
	echo ""
}

clear
echo -e "This script will update your masternode to version $BWKVERSION\n"
#read -p "Press Ctrl-C to abort or any other key to continue. " -n1 -s
continue_with_Enter

#clear
#:'
#if [ "$(id -u)" != "0" ]; then
#  echo "This script must be run as root."
#  exit 1
#fi
#'

unexpected_error()
{
	echo "unexpected error" 
	echo "installation aborted"
	exit 1
}

sudo -v
if [ $? -gt 0 ]; then
    echo "You need to run this installation script with sudo rights"
    echo "installation aborted"
fi

purge_bulwark_from_crontab="yes"

pgrep bulwarkd >/dev/null 2>&1
if [ $? -eq 0 ]; then
	# bulwark daemon runs
	# next line will be show wrong user for user with more as 8 characters 
	# USER=`ps u $(pgrep bulwarkd) | grep bulwarkd | cut -d " " -f 1`

	# this line works
	USER=`ps h -o uid $(pgrep bulwarkd) | id -nu`
	USERHOME=`eval echo "~$USER"`

	echo "Shutting down masternode..."
	if [ -e /etc/systemd/system/$service_name.service ]; then
		sudo systemctl stop $service_name
	else
		bulwark-cli stop
		purge_bulwark_from_crontab="yes"
	fi
else
	# no bulwark daemon"
	# search for core directory
	USERHOME=`find $HOME -xdev 2>/dev/null -name ".bulwark" | awk -F "." '{print $1; exit}' | sed 's/\/$//'`
fi

echo "USER=$USER"
echo "USERHOME=$USERHOME"

echo "actual_dir=`pwd`"
cd $coin_dir
echo "working_dir=`pwd`"

read -p "Press Ctrl-C to abort or any other key to continue. "
echo ""

# Add Fail2Ban memory hack if needed
if ! grep -q "ulimit -s 256" /etc/default/fail2ban; then
  echo "ulimit -s 256" | sudo tee -a /etc/default/fail2ban >/dev/null 2>&1
  sudo systemctl restart fail2ban
fi

if [ -e /usr/local/bin/bulwarkd ];then sudo rm -rfv /usr/local/bin/bulwarkd; fi
if [ -e /usr/local/bin/bulwark-cli ];then sudo rm -rfv /usr/local/bin/bulwark-cli; fi
if [ -e /usr/local/bin/bulwark-tx ];then sudo rm -rfv /usr/local/bin/bulwark-tx; fi

echo "Installing Bulwark ${BWKVERSION}"
if [ -e "$TARBALLNAME" ]; then rm -fv $TARBALLNAME 2>/dev/null; fi
if [ -d "bulwark-$BWKVERSION" ]; then rm -rv "bulwark-$BWKVERSION" 2>/dev/null; fi

wget $TARBALLURL || unexpected_error
tar -xzvf $TARBALLNAME || unexpected_error
mv -v bin bulwark-$BWKVERSION || unexpected_error

sudo ln bulwark-$BWKVERSION/bulwarkd /usr/local/bin    || unexpected_error
sudo ln bulwark-$BWKVERSION/bulwark-cli /usr/local/bin || unexpected_error

rm -fv $TARBALLNAME

if [ -e "$USERHOME/.bulwark/bulwark.conf" ]; then 
	cp -v "$USERHOME/.bulwark/bulwark.conf" "$USERHOME/.bulwark/bulwark.conf".backup 
fi

# Remove addnodes from bulwark.conf
sed -i '/^addnode/d' $USERHOME/.bulwark/bulwark.conf

echo "Restarting Bulwark daemon..."
bwk_start_service_name="bulwark"
bwk_start_service="/etc/systemd/system/$bwk_start_service_name.service"
coin_core_dir=${USERHOME}/.bulwark
coin_config_file=${USERHOME}/.bulwark/bulwark.conf 

if [ -e "$bwk_start_service" ]
then
    sudo mv -v "$bwk_start_service" "$bwk_start_service".backup
	sudo systemctl stop    $bwk_start_service_name
	sudo systemctl disable $bwk_start_service_name
	sudo rm -fv "$bwk_start_service"
	sudo systemctl daemon-reload
fi

sudo touch "$bwk_start_service"        
sudo chown -v $USER $bwk_start_service
sudo chgrp -v $USER $bwk_start_service
sleep 1

cat > $bwk_start_service << EOL
; Bulwark Start Service
[Unit]
Description="Bulwark (BWK) Master Node
After=network.target

[Service]
User=$USER
Group=$USER

Type=forking
;Type=simple

; location of the master node executable
WorkingDirectory=${coin_core_dir}
ExecStart=/usr/local/bin/bulwarkd -conf=${coin_config_file} -datadir=${coin_core_dir}
ExecStop=/usr/local/bin/bulwark-cli -conf=${coin_config_file} -datadir=${coin_core_dir} stop
;Restart=on-abort
;Restart=always
Restart=on-failure
RestartSec=60
StartLimitIntervalSec=5m
StartLimitInterval=5m
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
;WantedBy=default.target
EOL

sudo systemctl daemon-reload                  || unexpected_error

echo "sudo systemctl enable $bwk_start_service_name"
sudo systemctl enable $bwk_start_service_name || unexpected_error

echo "sudo systemctl start  $bwk_start_service_name"
sudo systemctl start  $bwk_start_service_name || unexpected_error

echo "sudo systemctl status $bwk_start_service_name"
sudo systemctl status $bwk_start_service_name | tail -n 10

sudo systemctl status $bwk_start_service_name | grep "Active:" | grep "failed" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    "
Bulwark start Service failed.
Please check the service after installation
Bulwark will be start manually anyways..."
    # Start daemon manually
    $coin_daemon -daemon >>$logfile 2>&1
	/usr/local/bin/bulwarkd -conf=${coin_config_file} -datadir=${coin_core_dir}
fi

if [ "$purge_bulwark_from_crontab" == "yes" ]; then
	(crontab -l | sed '/bulwark/d') | crontab
	(crontab -l | sed '/Bulwark/d') | crontab
fi

#clear
bulwark-cli -version

echo "Your masternode is syncing. Please wait for this process to finish."
sleep 5

: '
until bulwark-cli startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null; do
  for (( i=0; i<${#CHARS}; i++ )); do
    echo -en "${CHARS:$i:1}" "\r"
    sleep 2
    bulwark-cli mnsync status | grep 'RequestedMasternodeAssets' | grep 999 >/dev/null
    if [ $? -eq 0 ]; then
        echo -en "  Masternode syncronized" "\r"
        bulwark-cli masternode status | grep 'waiting for remote activation' >/dev/null
        if [ $? -gt 0 ]; then
            bulwark-cli masternode status
            read -p "Press Ctrl-C to abort or any other key to continue. "
        fi
    else
        bulwark-cli mnsync status | grep 'RequestedMasternodeAssets'
    fi
  done
done
'

#until "bulwark-cli mnsync status 2>/dev/null | grep '\"IsBlockchainSynced\" : true' > /dev/null" $USER; do
until bulwark-cli mnsync status 2>/dev/null | grep '\"IsBlockchainSynced\" : true' >/dev/null ; do
  for (( i=0; i<${#CHARS}; i++ )); do
    sleep 2
    echo -en "${CHARS:$i:1}" "\r"
  done
done


#echo "bulwark-cli mnsync status" && bulwark-cli mnsync status
echo "bulwark-cli getinfo" && bulwark-cli getinfo
echo "bulwark-cli masternode status" && bulwark-cli masternode status
bulwark-cli --version

echo "" && echo "Masternode update Bulwark BWKVERSION completed." && echo ""
