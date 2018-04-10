#!/bin/bash
#showing user that it's now running.
echo Setting up mninfo scripts..
cd ~

#Moves scripts from the cloned directory to the appropriate cron directories.
mv ~/Bulwark-MN-Install/mninfo/mninfo.sh /etc/cron.hourly/mninfo.sh
mv ~/Bulwark-MN-Install/mninfo/mninfo2.sh /etc/cron.hourly/mninfo2.sh
mv ~/Bulwark-MN-Install/mninfo/mninfoarchive.sh /etc/cron.daily/mninfoarchive.sh

#Removes scripts from the cloned directory.
rm -rf ~/Bulwark-MN-Install/mninfo/

#Assigns permissions to the scripts.
chmod 755 /etc/cron.daily/mninfoarchive.sh
chmod 755 /etc/cron.hourly/mninfo.sh
chmod 755 /etc/cron.hourly/mninfo2.sh

#Makes the archive directory and an empty hourly status document.
mkdir ~/.Bulwark/mninfoarchive
touch ~/.Bulwark/hourly_status.txt

#Adds scripts to crontab and lets user know.
echo Scheduling scripts..
(crontab -l 2>/dev/null; echo "*/0 * * * * /etc/cron.hourly/mninfo.sh -with args") | crontab -
(crontab -l 2>/dev/null; echo "*/55 23 * * * /etc/cron.daily/mninfoarchive.sh -with args") | crontab -

#Add PGP key for nginx and let user know we are setting up web server.
cd ~
echo Setting up web server via nginx.
sudo apt-key add nginx_signing.key
deb http://nginx.org/packages/ubuntu/ xenial nginx > /etc/apt/sources.list
deb-src http://nginx.org/packages/ubuntu/ xenial nginx > /etc/apt/sources.list

#Self explanatory.
echo Installing nginx..
apt-get update
apt-get install nginx

echo Starting nginx server..
/usr/bin/nginx
