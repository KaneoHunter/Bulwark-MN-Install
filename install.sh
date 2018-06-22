#!/bin/bash

# Make installer interactive and select normal mode by default.
INTERACTIVE="y"
ADVANCED="n"

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -a|--advanced)
    ADVANCED="y"
    shift
    ;;
    -n|--normal)
    ADVANCED="n"
    FAIL2BAN="y"
    UFW="y"
    BOOTSTRAP="y"
    shift
    ;;
    -i|--externalip)
    EXTERNALIP="$2"
    ARGUMENTIP="y"
    shift
    shift
    ;;
    --bindip)
    BINDIP="$2"
    shift
    shift
    ;;
    -k|--privatekey)
    KEY="$2"
    shift
    shift
    ;;
    -f|--fail2ban)
    FAIL2BAN="y"
    shift
    ;;
    --no-fail2ban)
    FAIL2BAN="n"
    shift
    ;;
    -u|--ufw)
    UFW="y"
    shift
    ;;
    --no-ufw)
    UFW="n"
    shift
    ;;
    -b|--bootstrap)
    BOOTSTRAP="y"
    shift
    ;;
    --no-bootstrap)
    BOOTSTRAP="n"
    shift
    ;;
    --no-interaction)
    INTERACTIVE="n"
    shift
    ;;
    -h|--help)
    cat << EOL

Bulwark Masternode installer arguments:

    -n --normal               : Run installer in normal mode
    -a --advanced             : Run installer in advanced mode
    -i --externalip <address> : Public IP address of VPS
    --bindip <address>        : Internal bind IP to use
    -k --privatekey <key>     : Private key to use
    -f --fail2ban             : Install Fail2Ban
    --no-fail2ban             : Don't install Fail2Ban
    -u --ufw                  : Install UFW
    --no-ufw                  : Don't install UFW
    -b --bootstrap            : Sync node using Bootstrap
    --no-bootstrap            : Don't use Bootstrap
    -h --help                 : Display this help text.
    --no-interaction          : Do not wait for wallet activation.

EOL
    exit
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

clear

# Set these to change the version of Bulwark to install

TARBALLURL="https://github.com/bulwark-crypto/Bulwark/releases/download/1.3.0/bulwark-1.3.0.0-linux64.tar.gz"
TARBALLNAME="bulwark-1.3.0.0-linux64.tar.gz"
BWKVERSION="1.3.0.0"
BOOTSTRAPURL="https://github.com/bulwark-crypto/Bulwark/releases/download/1.3.0/bootstrap.dat.xz"
BOOTSTRAPARCHIVE="bootstrap.dat.xz"

#!/bin/bash

# Check if we are root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root." 1>&2
   exit 1
fi

# Check if we have enough memory
if [[ `free -m | awk '/^Mem:/{print $2}'` -lt 850 ]]; then
  echo "This installation requires at least 1GB of RAM.";
  exit 1
fi

# Check if we have enough disk space
if [[ `df -k --output=avail / | tail -n1` -lt 10485760 ]]; then
  echo "This installation requires at least 10GB of free disk space.";
  exit 1
fi

# Install tools for dig and systemctl
echo "Preparing installation..."
apt-get install git dnsutils systemd -y > /dev/null 2>&1

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04?"  >&2; exit 1; }

# Get our current IP
if [ -z "$EXTERNALIP" ]; then
EXTERNALIP=`dig +short myip.opendns.com @resolver1.opendns.com`
fi
clear

if [[ $INTERACTIVE = "y" ]]; then
echo "
    ___T_
   | o o |
   |__-__|
   /| []|\\
 ()/|___|\()
    |_|_|
    /_|_\  ------- MASTERNODE INSTALLER v3 -------+
 |                                                  |
 |   Welcome to the Bulwark Masternode Installer!   |::
 |                                                  |::
 +------------------------------------------------+::
   ::::::::::::::::::::::::::::::::::::::::::::::::::

"

sleep 3
fi

if [[ ("$ADVANCED" == "y" || "$ADVANCED" == "Y") ]]; then

USER=bulwark

adduser $USER --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password > /dev/null

INSTALLERUSED="#Used Advanced Install"

echo "" && echo 'Added user "bulwark"' && echo ""
sleep 1

else

USER=root

if [ -z "$FAIL2BAN" ]; then
  FAIL2BAN="y"
fi
if [ -z "$UFW" ]; then
  UFW="y"
fi
if [ -z "$BOOTSTRAP" ]; then
  BOOTSTRAP="y"
fi
INSTALLERUSED="#Used Basic Install"
fi

USERHOME=`eval echo "~$USER"`

if [ -z "$ARGUMENTIP" ]; then
  read -e -p "Server IP Address: " -i $EXTERNALIP -e EXTERNALIP
fi

if [ -z "$BINDIP" ]; then
    BINDIP=$EXTERNALIP;
fi

if [ -z "$KEY" ]; then
  read -e -p "Masternode Private Key (e.g. 7edfjLCUzGczZi3JQw8GHp434R9kNY33eFyMGeKRymkB56G4324h # THE KEY YOU GENERATED EARLIER) : " KEY
