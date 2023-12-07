# OpenVPN + MFA (Google Authenticator)
<div style="text-align:center">
  <img src="./openvpn_logo.png" alt="wireguard" />
</div>          
This is a good setup for seccurly connect to your bastion with openvpn connection. You can seccurly access your servers with key or password. You will use private ip address of the servers (It may dosent have a public IP address).

## VPN Background

The way users currently authenticate is using a client-based .ovpn profile, along with username and password. To add another layer of security, adding a2 Factor Authentication mechanism for each user, they will login as usual, but will need to use a time-based token (provided by Google authenticator) tologin to our company’s networks.

## Installation
Simply run Install.sh script
The way users currently authenticate is using a client-based .ovpn profile, along with username and password. To add another layer of security, adding a2 Factor Authentication mechanism for each user, they will login as usual, but will need to use a time-based token (provided by Google authenticator) tologin to our company’s networks.

## Create a new user with MFA
Simply run user.sh script. this scrip can also use for remove a user. Cpoy the Google authenticator link, barcode backup codes for login to the server. Also you can copy users ovpn file from /root directory.


## Troubleshooting
**PAM issues**
See the PAM guide [here](https://docs.freebsd.org/en/articles/pam/#pam-essentials)

Test Google Authenticator plugin by logging in as a user + their 2FA code,

adjust your /etc/pam.d/openvpn to only have this 1 line,
```
auth requisite /usr/lib64/security/pam_google_authenticator.so 
secret=/opt/openvpn/google-auth/${USER} user=root authtok_prompt=pin
```
Now test with pamtester

```
yum install pamtester
apt install pamtester
pamtester openvpn <username> authenticate
```

If there are additional PAM issues, use the pam_permit to always give access, regardless of failures and watch the system message logs (also change the verb in /etc/openvpn/server.conf to 5 or higher)

Debug PAM by using pam_permit (this allows all authentication to proceed — used only for debug purposes, do not run production with this!)

update /etc/pam.d/openvpn

```
auth requisite /usr/lib64/security/pam_google_authenticator.so 
secret=/opt/openvpn/google-auth/${USER} 
user=root authtok_prompt=pin debug forward_pass
account required  pam_permit.so debug
```

**Client connection timeout after 60 min**
By default, OpenVPN will attempt to have a client renegotiation every 60 minutes (3600 sec), which will prompt the user to enter their 2FA pin to continue the connection.

If you want unlimited connection without these interruptions, update the /etc/openvpn/client-template.txt file and add “reneg-sec 0” parameter

this file should look like this:

Now any new VPN profile that you generate will include this reneg parameter, which tells the client to have infinite connection w/o a renegotiation.

**Addition**

1. Uncomment line (346) from openvpn-install.sh to route all the traffic (internet) through the vpn.

   ```#echo 'push "redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/server/server.conf```

2. For existing vpn add the line ```push "redirect-gateway def1 bypass-dhcp"``` to /etc/openvpn/server/server.conf for routing internet via vpn and if exist comment the line to use the existing internet connection.

3. Change the lines from 341-345 according to the environment where the vpn is installed. Those lines push vpc cidr to clients, through which the client will be able to access those networks via the vpn.

   ``` echo 'push "route 10.111.0.0 255.255.0.0"' >> /etc/openvpn/server/server.conf ```

4. Line 338 ```server 10.9.0.0 255.255.255.0``` specify the network from which the IP to be assigned when the clients connects via the vpn.

## Outcome


