#Edge Firewall base config

# Update IP value below to reflect your internal management range
# If there is more than one range than add additional ranges to the "management" address list
global ipman 10.0.0.0/8

/interface list
# Add OSPF neighbours to this list
add name=ospf-neighbours

# Add public facing interfaces (including VLANs) to this list
add name=public-in

#Add BFD neighbours to this list
add name=bfd-neighbours

#Add Discovery neighbours to this list
add name=mndp-allowed

#Add Management interfaces to this list
add name=management

# Disable all router services not generally required
/ip cloud
set ddns-enabled=no ddns-update-interval=none update-time=yes
/ip dns
set allow-remote-requests=no servers=1.1.1.1,8.8.8.8
/ip proxy
set enabled=no
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh address=$ipman disabled=no port=22
set www-ssl disabled=yes
set api disabled=yes
set winbox address=$ipman disabled=no port=8291
set api-ssl disabled=yes
/ip smb
set enabled=no
/ip socks
set enabled=no
/ip ssh
set allow-none-crypto=no strong-crypto=yes
/ip upnp
set enabled=no

/ip firewall address-list
# Add / uncomment your required BGP peer addresses
# For added security you can add individual addresses
add address=196.60.70.0/23 comment="NAP Cape Town BLP" list=bgp-allowed
add address=196.60.8.0/22 comment="NAP Johannesburg BLP" list=bgp-allowed
add address=196.223.22.0/24 comment="CINX BLP" list=bgp-allowed
add address=196.223.14.0/24 comment="JINX BLP" list=bgp-allowed

# Add / uncomment your local management ranges
add address=$ipman comment="Local management range" list=management

# Add internal and external time servers
add address=pool.ntp.org list=time-servers

# Add / uncomment allowed SSH source addresses (including public ranges)
add address=$ipman comment="SSH management range" list=ssh-allowed
# add address=10.100.0.0/24 comment="SSH management range" list=ssh-allowed

#Add NMS/SNMP servers to this list
add address=10.100.0.0/24 comment="SNMP Servers range" list=snmp-allowed

# Add / uncomment allowed DNS servers (to this router only)
# If you have authoritative servers inside your network they must be in this list
add address=1.1.1.1 list=dns-allowed comment="Cloudflare primary"
# add address=1.0.0.1 list=dns-allowed comment="Cloudflare secondary"
# add address=1.1.1.2 list=dns-allowed comment="Cloudflare anti-malware"
# add address=1.1.1.3 list=dns-allowed comment="Cloudflare anti-malware and adult content"
add address=8.8.8.8 list=dns-allowed comment="Google primary"
# add address=8.4.4.8 list=dns-allowed comment="Google secondary"
# add address=9.9.9.9 list=dns-allowed comment="Quad 9 primary"
# add address=149.112.112.112 list=dns-allowed comment="Quad 9 secondary"

#Uncomment to allow MikroTik Updates to router
add address=update.mikrotik.com list=mik-update
add address=159.148.147.204 list=mik-update
add address=159.148.172.226 list=mik-update
add address=159.148.147.196 list=mik-update

# This will disable connection tracking entirely meaning no NAT will work on this device
# This is important for Conntrack DOS mitigation
/ip firewall connection tracking
set enabled=no
# Ensure all NAT traversal (UPNP) is disabled
/ip firewall service-port
set [find] disabled=yes

/ip firewall raw

# Limit ICMP directly in kernel
# icmp-rate-limit is minimum time in ms between ping responses
/ip settings
set icmp-rate-limit=100 icmp-rate-mask=0x1939

# Enable/disable common services as required
add action=accept chain=prerouting comment="Accept OSPF" in-interface-list=ospf-neighbours protocol=ospf
add action=accept chain=prerouting comment="Accept BFD" dst-port=3784,4784 in-interface-list=bfd-neighbours protocol=udp
add action=accept chain=prerouting comment="Accept BGP on input by address list" dst-port=179 protocol=tcp src-address-list=bgp-allowed
add action=accept chain=prerouting comment="Accept passive BGP neighbour on input by address list" protocol=tcp src-address-list=bgp-allowed src-port=179
add action=accept chain=prerouting comment="Accept MAC Winbox" dst-address-type=local dst-port=20561 in-interface-list=management protocol=udp
add action=accept chain=prerouting comment="Accept SNMP" dst-address-type=local dst-port=161 in-interface-list=management protocol=udp src-address-list=snmp-allowed
add action=accept chain=prerouting comment="Accept Discovery" dst-port=5678 in-interface-list=mndp-allowed protocol=udp
add action=accept chain=prerouting comment="Accept VXLAN internal" dst-port=8472 in-interface-list=!public-in protocol=udp src-address-list=management
add action=accept chain=prerouting comment="Accept SSH to router" dst-address-type=local dst-port=22 protocol=tcp src-address-list=management 
add action=accept chain=prerouting comment="Accept SSH by address list to internal" dst-address-type=!local dst-port=22 protocol=tcp src-address-list=ssh-allowed
add action=accept chain=prerouting comment="Accept SSH by address list to internal" dst-address-type=!local dst-port=22 protocol=tcp dst-address-list=ssh-allowed
add action=accept chain=prerouting dst-port=123 protocol=udp src-address-list=time-servers
add action=accept chain=prerouting protocol=udp src-address-list=time-servers src-port=123
add action=accept chain=prerouting comment="Accept Winbox to router" dst-address-type=local dst-port=8291 in-interface-list=management protocol=tcp src-address-list=management
add action=accept chain=prerouting comment="Accept external DNS by list" protocol=udp src-address-list=dns-allowed src-port=53
add action=accept chain=prerouting comment="Accept MikroTik Update" src-address-list=mik-update

#Check your management interface and IP list before enabling
add disabled=yes action=drop chain=prerouting comment="Drop public Winbox" dst-port=8291 protocol=tcp

# This will drop all SSH from non-management interfaces
# Add external client IP's to ssh-allowed address list
add action=drop chain=prerouting comment="Drop public SSH" dst-port=22 in-interface-list=!management protocol=tcp

add action=drop chain=prerouting comment="Drop incoming DNS, NTP, SNMP" dst-port=53,123,161 in-interface-list=public-in protocol=udp

# Enable to drop common attack and probe ports
# add action=drop chain=prerouting comment="Drop other common amplification attacks" dst-port=19,137-139,445,1900,389,5000,10001,11211 in-interface-list=public-in protocol=udp
# add action=drop chain=prerouting comment="Drop other common amplification attacks" dst-port=137-139,445 in-interface-list=public-in protocol=tcp

#Check your rules carefully before enabling or change action to passthrough to monitor first
add action=drop chain=prerouting comment="Drop all other input traffic" dst-address-type=local log=yes disabled=yes

# Set allowed neighbour discovery
/ip neighbor discovery-settings
set discover-interface-list=mndp-allowed

# Ensure Detect Internet is turned off
/interface detect-internet set detect-interface-list=none wan-interface-list=none lan-interface-list=none internet-interface-list=none

# Set RoMON default disabled on all ports - add individual ports as required
/tool romon port
set [find interface=all] forbid=yes 

# Allow MAC Server on Management interfaces
/tool mac-server set allowed-interface-list=management 
/tool mac-server mac-winbox set allowed-interface-list=management 

# Disable IPv6 ND on all ports
/ipv6 nd
set [find interface=all] advertise-dns=no disabled=yes
