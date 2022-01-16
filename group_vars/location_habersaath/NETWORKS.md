

# switch config example

```
hostname "habersaath-sw-a"
no telnet-server
no tftp server
no snmp-server enable
ip default-gateway 10.31.146.129
vlan 40
   name "DHCP"
   no untagged 1-10
   no ip address
   exit
vlan 42
   name "MGMT"
   tagged 1-10
   ip address 10.31.146.130 255.255.255.192
   ipv6 enable
   ipv6 address autoconfig
   exit
primary-vlan 42
management-vlan 42
no dhcp config-file-update
no dhcp image-file-update
activate software-update disable
activate provision disable
password manager
password operator
```