fi

if [ -z "$FAIL2BAN" ]; then
  read -e -p "Install Fail2ban? [Y/n] : " FAIL2BAN
fi

if [ -z "$UFW" ]; then
  read -e -p "Install UFW and configure ports? [Y/n] : " UFW
fi

if [ -z "$BOOTSTRAP" ]; then
  read -e -p "Do you want to use our bootstrap file to speed the syncing process? [Y/n] : " BOOTSTRAP
fi

clear

# Generate random passwords
RPCUSER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
RPCPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# update packages and upgrade Ubuntu
echo "Installing dependencies..."
apt-get -qq update
apt-get -qq upgrade
apt-get -qq autoremove
apt-get -qq install wget htop xz-utils
apt-get -qq install build-essential && apt-get -qq install libtool autotools-dev autoconf automake && apt-get -qq install libssl-dev && apt-get -qq install libboost-all-dev && apt-get -qq install software-properties-common && add-apt-repository -y ppa:bitcoin/bitcoin && apt update && apt-get -qq install libdb4.8-dev && apt-get -qq install libdb4.8++-dev && apt-get -qq install libminiupnpc-dev && apt-get -qq install libqt4-dev libprotobuf-dev protobuf-compiler && apt-get -qq install libqrencode-dev && apt-get -qq install git && apt-get -qq install pkg-config && apt-get -qq install libzmq3-dev
apt-get -qq install aptitude

# Install Fail2Ban
if [[ ("$FAIL2BAN" == "y" || "$FAIL2BAN" == "Y" || "$FAIL2BAN" == "") ]]; then
  aptitude -y -q install fail2ban
  # Reduce Fail2Ban memory usage - http://hacksnsnacks.com/snippets/reduce-fail2ban-memory-usage/
  echo "ulimit -s 256" | sudo tee -a /etc/default/fail2ban
  service fail2ban restart
fi

# Install UFW
if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
  apt-get -qq install ufw
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw allow 52543/tcp
  yes | ufw enable
fi

# Install Bulwark daemon
wget $TARBALLURL
tar -xzvf $TARBALLNAME && mv bin bulwark-$BWKVERSION
rm $TARBALLNAME
cp ./bulwark-$BWKVERSION/bulwarkd /usr/local/bin
cp ./bulwark-$BWKVERSION/bulwark-cli /usr/local/bin
cp ./bulwark-$BWKVERSION/bulwark-tx /usr/local/bin
rm -rf bulwark-$BWKVERSION

# Create .bulwark directory
mkdir $USERHOME/.bulwark

# Install bootstrap file
if [[ ("$BOOTSTRAP" == "y" || "$BOOTSTRAP" == "Y" || "$BOOTSTRAP" == "") ]]; then
  echo "Installing bootstrap file..."
  wget $BOOTSTRAPURL && xz -cd $BOOTSTRAPARCHIVE > $USERHOME/.bulwark/bootstrap.dat && rm $BOOTSTRAPARCHIVE
fi

# Create bulwark.conf
touch $USERHOME/.bulwark/bulwark.conf
cat > $USERHOME/.bulwark/bulwark.conf << EOL
${INSTALLERUSED}
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
externalip=${EXTERNALIP}
bind=${BINDIP}:52543
masternodeaddr=${EXTERNALIP}
masternodeprivkey=${KEY}
masternode=1
EOL
chmod 0600 $USERHOME/.bulwark/bulwark.conf
chown -R $USER:$USER $USERHOME/.bulwark

sleep 1

cat > /etc/systemd/system/bulwarkd.service << EOL
[Unit]
Description=Bulwarks's distributed currency daemon
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/bulwarkd -conf=${USERHOME}/.bulwark/bulwark.conf -datadir=${USERHOME}/.bulwark
ExecStop=/usr/local/bin/bulwark-cli -conf=${USERHOME}/.bulwark/bulwark.conf -datadir=${USERHOME}/.bulwark stop
Restart=on-failure
RestartSec=1m
StartLimitIntervalSec=5m
StartLimitInterval=5m
StartLimitBurst=3
[Install]
WantedBy=multi-user.target
EOL
systemctl enable bulwarkd
echo "Starting bulwarkd..."
systemctl start bulwarkd

sleep 10

if ! systemctl status bulwarkd | grep -q "active (running)"; then
  echo "ERROR: Failed to start bulwarkd. Please contact support."
  exit
fi

echo "Waiting for wallet to load..."
until bulwark-cli getinfo 2>/dev/null | grep -q "version"; do
  sleep 1;
done

clear

echo "Your masternode is syncing. Please wait for this process to finish."
echo "This can take up to a few hours. Do not close this window." && echo ""

until su -c "bulwark-cli mnsync status 2>/dev/null | grep '\"IsBlockchainSynced\" : true' > /dev/null" $USER; do
  echo -ne "Current block: "`su -c "bulwark-cli getinfo" $USER | grep blocks | awk '{print $3}' | cut -d ',' -f 1`'\r'
  sleep 1
done

clear

cat << EOL

Now, you need to start your masternode. Please go to your desktop wallet and
enter the following line into your debug console:

