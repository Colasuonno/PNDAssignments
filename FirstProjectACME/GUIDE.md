# Prefix Delegation strategy

Since we are using ACME-30

We have 1E (30 in hex) as 16bits prefix for our network
So the idea is that our addresses are

/56

where, we have

[16][16][16][ 1E (8 bits)  ][ other 8 bits of custom  subnetting][  128-56 host bits ]


Strategy:


First 4 bits = which firewall, like (0-7) it's main firewall, 8-F is internal firewall

Second 4 bits = equals to ipv4 conf



--

# Obtain ipv6 address from ISP using Prefix delegation


In whatever client, access OPNSENSE Main firewall (whose has access to ISP), using ipv4.

For example, connecting to client-Ex1 with ipv4 (100.100.4.100)
 routed via (100.100.4.1 which is the Main firewall)


In the WAN section of opnsense dash we just enable DHCPv6 and /56 prefix for Prefix delegation


Obtained IP: 2001:470:b5b8:1e00::/56 


So we have as expected 1e[00]::/56


# Add ipv6 interfaces

The idea is: we need to add some info for ipv6 obtaining: use use track interface as we want to derivate ipv6 from router (pd)


We need to specify a prefix (which will be used for subnetting),  in this case, where we have a /56, we have 8 bit for subnetting, we will use the same pattern as used in ipv4


The idea is


```
[4 bits = 0 if under main firewall, 8 if internal][4 bits = same as ipv4 subnet prefix]
```





### Ipv6 conf for DMZ

For example we will have DMZ with ipv4 set to static ip @ 100.100.6.1

```
- IPV6 Conf type @ Track interface
- IPV6 Prefix ID @ 0x6 (same as ipv6 subnet)


- Received IPV6: 2001:470:b5b8:1e06:44fd:65ff:fe1b:8895/64

The important part is 1e06 (1E + 8 bit of Prefix choosen by us)
```


---

# Internal Firewall Configuration

Now we need to setup the second router,
which is connected to the main one, in order to access to the internel router, we need to connect to one of the connected interfaces:

so to say:

- Clients network (100.100.2.0)
- Internal Servers Network (100.100.1.0)


Are under internal firewall router


## Test connection


We can reach the internal firewall by accessing the default gateway of the sub device of the internal firewall:

such as: 100.100.2.1 or 100.100.1.1

# Internal Firewall Prefix delegation

- From our main firewall we need to enable router advertisements for our internal firewall which we rememeber has already obtained an ipv6 address with prefix id 0xf

- We then need to enable DHCPv6 Server for the internal firewall,  with range as we want like ::2


- We need to assign prefix delegation range, which will be used for subnetting, since i'ts internal we start with ::80 to ::80 (with 60 prefix delegation size), which means the subnet has only 4 bit of changing (8 will be fixed)

- Inside the internal firewall reached from the ext-1 client under (100.100.2.1 e.g) we set the clients of internal firewall to track the interface with prefix set to ipv4, for example 100.100.2.1 will have 0x2 prefix obtaining an ipv4 like: 2001:470:b6b8:1e82:64a3:2eff:fe83:1e7f/64


# Open IPV6 Rules floating

For both main and internal firewall we need to allow ipv6 traffic for EACH subdevice




# IPV6 Privacy

We need to ensure addr_gen_mode (ipv6) is set to random secret (in order to don't be tracked using real interface mac address)


from doc

```
addr_gen_mode - INTEGER
	Defines how link-local and autoconf addresses are generated.

	0: generate address based on EUI64 (default)
	1: do no generate a link-local address, use EUI64 for addresses generated
	   from autoconf
	2: generate stable privacy addresses, using the secret from
	   stable_secret (RFC7217)
	3: generate stable privacy addresses, using a random secret if unset
```


Make security stable @ reboot


edit ```/etc/sysctl.d/99-sysctl.conf```
and add 
```
net.ipv6.conf.eth0.stable_secret = 56:54:53:51:68:66:99:10 (Secret)
net.ipv6.conf.eth0.addr_gen_mode=3
```


# Setup DNS

- Always backup the conf file in /etc/dnsmasq.conf


1) Enable bogus-priv which preverse inverse ip lookup via upstream dns server


2) Add local only domains e.g
```
local=/acme-30.test/
```

3) Add listen address
```
listen-address=100.100.1.2,127.0.0.1,2001:470:b5b8:1e81:4730:4341:85e8:4a85
```

