# Step 1. Create PKI

System -> trust -> authorities


1) We create custom CA using RSA (2048 bytes key length)


# Step 2. Create certificates


1) Server certificate for OpenVPN Server inside main firewall:
    - System -> Trust -> Certificates
    - Create a server certificate using the CA created

2) Create client certificates according to assignemnt requiremenets so:
    - Alice
    - Bob
    - Christina
    - Diana


# Step 3. Create static TLS Key

Just shared secret between server and client. It's not the crypting method, just another "safe level" to prevent tls handshake DoS....

VPN -> OpenVPN -> Static keys


# Step 4. Create OpenVPN Instance

1) Get WAN Address to bind (100.100.0.2/24) in our case
2) Select address space for VPN for subnetting

- We use /22 netmask since we NEED only 4 subnets (in our topology)
- so 2^10 = 1024 address, 1024 / 256 = 4, so we have

- 10.8.0.0 -> 10.8.3.255


# Step 5. Client specific overrides

## Alice (External)

- Push Reset (Blocks all common routes, we want to whitelist them)
- ipv4 tunnel: 10.8.0.0/30
    - /30 so we only have 4 address to assign (first .0 is for external subnet)


# Step 6. Create Firewall Alias

- Alice external (vpn_external), type network content is 10.8.0.0/30


# Step  7. Create Firewall Rule to allow UDP 1194 OpenVPN Traffic

Firewall -> Rules -> WAN 1194 Pass on UDP

# Step 8. Creare Firewall rule to allow firewall aliases

- External rule on OpenVPN

Firewall -> Rules -> OpenVPN

Source vpn_external
Destination: EXTERNAL_CLIENTS net


# Step 9. any -> any BLOCK

Add rule to block clients not allowed, so it's OpenVPN Rule

source: any dest: any (BLOCK)

# Step 10. Download OpenVPN Client cert

Download


# Step 11. Connect 


```bash
➜  ACME_30_Roadwarriors_alice git:(main) ✗ sudo openvpn ACME_30_Roadwarriors_alice.ovpn 
2026-05-22 18:11:28 DEPRECATED OPTION: --persist-key option ignored. Keys are now always persisted across restarts. 
2026-05-22 18:11:28 Note: --cipher is not set. OpenVPN versions before 2.5 defaulted to BF-CBC as fallback when cipher negotiation failed in this case. If you need this fallback please add '--data-ciphers-fallback BF-CBC' to your configuration and/or add BF-CBC to --data-ciphers. E.g. --data-ciphers DEFAULT:BF-CBC
2026-05-22 18:11:28 WARNING: file 'ACME_30_Roadwarriors_alice.p12' is group or others accessible
2026-05-22 18:11:28 OpenVPN 2.7.4 [git:makepkg/8e9e91f4caff9a80+] x86_64-pc-linux-gnu [SSL (OpenSSL)] [LZO] [LZ4] [EPOLL] [PKCS11] [MH/PKTINFO] [AEAD] [DCO] built on Apr 30 2026
2026-05-22 18:11:28 library versions: OpenSSL 3.6.2 7 Apr 2026, LZO 2.10
2026-05-22 18:11:28 DCO version: 7.0.9-arch1-1 #1 SMP PREEMPT_DYNAMIC Sun, 17 May 2026 17:23:07 +0000
2026-05-22 18:11:28 TCP/UDP: Preserving recently used remote address: [AF_INET]100.100.0.2:1194
2026-05-22 18:11:28 UDPv4 link local: (not bound)
2026-05-22 18:11:28 UDPv4 link remote: [AF_INET]100.100.0.2:1194
2026-05-22 18:11:28 [openvpn-server] Peer Connection Initiated with [AF_INET]100.100.0.2:1194
2026-05-22 18:11:29 DCO device tun0 opened
2026-05-22 18:11:29 ovpn-dco device [tun0] opened
2026-05-22 18:11:29 net_iface_mtu_set: mtu 1500 for tun0
2026-05-22 18:11:29 net_iface_up: set tun0 up
2026-05-22 18:11:29 net_addr_v4_add: 10.8.0.2/22 dev tun0
2026-05-22 18:11:29 Initialization Sequence Completed

```


# Step 12. Test connection


```bash
8: tun0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/none 
    inet 10.8.0.2/22 brd 10.8.3.255 scope global tun0
       valid_lft forever preferred_lft forever
    inet6 fe80::4192:9846:8f78:8dc8/64 scope link stable-privacy proto kernel_ll 
       valid_lft forever preferred_lft forever
➜  ~ ping -I tun0 100.100.2.1
PING 100.100.2.1 (100.100.2.1) from 10.8.0.2 tun0: 56(84) bytes of data.
^C
--- 100.100.2.1 ping statistics ---
4 packets transmitted, 0 received, 100% packet loss, time 3078ms

➜  ~ ping -I tun0 100.100.4.1 
PING 100.100.4.1 (100.100.4.1) from 10.8.0.2 tun0: 56(84) bytes of data.
64 bytes from 100.100.4.1: icmp_seq=1 ttl=64 time=25.7 ms
64 bytes from 100.100.4.1: icmp_seq=2 ttl=64 time=25.7 ms
64 bytes from 100.100.4.1: icmp_seq=3 ttl=64 time=44.6 ms
^C
--- 100.100.4.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2002ms
rtt min/avg/max/mdev = 25.741/32.036/44.620/8.898 ms
➜  ~ 
```

It works with alice certificate pinging only external clients in .4 subnet!!!!!


# PKI X.509???

Yes since we created CA!!!!


# Does it work? Let's check wireshark


## Step 1


We first check if using physical interface (actually it's still virtual since we are in double VPN setup (lol))

```bash
7: tap0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 1000
    link/ether ee:44:b7:80:a9:54 brd ff:ff:ff:ff:ff:ff
    inet 100.101.0.2/24 brd 100.101.0.255 scope global tap0
       valid_lft forever preferred_lft forever
    inet6 fe80::9423:aff:fe89:408f/64 scope link proto kernel_ll 
       valid_lft forever preferred_lft forever
8: tun0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/none 
    inet 10.8.0.2/22 brd 10.8.3.255 scope global tun0
       valid_lft forever preferred_lft forever
    inet6 fe80::4192:9846:8f78:8dc8/64 scope link stable-privacy proto kernel_ll 
       valid_lft forever preferred_lft forever
➜  ~ 
```

So it's

- tap0 (fake physical)
- tun0 (tunnel VPN, with alice certificate)


## Step 2


### tap0 (crypted)

We filter wireshark on tap0 interface using filter udp.port == 1194


and with a simple ping to 100.100.4.1 device we see

![img](imgs/tap0_scan_ping.png)

![img](imgs/tap0_scan_bytes.png)


(Apparently random bytes)


### tun0 (tunnel uncrypted)


![img](imgs/tun0_scan_ping.png)

![img](imgs/tun0_scan_bytes.png)


(Real ICMP data)