startmasternode alias false <mymnalias>

where <mymnalias> is the name of your masternode alias (without brackets)

EOL

if [[ $INTERACTIVE = "y" ]]; then
  read -p "Press Enter to continue after you've done that. " -n1 -s
fi

clear

sleep 1
su -c "/usr/local/bin/bulwark-cli startmasternode local false" $USER
sleep 1
clear
su -c "/usr/local/bin/bulwark-cli masternode status" $USER
sleep 5

read -e -p "Would you now like to set up staking from this VPS? [N/y] : " STAKING
if [[ ("$STAKING" == "y" || "$STAKING" == "Y") ]]; then
  #Ensure bulwarkd is active
  if systemctl is-active --quiet bulwarkd; then
  	systemctl start bulwarkd
  fi
  echo "Setting Up Staking Address.."

  #Simple check to make sure the bulwarkd sync process is finished, so it isn't interrupted and forced to start over later.'
  echo "Checking Bulwarkd status. The script will begin setting up staking once bulwarkd has finished syncing. Please allow this process to finish."
  until su -c "bulwark-cli mnsync status 2>/dev/null | grep '\"IsBlockchainSynced\" : true' > /dev/null" $USER; do
    echo -ne "Current block: "`su -c "bulwark-cli getinfo" $USER | grep blocks | awk '{print $3}' | cut -d ',' -f 1`'\r'
    sleep 1
  done

  #Ensure the .conf exists
  touch ~/.bulwark/bulwark.conf

  #If the line does not already exist, adds a line to bulwark.conf to instruct the wallet to stake

  sed 's/staking=0/staking=1/' <~/.bulwark/bulwark.conf

  if grep -Fxq "staking=1" ~/.bulwark/bulwark.conf; then
  	echo "Staking Already Active"
  else
  	echo "staking=1" >> ~/.bulwark/bulwark.conf
  fi

  #Generates new address and assigns it a variable
  STAKINGADDRESS=$(bulwark-cli getnewaddress)

  #Ask for a password and apply it to a variable and confirm it.
  ENCRYPTIONKEY=1
  ENCRYPTIONKEYCONF=2
  until [ $ENCRYPTIONKEY = $ENCRYPTIONKEYCONF ]; do
  	read -e -s -p "Please enter a password to encrypt your new staking address/wallet with, you will not see what you type appear. (KEEP THIS SAFE, THIS CANNOT BE RECOVERED) : " ENCRYPTIONKEY
  	read -e -s -p "Please confirm your password : " ENCRYPTIONKEYCONF
  		if [ $ENCRYPTIONKEY != $ENCRYPTIONKEYCONF ]; then
  			echo "Your passwords do not match, please try again."
  		else
  			echo "Password set."
  		fi
  done


  #Encrypt the new address with the requested password
  BIP38=$(bulwark-cli bip38encrypt $STAKINGADDRESS $ENCRYPTIONKEY)
  echo "Address successfully encrypted!"

  #Encrypt the wallet with the same password
  bulwark-cli encryptwallet $ENCRYPTIONKEY && echo "Wallet successfully encrypted!" || { echo "Encryption failed!"; exit; }

  #Wait for bulwarkd to close down after wallet encryption
  echo "Waiting for bulwarkd to restart..."
  until  ! systemctl is-active --quiet bulwarkd; do
      sleep 0.5
  done

  #Open up bulwarkd again
  systemctl start bulwarkd

  #Unlocks the wallet for a long time period
  bulwark-cli walletpassphrase $ENCRYPTIONKEY 9999999999 true

  #Write readme file with further info/instructions.
  touch ~/.bulwark/StakingInfoReadMe.txt
  cat > ~/.bulwark/StakingInfoReadMe.txt << EOL
  Your wallet has now been set up for staking, please send the coins you wish to stake to ${STAKINGADDRESS}. Once your wallet is synced your coins should begin staking automatically.

  To check on the status of your staked coins you can run "bulwark-cli getstakingstatus" and "bulwark-cli getinfo". To see when you receive your rewards from your QT wallet, you can also add a watch-only address from your debug console using "importaddress ${STAKINGADDRESS} StakingRewards".

  You can also import the private key for this address in to your QT wallet using the BIP38 tool under settings, just enter the information here with the password you chose at the start.

  ${BIP38}

  If your bulwarkd restarts, and you need to unlock your wallet again, use "bulwark-cli walletpassphrase ${ENCRYPTIONKEY} 9999999999 true"

  Finally, to send the coins elsewhere if you no longer wish to stake them, use "bulwark-cli walletpassphrase ${ENCRYPTIONKEY} 600 false" and then run "bulwark-cli sendfrom ${STAKINGADDRESS} <Address You Want To Send To> <Amount>" which will return the transaction hash to trace
  the transaction on a block explorer, and will automatically propagate the transaction around the network.

  All of these instruction will be available from the Github page, and in the Bulwark Discord/Telegram on request!

  https://github.com/KaneoHunter/shn/blob/staking/README.md#staking-setup

EOL

  clear

  cat ~/.bulwark/StakingInfoReadMe.txt
else
  echo "Masternode operational."
fi
