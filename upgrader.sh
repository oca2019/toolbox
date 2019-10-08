#!/bin/sh
# Script used to check api service

while getopts ":h:p:v:f:d:" opt
do
    case $opt in
        h)
        HOST=$OPTARG
        ;;
        p)
        PRODUCT=$OPTARG
        ;;
        v)
        MAJOR_VERSION=$OPTARG
        ;;
        f)
        UPGRADE_PACKAGE=$OPTARG
        ;;
        d)
        DEBGU=$OPTARG
        ;;
        ?)
        echo "未知参数"
        exit 1;;
    esac
done

function printHelp()
{
    echo "Usage: $0 -h 172.24.0.190 -p BVM -v 2.6.1 [-d yes] [ -f bvm_upgrade.tar.gz ] "
    echo "       -p [UCM|BVM]"
    echo "       -d [yes|no, default is no]"
    echo "       -f [Upgrade with this package and not download from file server]"
}
       
if [[ -z "$HOST" ]] ; then
    printHelp
    exit 1
fi

if [[ "UCM" != "$PRODUCT" ]] && [[ "BVM" != "$PRODUCT" ]] ; then
    printHelp
    exit 1
fi

if [[ ! -f "$UPGRADE_PACKAGE" ]] && [[ -z "$MAJOR_VERSION" ]];then
    echo "Plese specify -v or -f "
    exit 1
fi

echo "           HOST=[$HOST]"
echo "        PRODUCT=[$PRODUCT]"
echo "  MAJOR_VERSION=[$MAJOR_VERSION]"
echo "UPGRADE_PACKAGE=[$UPGRADE_PACKAGE]"

FILE_SERVER_PREFIX=http://172.24.0.249/packages
BVM_PACKAGE_BASE_URL=$FILE_SERVER_PREFIX/bvm/$MAJOR_VERSION
UCM_PACKAGE_BASE_URL=$FILE_SERVER_PREFIX/ucm/$MAJOR_VERSION

CURL_CMD_PREFXI="curl"
if [ "yes" = "$DEBUG" ] ; then
  CURL_CMD_PREFXI="curl -s"
fi

TOKEN=0     ##update it after login
UPGRADE_VERSION=1.0.0.0001

BVM_API_VERSION_URL=http://$HOST/api/rest/v2.0/version
BVM_API_LOGIN_URL=http://$HOST/api/rest/v2.0/login
BVM_API_UPGRADE_URL="http://$HOST/fileServlet?action=upgrade&token="

UCM_API_VERSION_URL=http://$HOST/api/rest/v2.0/version
UCM_API_LOGIN_URL=http://$HOST/api/rest/v2.0/login
UCM_API_UPGRADE_URL="http://$HOST/fileServlet?action=upgrade&userToken="
UCM_API_UPGRADE_CONFIRM_URL="http://$HOST/api/rest/v2.0/upgrade?confirm=true&token="

if [ "BVM" = "$PRODUCT" ] ; then
    PACKAGE_BASE_URL=$BVM_PACKAGE_BASE_URL
    API_VERSION_URL=$BVM_API_VERSION_URL
    API_UPGRADE_URL=$BVM_API_UPGRADE_URL
    API_LOGIN_URL=$BVM_API_LOGIN_URL
elif [ "UCM" = "$PRODUCT" ] ; then
    PACKAGE_BASE_URL=$UCM_PACKAGE_BASE_URL
    API_VERSION_URL=$UCM_API_VERSION_URL
    API_UPGRADE_URL=$UCM_API_UPGRADE_URL
    API_LOGIN_URL=$UCM_API_LOGIN_URL
fi

function login()
{
    echo "------[$FUNCNAME]------"
    time=`date "+%Y-%m-%d %H:%M:%S"`
    echo "Time: [$time]"
    
    loginP=`$CURL_CMD_PREFXI -w "http_code=%{http_code}" $API_LOGIN_URL -X PUT -H "Content-Type:application/json" -d @./$PRODUCT/loginR.json`
    if [ "yes" = "$DEBGU" ]; then
        echo $loginP
    fi
    TOKEN=`echo $loginP | awk -F '"token":' '{print $2}' | awk -F , '{print $1}'|awk -F '"' '{print $2}'`
    echo $TOKEN
}

function upgrade()
{
    echo "------[$FUNCNAME]------"
    time=`date "+%Y-%m-%d %H:%M:%S"`
    echo "[$time]"
    
    if [[ -f "$UPGRADE_PACKAGE" ]];then
        echo "Use local package to upgrade "
    else
        #echo "Download upgrade package"
        downloadPackage
    fi
    
    #echo "login to get token"
    login
    
    if [ -z "$TOKEN" ]; then
        echo "Failed to get token from login request"
        exit 1
    fi
    
    versionP=`$CURL_CMD_PREFXI $API_VERSION_URL`
    echo $versionP
    
    #echo "start to upgrade"
    upgradeP=`$CURL_CMD_PREFXI -F "file=@$UPGRADE_PACKAGE" $API_UPGRADE_URL$TOKEN `
    echo $upgradeP
    
    if [ "UCM" = "$PRODUCT" ]; then
        confirmP=`$CURL_CMD_PREFXI $UCM_API_UPGRADE_CONFIRM_URL$TOKEN -X PUT -H "Content-Type:application/json"`
        echo $confirmP
    fi
}

function downloadPackage()
{
    echo "------[$FUNCNAME]------"
    
    time=`date "+%Y-%m-%d %H:%M:%S"`
    echo "[$time]"
    
    package_base_url=$PACKAGE_BASE_URL
    
    temp=`$CURL_CMD_PREFXI $package_base_url/`
    array=(${temp//HREF/ })  
    UPGRADE_VERSION=`echo ${array[@]: -1} | awk -F ">" '{print $2}' |awk -F "<" '{print $1}'`
   
    echo "New version: [$UPGRADE_VERSION]"
    UPGRADE_PACKAGE=hexmeet_bvm_upgrade_"$UPGRADE_VERSION"_x86_64.tar.gz
    packageUrl=$package_base_url/$UPGRADE_VERSION/hexmeet/$UPGRADE_PACKAGE
    if [ "$MAJOR_VERSION" = "2.5.2" ] ;then  
      packageUrl=$package_base_url/$UPGRADE_VERSION/$UPGRADE_PACKAGE
    fi 
    
    if [ "UCM" = "$PRODUCT" ]; then
        UPGRADE_PACKAGE=uc-upgrade-ucm-only-"$UPGRADE_VERSION".tar.gz
        echo "Upgrade package: [$UPGRADE_PACKAGE]"
        packageUrl=$package_base_url/$UPGRADE_VERSION/$UPGRADE_PACKAGE
    fi
    echo $packageUrl
    
    echo "Remove old package if exists"
    rm -rf $UPGRADE_PACKAGE
    $CURL_CMD_PREFXI -o $UPGRADE_PACKAGE $packageUrl
}

upgrade

echo $TOKEN
echo $UPGRADE_PACKAGE
echo $UPGRADE_VERSION

#downloadPackage
#login 
#upgrade $UPGRADE_PACKAGE
