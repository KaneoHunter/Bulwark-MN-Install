#!/bin/bash
touch ~/.bulwark/hourly_status.txt
date '+%A %W %Y %X' >> ~/.bulwark/hourly_status.txt
bulwark-cli getblockchaininfo >> ~/.bulwark/hourly_status.txt
bulwark-cli masternode status >> ~/.bulwark/hourly_status.txt
bulwark-cli getinfo >> ~/.bulwark/hourly_status.txt
echo "" >> ~/.bulwark/hourly_status.txt
