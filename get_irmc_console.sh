#!/bin/bash

CURL=`which curl`
JAVAWS=`which javaws`

function show_usage() {
    echo ""
    echo "Usage:"
    echo "    $(basename $0) -i  [-u ] [-p ]"
    echo ""
    exit 1
}

function get_irmcs4_console() {
    local irmc=$1
    local user=$2
    local password=$3

    if [ -f avr.jnlp ]; then
        rm -f avr.jnlp
    fi

    ${CURL} -k -s -u ${user}:${password} --digest https://${irmc}/avr.jnlp -o avr.jnlp

    if [ $? -eq 0 -a -f avr.jnlp ]; then
        ${JAVAWS} avr.jnlp
    fi
}

function get_irmcs5_console() {
    local irmc=$1
    local user=$2
    local password=$3

    if [ -f avr.jnlp ]; then
        rm -f avr.jnlp
    fi
    TOKEN=$(${CURL} -i -s -k -u admin:admin -H "Accept: application/json" -H"Content-Type: application/json" https://${irmc}/redfish/v1/SessionService/Sessions -d "{\"UserName\": \"${user}\", \"Password\": \"${password}\"}" |grep "X-Auth-Token" |awk -F':' '{print $2}')

    if [ -z ${TOKEN} ]; then
        echo "ERROR: Could not get the auth token from iRMC"
        exit 1
    else
        ${CURL} -k -s -H "X-Auth-Token: ${TOKEN}" https://${irmc}/avr.jnlp -o avr.jnlp
    fi

    if [ $? -eq 0 -a -f avr.jnlp ]; then
        grep "jnlp" avr.jnlp
        if [ $? -ne 0  ]; then
            echo "ERROR: HTML5 Viewer is used in iRMC"
        else
            ${JAVAWS} avr.jnlp
        fi
    fi
}

while getopts 'i:u:p:h' OPT
do
    case ${OPT} in
        i) iRMC_ADDR=${OPTARG}
            ;;
        u) iRMC_USER=${OPTARG}
            ;;
        p) iRMC_PASS=${OPTARG}
            ;;
        h) show_usage
            ;;
        \?) show_usage
            ;;
    esac
done
shift $((OPTIND - 1))

if [ -z ${iRMC_ADDR} ]; then
    echo "ERROR: iRMC address/name/FQDN is not provided. Please use the '-i' option."
    exit 1
fi

if [ -z ${iRMC_USER} ]; then
    iRMC_USER="admin"
fi

if [ -z ${iRMC_PASS} ]; then
    iRMC_PASS="admin"
fi


${CURL} -s -k https://${iRMC_ADDR}/ | grep "iRMC S5" > /dev/null

if [ $? -eq 0 ]; then
    get_irmcs5_console ${iRMC_ADDR} ${iRMC_USER} ${iRMC_PASS}
    exit
fi

${CURL} -s -k https://${iRMC_ADDR}/ | grep "iRMC S[2-4]" > /dev/null

if [ $? -eq 0 ]; then
    get_irmcs4_console ${iRMC_ADDR} ${iRMC_USER} ${iRMC_PASS}
    exit
fi

echo "ERROR: Could not access the iRMC"
exit 1
