#!/usr/bin/env bash
red='\033[0;31m'
yellow='\033[1;33m'
blue='\e[34m'
green='\e[42m'
NC='\033[0m' # No Color, back to default

# echo -e "${green}GREEN TEST"
# stop

show_DigitalOcean_PW () {
    
    #test if on digital ocean
    if [ -e ~/.digitalocean_password ]
    then
        
        echo -e "${yellow}You appear to be on ${blue} Digital Ocean!${yellow}, \nplease note that the MySQL password is in a file at ~/.digitalocean_password"
        echo -e "${yellow}It currently contains:  \e[39m"
        cat ~/.digitalocean_password
    fi
    if [ -e /home/larasail/.my.cnf ]
    then
        
        echo -e "${yellow}You appear to be on ${blue} Digital Ocean!${yellow}, in a laravel / larasail environment"
        echo -e "${yellow}It currently contains:  \e[39m"
        cat /home/larasail/.my.cnf
    fi
}

Linux_version_test () {
    #linux disto and version check
    if [ ! -e /etc/os-release ]
    then
        echo "Sorry.  \n /etc/os-release does not exist"
        exit 1
    else
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID

        # echo "OS: "$OS
        # echo "Version: "$VER

        if [ $OS == 'Ubuntu' ] && { [ $VER == '16.04' ] || [ $VER == '17.10' ] || [ $VER == '18.04' ] || [ $VER == '20.04' ] || [ $VER == '22.04' ]; }
        then
            echo "Ubuntu 16.04/17.10/18.04 verified.  Continuing."
        else
            echo "Sorry - Written for Ubuntu 16.04/17.10/18.04 specifically"
            echo "Your appear to be running OS:$OS $VER"
            echo ""
            exit
        fi
        
    fi
}

test_root_Home_Dir () {
    # test if root user and test if in home directory
    #if [[ "$USER" != "root" ]]
    if [[ $EUID -ne 0 ]]
    then
        echo -e "${red}This script must be run as root"
        exit 1
    fi
    if [ $HOME != "`pwd`" ]
    then
        echo "The present working directory is: `pwd`"
        echo "Please run this from your Home directory: "$HOME
        exit 1
    fi
}

Open_firewall () {
    
    
    echo "Open Firewall to your specific IP address."
    echo "I believe your IP address is:"
    #who am i|awk '{ print $5}'
    yourip=`who am i|awk '{ print $5}'`
    cleanip=`echo $yourip | sed 's/[()]//g'`  #remove ( )
    echo $cleanip
    echo "----------------"
    echo "About to run command:   "
    fw_cmd="ufw allow from $cleanip to any port 3306"
    echo $fw_cmd
    echo "proceed?"
    read -p " Please press Y to continue, or N to stop (y/n)" -n 1 -r
    echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]
        then
        eval $fw_cmd
    fi
    
}
Make_remote_user () {
echo -e "First let's test you have root access to MySQL.${NC}"
read -s -p "Enter MYSQL root password: " mysqlRootPassword

while ! mysql -u root -p$mysqlRootPassword  -e ";" ; do
       read -s -p "${red}Can't connect, please retry: ${NC}" mysqlRootPassword
done
echo -e "${green}"
echo -e "${green}SUCCESS!${yellow}"
echo -e "${NC}${yellow}FYI, current users:"
mysql -u root -p$mysqlRootPassword  -e "use mysql;select host,user from user"


echo -e "NOTE: It's recommend to create a remote user and to NOT use root as the remote user."
echo -e "------------------------------------------------------------------------------------${NC}"
echo -e "Enter remote username: "
read remoteUserName
echo -e "enter password for remote user: '$remoteUserName' : "
read remotePassword
echo " "
printf "${yellow}Attempting to create remote user...\n"
#TODO: fix this grant error.  may want to keep it though to use for older versions of maria/mysql
#TODO: test for running version of mysql/mariadb and apply appropriate version below
#reference:  https://techglimpse.com/error-grant-identified-by-password/

#oldversion for MySQL below v. 5.7.6
mySQLstmt="USE mysql; CREATE USER '$remoteUserName'@'%' IDENTIFIED BY '$remotePassword'; GRANT ALL PRIVILEGES ON *.* TO '$remoteUserName'@'%' IDENTIFIED BY '$remotePassword' WITH GRANT OPTION; FLUSH PRIVILEGES;"
#new Version
mySQLstmt="USE mysql; CREATE USER '$remoteUserName'@'%' IDENTIFIED BY '$remotePassword'; GRANT ALL PRIVILEGES ON *.* TO '$remoteUserName'@'%'; FLUSH PRIVILEGES;"

echo -e "${NC}USE mysql; CREATE USER '$remoteUserName'@'%' IDENTIFIED BY '$remotePassword'; GRANT ALL PRIVILEGES ON *.* TO '$remoteUserName'@'%' IDENTIFIED BY '$remotePassword' WITH GRANT OPTION; FLUSH PRIVILEGES;\n"
echo mySQLStmt
echo "are those 2 above exactly the same?"

mysql -u root -p$mysqlRootPassword  -e "${mySQLstmt}"
if [ $? -eq 0 ]
then
  echo -e "${green}Successfully created remote user!${NC} $remoteUserName${yellow}"
  # exit 0
else
  printf "${red}Error.\nError.\nError.\nSorry Dave, I'm afraid I can't do that.\nPerhaps user already exists?\n${yellow}" >&2
  
fi
}

mysql_test() {

    if [ -e /etc/mysql/mysql.conf.d/mysqld.cnf ]
    then
        echo "Making change to mysqld.cnf"
        sed -i.bak 's/^bind-address/#bind-address/' /etc/mysql/mysql.conf.d/mysqld.cnf
        #restart MySQL
        echo "Restarting MySQL"
        service mysql restart
       
        
        #want to create a mysql Remote user?
    else
        echo -e "${red}mysqld.cnf NOT found at \n /etc/mysql/mysql.conf.d/mysqld.cnf"
        echo "NOTE: This script is intended for Ubuntu 16-18 {yellow}"
        # exit 0
    fi
    }


mariadb_test () {
    echo "it's MariaDB!"
    mbcmd='/etc/mysql/my.cnf'
    if test -f "$mbcmd"; then
        echo "$mbcmd exists!"
        echo "Making change to $mbcmd"
        sed -i.bak 's/^bind-address/#bind-address/' "$mbcmd"
        echo "Restarting MySQL"
        service mysql restart
    fi
}

Linux_version_test
test_root_Home_Dir
Open_firewall


#set -x  #echo on;
echo -e "${yellow}The intention of this script is to make all changes neccesary to enable MariaDB / MySQL accessible remotely, \nand optionally create a remote user"
#run as root, this makes a backup called mysqld.cnf.bak in same etc directory
echo "-----------------------------------"
read -p " Please press Y to continue, or N to stop" -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then

testmariadb=$(mysql --version)
if [[ $testmariadb == *"Maria"* ]]; then 
    mariadb_test
else
    mysql_test
fi

    show_DigitalOcean_PW
    
    echo -e "${yellow}Want to log in to mysql and make a remote user?  (you will need to provide mysql root password) "
    read -p " Please press Y to continue, or N to stop" -n 1 -r
    echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo -e "NOTE: It's recommend to create a remote user and to NOT use root as the remote user."
        # mysql -uroot -pecho -e "${yellow}Want to log in to mysql and make a remote user?  (you will need to provide mysql root password) "
    read -p " Please press Y to continue, or N to stop" -n 1 -r
    echo    # (optional) move to a new line
    fi
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        
        Make_remote_user
        

    fi
    
fi


echo -e "${NC}"
