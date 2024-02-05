#!/usr/bin/env bash

# Script for making life easier when connecting to MWP ansible deployment servers.

export PSMP_SERVER=phx.psmp.dc1.ca.iam.int.gd3p.tools
   
# The location you store your SSH certs.
export SSH_CERTS_DIR=$HOME/.ssh

# However you retrieve your JOMAX password. This must be a command that sends the password to stdout. Example: PASSCMD="gpg --decrypt .shadow.gpg"
export PASSCMD="lpass show -G JOMAX --field=password" 

# Your ADS hosts. This is in the form of an associative array so [<hostname>]=<ipaddress>
declare -A ADS_HOSTS=([p3plwpads01.cloud.phx3.gdg]=10.39.147.172
                      [p3plwpads02.cloud.phx3.gdg]=10.39.146.53);

function main {

check_binaries

build_menu
    
if [[ ${!ADS_HOSTS[@]} =~ $CHOICE ]]; then
    ssh_to_ads
fi

if [[ $CHOICE == "Upload Certificates" ]]; then
    read -p "Would you like to download your SSH certificates first? If no, proceed to upload. (y/n)"

    if [[ $REPLY =~ ^[Yy]|yes$ ]]; then
        download_certs $(fetch_sso_token)
        extract_certs
        upload_certs
    else
        upload_certs
    fi
fi

if [[ $CHOICE == "Quit" ]];  then
    echo "Bye"
    exit 0
fi
}

function build_menu {
declare -a MENU=($(printf "%s\n" ${!ADS_HOSTS[@]}|tac) "Upload Certificates" "Quit");

PS3="Select your ADS Host: "

while true; do
    select CHOICE in "${MENU[@]}" ; do
        case $1 in 
            *) [[ ${ADS_HOSTS[*]} =~ $1 ]] \
                && echo "Connecting to ${!ADS_HOSTS[$1]}" \
                && break 2;;&
            *) break 2;;
        esac
    done
done
}

function ssh_to_ads {
local ADS_FLOATING_IP=${ADS_HOSTS[$CHOICE]}
local COMMAND="ssh -q -oStrictHostKeyChecking=no -oCheckHostIP=no -oServerAliveInterval=45 -oServerAliveCountMax=300 ${USER}@${USER}#dc1.corp.gd@${ADS_FLOATING_IP}@${PSMP_SERVER}"
login_expect
}


function upload_certs {
for ADS_HOST in "${!ADS_HOSTS[@]}"; do
    local ADS_FLOATING_IP="${ADS_HOSTS[$ADS_HOST]}"
    echo "Preparing to upload certificates to ${ADS_HOST}(${ADS_FLOATING_IP})..."
    COMMAND="rsync -a --include \"${USER}-wpaas*\" --exclude \"*\" \"${SSH_CERTS_DIR}/\" \"${USER}@${USER}#dc1.corp.gd@${ADS_FLOATING_IP}@${PSMP_SERVER}:~/.ssh/\""
    login_expect && echo "Certificates Uploaded!"
done
}

function login_expect {
/usr/bin/expect -c "
    log_user 0
    spawn $COMMAND
    sleep 1
    expect {
        \"*JOMAX*\" {
            send \"$(${PASSCMD})\r\r\"
            exp_continue
        }
        \"*authentication\ method*\" {
            send \"2\r\"
            log_user 1
            send_user \"\nPlease Activate Yubikey now!\n\"
            log_user 0
            exp_continue
            log_user 1
        }
    }   
     interact {
        \"*Yubikey*\" {
            expect_user -re \"(.*)\n\" {
                set input $expect_out(1,string) 
            }
    }
}"
}

function extract_certs {
    echo "Extracting certificates into ${SSH_CERTS_DIR}/"
    mkdir -p ${SSH_CERTS_DIR}
    unzip -qq -o ${SSH_CERTS_DIR}/certs.zip -d ${SSH_CERTS_DIR}/
    rm ${SSH_CERTS_DIR}/certs.zip
    chmod 600 ${SSH_CERTS_DIR}/${USER}-wpaas*
}

function download_certs {
    local jwt=$1
    echo "Downloading certificates using the sso token"
    if ! curl -f -s https://certaccess.int.godaddy.com/generate -H "Authorization: sso-jwt ${jwt}" -o ${SSH_CERTS_DIR}/certs.zip; then
		echo "Failed to download certs"
    	echo "Is the VPN connected?"
	    exit 1
    fi
}

function fetch_sso_token {
	local jwt
	if ! jwt=$(ssojwt); then
		echo "Failed to get jwt token with ssojwt"
		exit 1
	fi
	printf "%s" "$jwt"
}

function check_binaries {
    if ! command -v ssojwt &> /dev/null; then
        echo -e "WARNING: This script requires \e[4mssojwt\e[0m to properly run. Please install \e[4mssojwt\e[0m from https://github.com/gdcorp-engineering/ssojwt/releases before continuing"
        exit 1;
    fi

    if ! command -v unzip &> /dev/null; then
        echo -e "WARNING: This script requires \e[4munzip\e[0m to properly run. Please install \e[4munzip\e[0m before continuing"
        exit 1;
    fi

    if ! command -v curl &> /dev/null; then
        echo -e "WARNING: This script requires \e[4curl\e[0m to properly run. Please install \e[4mcurl\e[0m before continuing"
        exit 1;
    fi

    if ! command -v expect &> /dev/null; then
        echo -e "WARNING: This script requires \e[4expect\e[0m to properly run. Please install \e[4expect\e[0m before continuing"
        exit 1;
    fi
}

main; unset -f main;
