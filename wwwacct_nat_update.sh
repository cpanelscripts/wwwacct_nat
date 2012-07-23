#!/bin/bash
myfile=/scripts/wwwacct_nat.sh
mycurversion=$(awk 'NR==6 {print}' $myfile | cut -d'=' -f2)
mycurbuild=$(awk 'NR==7 {print}' $myfile | cut -d'=' -f2)
echo ""
echo "+===================================+"
echo "|    [ Build: $mycurbuild Ver: $mycurversion ]     |"
echo "+===================================+"
echo ""
echo "What Build Would You Like?"
echo "edge? stable? release?"
read mybuild
echo "Checking GitHubs Version Number"
mygitversion=$(curl -s -B -L https://raw.github.com/cpanelscripts/wwwacct_nat/master/stable/wwwacct_nat.sh | grep myversion= | cut -d'=' -f2)
echo ""

function check_update {
if [ "$mygitversion" = "" ]; then
echo "GitHub Returned..."
echo "Version: $mygitversion"
exit
else
  echo "+===================================+"
  echo "|   [ Build: $mycurbuild GitVer: $mygitversion ]   |"
  echo "+===================================+"
  echo ""
  if [ "$mygitversion" -gt "$mycurversion" ]; then
    echo "update is needed"
    update
    else
    echo "no update is needed"
  fi
fi
}

function get_update {
  if [ ! -f $myfile.tmp ]; then
    echo "attempting to download update from github"
    myupdateurl="https://raw.github.com/cpanelscripts/wwwacct_nat/master/$mybuild/wwwacct_nat.sh"
    wget -O $myfile.tmp $myupdateurl 1> /dev/null
  fi
  echo "checking again (in case download failed)"
  if [ ! -f $myfile.tmp ]; then
    echo "update still not found"
  fi
}

function execute_update {
  mv -f $myfile.tmp $myfile
  echo "executing updated file"
  chmod +x $myfile
  $myfile
}

function update {
  get_update
  execute_update
  exit 0 # must exit, or script will recursively call itself for all eternity
}

check_update # make the magic happen
