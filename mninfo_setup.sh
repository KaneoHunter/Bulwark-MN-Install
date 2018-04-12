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
chmod 755 /etc/cron.daily/mninfoarchive.sh /etc/cron.hourly/mninfo.sh /etc/cron.hourly/mninfo2.sh

#Makes the archive directory and an empty hourly status document.
mkdir ~/.bulwark/mninfoarchive
touch ~/.bulwark/hourly_status.txt

#Adds scripts to crontab and lets user know.
echo Scheduling scripts..
(crontab -l 2>/dev/null; echo "0 * * * * /etc/cron.hourly/mninfo.sh -with args") | crontab -
(crontab -l 2>/dev/null; echo "55 23 * * * /etc/cron.daily/mninfoarchive.sh -with args") | crontab -

#Add PGP key for nginx and let user know we are setting up web server.
cd ~
echo Setting up web server via nginx.
mv ~/Bulwark-MN-Install/nginx_configs/nginx_signing.key.txt /etc/apt/nginx_signing.key
sudo apt-key add /etc/apt/nginx_signing.key
deb http://nginx.org/packages/ubuntu/ xenial nginx >> /etc/apt/sources.list
deb-src http://nginx.org/packages/ubuntu/ xenial nginx >> /etc/apt/sources.list

#Self explanatory.
echo Installing nginx..
apt-get update
apt-get install nginx

echo Starting nginx server..
systemctl start nginx

#Setting nginx config
cp -TRv ~/Bulwark-MN-Install/nginx_configs /etc/nginx
rm -r ~Bulwark-MN-Install/nginx_configs

#Reloading config
sudo nginx -s reload

#Final message
clear
echo "Setup complete, you should be able to find your MN information from any browser on "http://<your-MN-IP>/hourly_status.txt" and "http://<your-MN-IP>/mninfoarchive"."
echo Please consider a donation here if you would like to see more community made tools like this -> bPenp1eNYWN1CSP7mrPNjym9vXsAJxrBjj <-
sleep 10

read -p "Press any key to continue... " -n1 -s
