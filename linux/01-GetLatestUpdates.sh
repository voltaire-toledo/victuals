echo
echo "general update shit"
sudo apt update
sudo apt full-upgrade

echo
echo "##### SET AUTOREMOVE #####"
sudo apt autoremove

echo
echo "##### CHECKING FIRMWARE #####"
fwupdmgr get-devices

echo 
echo "##### INSTALL IF UPDATES ARE AVAILBLE #####"
fwupdmgr get-devices
fwupdmgr get-updates

echo "##### REBOOT #####"
# sudo reboot
 
