#!/bin/bash

BOOTSTRAPURL=`curl -s https://api.github.com/repos/bulwark-crypto/bulwark/releases/latest | grep bootstrap.dat.xz | grep browser_download_url | cut -d '"' -f 4`
BOOTSTRAPARCHIVE="bootstrap.dat.xz"

clear
echo "This script will refresh your masternode."
read -p "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

USER=`ps u $(pgrep bulwarkd) | grep bulwarkd | cut -d " " -f 1`
USERHOME=`eval echo "~$USER"`

if [ -e /etc/systemd/system/bulwarkd.service ]; then
  systemctl stop bulwarkd
else
  su -c "bulwark-cli stop" $USER
fi

echo "Refreshing node, please wait."

sleep 5

rm -rf $USERHOME/.bulwark/blocks
rm -rf $USERHOME/.bulwark/database
rm -rf $USERHOME/.bulwark/chainstate
rm -rf $USERHOME/.bulwark/peers.dat

cp $USERHOME/.bulwark/bulwark.conf $USERHOME/.bulwark/bulwark.conf.backup
sed -i '/^addnode/d' $USERHOME/.bulwark/bulwark.conf

echo "Installing bootstrap file..."
wget $BOOTSTRAPURL && xz -cd $BOOTSTRAPARCHIVE > $USERHOME/.bulwark/bootstrap.dat && rm $BOOTSTRAPARCHIVE

if [ -e /etc/systemd/system/bulwarkd.service ]; then
  sudo systemctl start bulwarkd
else
  su -c "bulwarkd -daemon" $USER
fi

clear

echo "Your masternode is syncing. Please wait for this process to finish."
echo "This can take up to a few hours. Do not close this window." && echo ""

until [ -n "$(bulwark-cli getconnectioncount 2>/dev/null)"  ]; do
  sleep 1
done

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

read -p "Press Enter to continue after you've done that. " -n1 -s

clear

sleep 1
su -c "/usr/local/bin/bulwark-cli startmasternode local false" $USER
sleep 1
clear
su -c "/usr/local/bin/bulwark-cli masternode status" $USER
sleep 5

echo "" && echo "Masternode refresh completed." && echo ""
