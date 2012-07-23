#!/bin/bash
# cpanel - wwwacct_nat.sh                         Copyright(c) 2008 cPanel, Inc.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited
myversion=001
mybuild=STABLE
echo ""
echo "This script is designed to help you run cPanel/WHM behind a NAT/ROUTER"
echo "Based network 192.168.x.xxx take Extra Caution when using this script"
echo "Please view the readme that comes with this script before using it."
echo ""
echo "+===================================+"
echo "| Dependency Check                  |"
echo "+===================================+"
rootcheck=$(echo $USER); if [ "$rootcheck" = "root" ]; then
echo "| running as user $rootcheck      [ OK ]   "
else
echo "| running as user root      [FAIL]   "
echo "+===================================+"
echo "Script Halted!"
exit
fi
if [ -f /etc/wwwacct.conf ]; then
echo "| cPanel wwwacct.conf       [ OK ]   "
else
echo "| cPanel wwwacct.conf       [FAIL]   "
echo "+===================================+"
echo "Script Halted!"
exit
fi
mycurl="`which /usr/bin/curl 2> /dev/null`"; if [ "$mycurl" != "" ]; then
echo "| $mycurl             [ OK ]   "
else
echo "| /usr/bin/curl             [FAIL]   "
fi
mysed="`which /bin/sed 2> /dev/null`"; if [ "$mysed" != "" ]; then
echo "| $mysed                  [ OK ]   "
else
echo "| /bin/sed                  [FAIL]   "
fi
mywget="`which /usr/bin/wget 2> /dev/null`"; if [ "$mywget" != "" ]; then
echo "| $mywget             [ OK ]   "
else
echo "| /usr/bin/wget             [FAIL]   "
fi
echo "+===================================+"
sleep 2
addr=$(awk '/ADDR/ { print $2 }' /etc/wwwacct.conf)
ethdev=$(awk '/ETHDEV/ { print $2 }' /etc/wwwacct.conf)
lanaddr=$(ifconfig $ethdev | grep 'inet addr:'| cut -d: -f2 | awk '{ print $1}')
replace $addr $lanaddr -- /etc/wwwacct.conf 1> /dev/null
mainip=$(awk '{ print $1 }' /var/cpanel/mainip)
echo ""
echo "+===================================+"
echo "| We Have Detected                  |"
echo "+===================================+"
echo "| Main/DNS IP: $mainip"
echo "| Shared/NAT IP: $lanaddr"
echo "+===================================+"
while true; do
echo ""
echo "+===================================+"
echo "|       cPanel NAT Main Menu        |"
echo "+===================================+"
echo "| 1) First Time Setup"
echo "| 2) Update Everything"
echo "| 3) New Account"
echo "| 4) Del Account"
echo "| 5) Sub-Domains *use caution*"
echo "| 6) Check GitHub To Update Script"
echo "| 7) Quit"
echo "+===================================+"
echo "|    [ Build: $mybuild Ver: $myversion ]     |"
echo "+===================================+"
read case;
echo ""
case $case in
  1)  
echo "Detecting WAN IP (using curl)"
echo "Should Be Quick"
wanip=$(curl -s http://www.cpanel.net/myip)
echo $wanip > /var/cpanel/mainip
echo "Main IP Updated To $wanip"
echo "Fixing Proxy Domains For NAT"
replace proxysubdomainsfornewaccounts=1 proxysubdomainsfornewaccounts=0 -- /var/cpanel/cpanel.config
/usr/local/cpanel/whostmgr/bin/whostmgr2 --updatetweaksettings 1> /dev/null;;
  2)
