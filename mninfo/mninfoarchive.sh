#!bin/bash
whoami
_now=$(date +%d_%m_%y)
mv ~/.bulwark/hourly_status.txt ~/.bulwark/mninfoarchive/$_now.txt
echo "Archived hourly_update.txt to ~/.bulwark/mninfoarchive/$_now.txt..." > ~/.bulwark/hourly_status.txt
echo "" >> ~/.bulwark/hourly_status.txt