We clearly have localhost, public ipv4 of dns server, and public ipv6 

4) Disable dhcp, since we only want to give dns services, (firewall/router will provide dhcp / ISP Prefix delegation)

```
no-dhcp-interface=<int> (eth0)
```


5) uncomment bind-interfaces since we want to listen DNS Server only on selected host (the ones specified in listen address) otherwise we will occupy port 54 on all interfaces / host.

6) uncomment expand-hosts, suppose we have domain=home.arpa and expand-host enabled and in /etc/hosts we have
```
192.168.1.10 stampante
192.168.1.30 server.home.arpa
```

dnsmasq will respond

```
stampante -> 192.168.1.10
stampante.home.arpa -> 192.168.1.10 (added by expand host)
```

7) Setup the domain like
```
domain=acme-30.test
```
as specified above


8) The combination of local= and domain= will cause this behavour:

Private dns, unknown will respond NXDOMAIN (do not search on public DNS server)


# Warning and Problems with this configuration


1) ```LOUD WARNING: listening on 100.100.1.2 may accept requests via interfaces other than eth0```


This warning is thrown since dnsmasq is telling us: I will accept everything coming from 100.100.1.2 no matter the interface, in our case, we only have 1 interface so that's not a problem:


A clever approach would be: using bind-dynamic linked to eth0 so no matter the ip source, I will accept only things referred to eth0 interface


2) ```LOUD WARNING: use --bind-dynamic rather than --bind-interfaces to avoid DNS amplification attacks via these interface(s)```

## DNS Amplification


Since DNS is UDP (no handshake etc etc) (connection less), so we can ip spoof. DNS Response are much larger then DNS query.


The attack idea is DDoS, so to increase and destroy traffic for DNS.


1) Find DNS Resolver which respond to everyone
2) Prepare UDP DNS Packet (60 bytes) (like ANY with a lot of records)
3) Spoof ip with DNS Server (victim)
4) Send this packet to dns resolver
5) attacker spent little bytes, victim will receive a lot of traffic (unwanted)


### Why our DNS Server is a target?


idk I need more info to answer this



# Setup DNS Server hosts

```
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
# --- BEGIN PVE ---
100.100.1.2 dnsserver.acme-30.test dnsserver
# --- END PVE ---


2001:470:b5b8:1e81:4730:4341:85e8:4a85 dnsserver.acme-30.test dnsserver

2001:470:b5b8:1e06:40fa:57ff:fe4a:2073 webserver.acme-30.test webserver
100.100.6.2 webserver.acme-30.test webserver


2001:470:b5b8:1e82:7ab2:ec67:312:97d9 kali.acme-30.test kali
100.100.2.100 kali.acme-30.test kali
```



As shown, we setup host-per-host all the ipv6 and ipv4 linked to a specific client


# Adding DNS Server to client

Change the resolv configuration

```
root@webserver:~# cat /etc/resolv.conf 
nameserver 100.100.1.2
nameserver 2001:470:b5b8:1e81:4730:4341:85e8:4a85


# --- BEGIN PVE ---
search acme.corp
nameserver 151.100.4.13
# --- END PVE ---
root@webserver:~# 
```


Adding DNS Server to the resolv will cause:


From webserver client 

```bash
root@webserver:~# ping kali
PING kali(kali.acme-30.test (2001:470:b5b8:1e82:7ab2:ec67:312:97d9)) 56 data bytes
64 bytes from kali.acme-30.test (2001:470:b5b8:1e82:7ab2:ec67:312:97d9): icmp_seq=1 ttl=62 time=1.37 ms
64 bytes from kali.acme-30.test (2001:470:b5b8:1e82:7ab2:ec67:312:97d9): icmp_seq=2 ttl=62 time=1.79 ms
^C
--- kali ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 1.365/1.577/1.790/0.212 ms
```


### Dig

```bash
root@webserver:~# dig kali

; <<>> DiG 9.16.50-Debian <<>> kali
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 7954
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
;; QUESTION SECTION:
;kali.                          IN      A

;; ANSWER SECTION:
kali.                   0       IN      A       100.100.2.100

;; Query time: 4 msec
;; SERVER: 100.100.1.2#53(100.100.1.2)
;; WHEN: Wed Apr 22 12:15:05 UTC 2026
;; MSG SIZE  rcvd: 49

root@webserver:~# 
```



Where kali, resolves 100.100.2.100 from 100.100.1.2 (DNS Server)


















