echo "Detecting WAN IP (using curl)"
echo "Should Be Quick"
wanip=$(curl -s http://www.cpanel.net/myip)
echo ""
echo "+===================================+"
echo "| We Have Detected                  |"
echo "+===================================+"
echo "| Old IP: $mainip"
echo "| New IP: $wanip"
echo "+===================================+"
echo ""
echo "Updating NameServer IPs"
replace $mainip $wanip -- /etc/nameserverips
echo "Updating DNS With $wanip"
for domain in `ls /var/named|grep '\.db$'`; do
if [ -f "/var/named/$domain" ] ; then
arecord=$(grep -E 'ftp IN A' /var/named/$domain|awk '{print $4}')
echo "Updating $domain From $arecord To $wanip"
replace $arecord $wanip -- /var/named/$domain 1> /dev/null
fi
done
echo "Updating cPanel IPs"
replace $mainip $wanip -- /var/cpanel/mainip
replace $mainip $wanip -- /etc/secondary.ip
replace $mainip $wanip -- /etc/hosts
replace $mainip $wanip -- /etc/mail_reverse_dns
replace $wanip $lanaddr -- /var/cpanel/users/*
echo "Fixing Proxy Domains For NAT"
replace proxysubdomainsfornewaccounts=1 proxysubdomainsfornewaccounts=0 -- /var/cpanel/cpanel.config
/usr/local/cpanel/whostmgr/bin/whostmgr2 --updatetweaksettings 1> /dev/null;;
  3)
echo "What is the domain name you would like to setup?"
echo -n ""
read -e domain
echo ""
echo "What username would you like to setup?"
echo -n ""
read -e user
echo ""
echo "What password would you like to setup?"
echo -n ""
read -e pass
echo ""
echo "Preparing DNS Zones For WAN IP"
echo "Detecting Zone Template Backups"
dir=/var/cpanel/zonetemplates/backup
echo ""
if [ -d $dir ]; then
echo "Backups Exist Copying To Main Folder For Setup"
  for mytemplate in `ls /var/cpanel/zonetemplates/*`; do
  if [ -f "$mytemplate" ] ; then
  rm -f $mytemplate
  fi
  done
cp $dir/* /var/cpanel/zonetemplates
else
echo "No Backups Found"
echo "Backing Up"
mkdir $dir
  for mybackup in `ls /var/cpanel/zonetemplates/*`; do
  if [ -f "$mybackup" ] ; then
  cp $mybackup $dir
  fi
  done
fi
echo ""
echo "Setting Up Zone Templates With $mainip"
  for mytemplate in `ls /var/cpanel/zonetemplates/*`; do
  if [ -f "$mytemplate" ] ; then
  replace %ip% $mainip -- $mytemplate
  echo "cpanel IN A $mainip" >> $mytemplate
  echo "whm IN A $mainip" >> $mytemplate
  echo "webmail IN A $mainip" >> $mytemplate
  echo "webdisk IN A $mainip" >> $mytemplate
  fi
  done
echo "Done"
echo ""
/scripts/wwwacct $domain $user $pass;;
  4)
/bin/ls -A /var/cpanel/users/
read user
/scripts/killacct --force --killdns $user;;
  5)
echo "What User?"
read user
echo ""
domain=$(awk '/DNS/' /var/cpanel/users/$user | cut -d'=' -f2)
echo "Not The Full Domain (sub.$domain)"
echo "What Is The Sub Part? (sub)"
read subdomain
folder=/home/$user/public_html/$subdomain
if [ ! -d $folder ] ; then 
mkdir $folder; chmod 0755 $folder; chown $user.$user $folder;
fi
echo ""
if [ -f "/var/named/$domain.db" ] ; then
echo "$domain.db Found"
apacheconf=/usr/local/apache/conf/includes
  if [ -f "$apacheconf/$subdomain.$domain.conf" ] ; then
  echo "Sorry Already Exists!"
  echo "Remove [YES/NO]?"
  read myremove
    if [ "$myremove" = "YES" ]; then
    echo "Removing..."
    rm -f $apacheconf/$subdomain.$domain.conf
    sed -i "/$subdomain IN A/d" /var/named/$domain.db
    sed -i "/$subdomain.$domain.conf/d" $apacheconf/post_virtualhost_global.conf
    echo "Restarting httpd"
    service httpd restart
    echo "Restarting bind"
    rndc flush; rndc reload;
    echo "Done"
    else
    echo "Returning To Menu"
    fi
  else
  echo "<virtualhost $lanaddr:80>" > $apacheconf/$subdomain.$domain.conf
  echo "    ServerName $subdomain.$domain" >> $apacheconf/$subdomain.$domain.conf
  echo "    DocumentRoot $folder" >> $apacheconf/$subdomain.$domain.conf
  echo "    ServerAdmin webmaster@$domain" >> $apacheconf/$subdomain.$domain.conf
  echo "    UseCanonicalName Off" >> $apacheconf/$subdomain.$domain.conf
  echo "</virtualhost>" >> $apacheconf/$subdomain.$domain.conf
  echo "Restarting httpd"
  echo "Include conf/includes/$subdomain.$domain.conf" >> $apacheconf/post_virtualhost_global.conf
  service httpd restart
  echo "Restarting bind"
  echo $subdomain IN A $mainip >> /var/named/$domain.db
  rndc flush; rndc reload;
  echo ""
  echo "Files Are In $folder"
  fi
else
echo "$domain.db Not Found"
echo "Halted Returning To Menu"
fi;;
  6)
echo "Downloading Update Script..."
echo "Please Wait"
wget -q -O /scripts/wwwacct_nat_update.sh https://raw.github.com/cpanelscripts/wwwacct_nat/master/wwwacct_nat_update.sh
echo ""
chmod 0755 wwwacct_nat_update.sh && /scripts/wwwacct_nat_update.sh && exit;;
  7)
echo "Thanks For Using This Script"
echo "Quitting"
exit;;
  *)
echo "$case is an invaild option. Please select option between 1-6 only";
sleep 3
clear
esac
done
