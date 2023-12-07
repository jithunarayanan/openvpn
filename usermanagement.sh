#!/bin/bash
#Description: This script will generate a Google MFA bar code for the user

VPN-NAME=myvpn

if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit
fi


addnewuser () {
    useradd -m $1 -s /sbin/nologin
    echo "Enter a password for the user"
    passwd $1
    #echo "$username ALL=(ALL:ALL) ALL" >> /etc/sudoers
    sudo su -c "google-authenticator -t -d -r3 -R30 -f -l "$vpn myvpn" -s /etc/openvpn/google-authenticator/$1" - gauth
}

new_client () {
    
	# Generates the custom client.ovpn
	{
	cat /etc/openvpn/server/client-common.txt
	echo "<ca>"
	cat /etc/openvpn/server/easy-rsa/pki/ca.crt
	echo "</ca>"
	echo "<cert>"
	sed -ne '/BEGIN CERTIFICATE/,$ p' /etc/openvpn/server/easy-rsa/pki/issued/"$1".crt
	echo "</cert>"
	echo "<key>"
	cat /etc/openvpn/server/easy-rsa/pki/private/"$1".key
	echo "</key>"
	echo "<tls-crypt>"
	sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/server/tc.key
	echo "</tls-crypt>"
#	echo "dhcp-option DNS 8.8.8.8"
	echo "reneg-sec 36000"
	echo "auth-user-pass"
	} > ~/"$1".ovpn
}


add_ovpn_user () {
	echo
	echo "Tell me a name for the client certificate."
	read -p "Client name: " unsanitized_client
	client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")
	while [[ -z "$client" || -e /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt ]]; do
		echo "$client: invalid client name."
		read -p "Client name: " unsanitized_client
		client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")
	done


	cd /etc/openvpn/server/easy-rsa/
	EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-client-full "$client" nopass
	# Generates the custom client.ovpn
	new_client "$client"

    checkuser=`cat /etc/passwd | grep $client | cut -d: -f1 | head -n1`

    if [[ "$client" == "$checkuser" ]]
    then
        read -p "$client already exist do you want to create another token? " -n 1 -r
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            addnewuser "$client"
        else
            exit 1
        fi
    fi

    if [[ "$client" != "$checkuser" ]]
    then
        addnewuser "$client"
    fi

	echo
	echo "Client $client added, configuration is available at:" ~/"$client.ovpn"
	exit

}


revoke_cert() {
# This option could be documented a bit better and maybe even be simplified
    # ...but what can I say, I want some sleep too
    number_of_clients=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep -c "^V")
    if [[ "$number_of_clients" = 0 ]]; then
        echo
        echo "You have no existing clients!"
        exit
    fi
    echo
    echo "Select the existing client certificate you want to revoke:"
    tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
    read -p "Select one client: " client_number
    until [[ "$client_number" =~ ^[0-9]+$ && "$client_number" -le "$number_of_clients" ]]; do
        echo "$client_number: invalid selection."
        read -p "Select one client: " client_number
    done
    client=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$client_number"p)
    echo
    read -p "Do you really want to revoke access for client $client? [y/N]: " revoke
    until [[ "$revoke" =~ ^[yYnN]*$ ]]; do
        echo "$revoke: invalid selection."
        read -p "Do you really want to revoke access for client $client? [y/N]: " revoke
    done
    if [[ "$revoke" =~ ^[yY]$ ]]; then
        cd /etc/openvpn/server/easy-rsa/
        ./easyrsa --batch revoke "$client"
        EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
        rm -f pki/reqs/"$client".req
        rm -f pki/private/"$client".key
        rm -f pki/issued/"$client".crt
        rm -f /etc/openvpn/server/crl.pem
        cp /etc/openvpn/server/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem
        # CRL is read with each client connection, when OpenVPN is dropped to nobody
        chown nobody:"$group_name" /etc/openvpn/server/crl.pem
        echo
        echo "Certificate for client $client revoked!"
    else
        echo
        echo "Certificate revocation for client $client aborted!"
    fi
    exit

    read -p "Do you want to remove this linux user? [y/N]: " yesno
    if [[ "$yesno" =~ ^[yY]$ ]]; then
        sudo userdel $client
    else
        echo "Openvpn certificate revoked and you have to disable or remove linux user if not required"
    fi
}



while :
do
clear
    echo "Add user to openvpn."
	echo
	echo "What do you want to do?"
	echo "   1) Add a new user"
	echo "   2) Revoke an existing user"
    echo "   3) Exit"
	read -p "Select an option: " option
	until [[ "$option" =~ ^[1-4]$ ]]; do
		echo "$option: invalid selection."
		read -p "Select an option: " option
	done

    case "$option" in
	    1) 
		    echo
            add_ovpn_user
            exit
		    ;;
	    2) 
		    echo
            revoke_cert
            exit
		    ;;
	    3) 
            exit;;
    esac
done
