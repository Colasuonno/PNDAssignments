# ACME 30 — Final Internal Firewall  
## Reasoning, practical configuration and tests performed

This file describes in detail how the **Internal Firewall-Router** of the ACME network was configured.  
The goal of the Internal Firewall is to separate and protect the internal networks by applying a restrictive policy based on the following principle:

```text
Default deny:
everything is blocked, except what is explicitly allowed.
```

The work performed on the Internal Firewall was complementary to the work performed on the Main Firewall.  
The Main Firewall controls traffic among the DMZ, WAN, external services network and the internal side; the Internal Firewall mainly controls:

```text
CLIENTS ↔ SERVERS
CLIENTS/SERVERS ↔ Main Firewall
CLIENTS/SERVERS ↔ DMZ
CLIENTS/SERVERS ↔ logging services, DNS, Graylog, Greenbone
```

In practice, the Internal Firewall decides what internal clients and internal servers are allowed to do.

---

# 1. Role of the Internal Firewall

The Internal Firewall has three main tabs:

| Tab / Interface | Role |
|---|---|
| `CLIENTS` | traffic coming from the client network `100.100.2.0/24` |
| `SERVERS` | traffic coming from the internal server network `100.100.1.0/24` |
| `EXTERNAL` | traffic coming from the side toward the Main Firewall / DMZ / external services |
| `IPsec` | already existing IPsec rules, not to be modified unless necessary |
| `Loopback` | automatic internal rules, not to be changed |

The main networks are:

```text
net_clients = 100.100.2.0/24
net_srv     = 100.100.1.0/24
net_dmz     = 100.100.6.0/24
net_ext     = 100.100.4.0/24
```

The most important IP addresses are:

```text
Internal Firewall, SERVERS side = 100.100.1.1
Internal Firewall, CLIENTS side = 100.100.2.1
Main Firewall, internal side    = 100.100.254.1
```

The administrative machine is:

```text
host_admin = 100.100.2.100
```

that is, Kali.

---

# 2. Goal of the Internal Firewall policy

The final policy must allow only the necessary flows.

In particular:

```text
CLIENTS:
  can use the internal DNS;
  can use the Squid proxy;
  can reach the reverse proxy;
  can send logs;
  can reach Graylog/Greenbone only if they are host_admin;
  can ping where allowed;
  must not have unrestricted access to internal servers.

SERVERS:
  can use external DNS through the DNS server;
  can use the proxy if necessary;
  Greenbone can scan the authorized networks;
  everything else is blocked.

EXTERNAL:
  allows some flows from DMZ/external services to internal support servers:
  DNS, Syslog, Graylog;
  blocks everything else.
```

The key point is that the Internal Firewall must not act as a simple open gateway between clients and servers.  
Instead, it must prevent unauthorized lateral movement.

---

# 3. Aliases used on the Internal Firewall

We used the same aliases created on the Main Firewall in order to keep the configuration consistent.

## 3.1 Host aliases

| Alias | Value | Meaning |
|---|---:|---|
| `host_webserver` | `100.100.6.2` | Web server in the DMZ |
| `host_proxyserver` | `100.100.6.3` | Proxy server in the DMZ |
| `host_dnsserver` | `100.100.1.2` | Internal DNS server |
| `host_logserver` | `100.100.1.3` | Internal Syslog server |
| `host_greenbone` | `100.100.1.4` | Vulnerability scanner |
| `host_graylog` | `100.100.1.10` | Graylog log collector |
| `host_fantasticcoffee` | `100.100.4.10` | Vending machine / external service |
| `host_admin` | `100.100.2.100` | Kali / administrative machine |

## 3.2 Network aliases

| Alias | Value | Meaning |
|---|---:|---|
| `net_clients` | `100.100.2.0/24` | Client network |
| `net_srv` | `100.100.1.0/24` | Internal server network |
| `net_dmz` | `100.100.6.0/24` | DMZ network |
| `net_ext` | `100.100.4.0/24` | External services network |

## 3.3 Port aliases

| Alias | Value | Meaning |
|---|---:|---|
| `port_web` | `80,443` | HTTP/HTTPS |
| `port_dns` | `53` | DNS TCP/UDP |
| `port_proxy` | `3128` | Squid forward proxy |
| `port_syslog` | `514` | Standard UDP Syslog |
| `port_graylog_syslog` | `5140` | Graylog Syslog input |
| `port_graylog_gelf` | `12201` | Graylog GELF input |
| `port_graylog_web` | `80` | Graylog Web UI in our setup |
| `port_greenbone` | `9392` | Greenbone Web UI |

Important note: also on the Internal Firewall, the `port_graylog_web` alias must be `80`, not `9000`, because in our setup Graylog listens on port `80`.

---

# 4. Configuration of the CLIENTS tab

The `CLIENTS` tab controls the traffic entering the Internal Firewall from the client network:

```text
net_clients = 100.100.2.0/24
```

This is the most important tab for controlling what users/clients can do.

The old rule:

```text
IPv4+6 * → * PASS
```

was disabled.

## Why?

Because an `any → any` rule from the client network would allow clients to freely reach internal servers, firewalls, the DMZ and other services.  
This would violate the least privilege principle.

---

## 4.1 Admin to Main Firewall GUI

We added:

```text
Action: Pass
Interface: CLIENTS
Direction: in
TCP/IP Version: IPv4
Protocol: TCP
Source: host_admin
Destination: 100.100.254.1/32
Destination port: 80
Description: A3_ALLOW_ADMIN_TO_MAIN_FW_GUI_HTTP
```

## Why?

During the tests, we could not access the Main Firewall GUI from Kali.  
We had already verified that the Main Firewall GUI was listening on HTTP port `80`, not HTTPS port `443`.

However, traffic from Kali to the Main Firewall first crosses the Internal Firewall:

```text
Kali 100.100.2.100
    ↓
Internal Firewall
    ↓
Main Firewall 100.100.254.1
```

Therefore, a rule was also needed on the Internal Firewall.

We used the destination:

```text
100.100.254.1/32
```

and not:

```text
100.100.254.1/24
```

because we wanted to allow access only to the single host `100.100.254.1`, not to the whole `100.100.254.0/24` network.

---

## 4.2 Admin to Internal Firewall GUI

We added:

```text
Action: Pass
Interface: CLIENTS
Direction: in
TCP/IP Version: IPv4
Protocol: TCP
Source: host_admin
Destination: This Firewall
Destination port: 80
Description: A3_ALLOW_ADMIN_TO_INTERNAL_FW_GUI_HTTP
```

## Why?

Kali is the administrative machine, so it must also be able to manage the Internal Firewall.

We restricted the source to:

```text
host_admin
```

and not to:

```text
net_clients
```

because not all clients should be able to administer the firewall.

---

## 4.3 Clients to internal DNS

Rule:

```text
Action: Pass
Interface: CLIENTS
Direction: in
TCP/IP Version: IPv4
Protocol: TCP/UDP
Source: net_clients
Destination: host_dnsserver
Destination port: port_dns
Description: A3_ALLOW_CLIENTS_TO_DNS
```

## Why?

Clients must be able to resolve internal names and, if needed, external names through the internal DNS server.

We did not allow:

```text
net_clients → Internet : 53
```

because we want to centralize DNS queries on the internal server.

---

## 4.4 Clients to Squid forward proxy

Rule:

```text
Action: Pass
Interface: CLIENTS
Direction: in
TCP/IP Version: IPv4
Protocol: TCP
Source: net_clients
Destination: host_proxyserver
Destination port: port_proxy
Description: A3_ALLOW_CLIENTS_TO_FORWARD_PROXY
```

## Why?

Clients must be able to browse HTTP/HTTPS through Squid:

```text
client → proxyserver:3128 → Internet
```

This rule does not give clients direct Internet access.  
It only allows them to reach the proxy.

The following traffic toward the Internet is then controlled by the Main Firewall on the `DMZ` tab, where only `host_proxyserver` is authorized to go out using HTTP/HTTPS.

---

## 4.5 Clients to reverse proxy

Rule:

```text
Action: Pass
Interface: CLIENTS
Direction: in
TCP/IP Version: IPv4
Protocol: TCP
Source: net_clients
Destination: host_proxyserver
Destination port: port_web
Description: A3_ALLOW_CLIENTS_TO_REVERSE_PROXY
```

## Why?

Clients must be able to reach the services published by the reverse proxy:

```text
webserver.acme-30.test
fantasticcoffee.acme-30.test
```

The traffic goes to:

```text
host_proxyserver : 80/443
```

and not directly to the backend servers.

---

## 4.6 Clients to Syslog server

Rule:

```text
Action: Pass
Interface: CLIENTS
Direction: in
TCP/IP Version: IPv4
Protocol: UDP
Source: net_clients
Destination: host_logserver
Destination port: port_syslog
Description: A3_ALLOW_CLIENTS_TO_SYSLOG
```

## Why?

Clients can send logs to the centralized Syslog server.

This is useful for logging and auditing.

---

## 4.7 Clients to Graylog Syslog input

Rule:

```text
Action: Pass
Interface: CLIENTS
Direction: in
TCP/IP Version: IPv4
Protocol: UDP
Source: net_clients
Destination: host_graylog
Destination port: port_graylog_syslog
Description: A3_ALLOW_CLIENTS_TO_GRAYLOG_SYSLOG
```

## Why?

Clients can also send logs to Graylog through the UDP Syslog input on port `5140`.

---

## 4.8 Clients to Graylog GELF input

Rule:

```text
Action: Pass
Interface: CLIENTS
Direction: in
TCP/IP Version: IPv4
Protocol: UDP
Source: net_clients
Destination: host_graylog
Destination port: port_graylog_gelf
Description: A3_ALLOW_CLIENTS_TO_GRAYLOG_GELF
```

## Why?

Graylog also supports GELF UDP input on port `12201`.  
This rule allows authorized hosts in the client network to send events using this format as well.

---

## 4.9 Admin to Greenbone

Rule:

```text
Action: Pass
Interface: CLIENTS
Direction: in
TCP/IP Version: IPv4
Protocol: TCP
Source: host_admin
Destination: host_greenbone
Destination port: port_greenbone
Description: A3_ALLOW_ADMIN_TO_GREENBONE
```

## Why?

Greenbone is an administrative and sensitive tool.  
Its web interface must not be accessible by all clients.

For this reason, we allowed:

```text
host_admin → Greenbone:9392
```

and not:

```text
net_clients → Greenbone:9392
```

---

## 4.10 Admin to Graylog Web UI

Final corrected rule:

```text
Action: Pass
Interface: CLIENTS
Direction: in
TCP/IP Version: IPv4
Protocol: TCP
Source: host_admin
Destination: host_graylog
Destination port: port_graylog_web
Description: A3_ALLOW_ADMIN_TO_GRAYLOG_WEB
```

where:

```text
port_graylog_web = 80
```

## Why?

The Graylog Web UI is an administrative tool.  
It must be reachable from Kali, but not from all clients.

During testing, we discovered that Graylog was not listening on port `9000`.

On the `graylog` container, we ran:

```bash
ss -lntup | grep -E '80|9000|5140|12201|graylog|java'
```

The result showed:

```text
tcp LISTEN [::ffff:100.100.1.10]:80
udp UNCONN *:5140
udp UNCONN *:12201
```

Therefore, the UI is available at:

```text
http://100.100.1.10:80
```

For this reason, we corrected the alias:

```text
port_graylog_web = 80
```

---

## 4.11 Clients to ICMP

Rule:

```text
Action: Pass
Interface: CLIENTS
Direction: in
TCP/IP Version: IPv4
Protocol: ICMP
Source: net_clients
Destination: any
Description: A3_ALLOW_CLIENTS_ICMP
```

## Why?

Ping is useful for diagnostic tests and reachability checks.

The important point is that this rule allows only ICMP, not unrestricted TCP/UDP traffic.

---

## 4.12 Final block rule on CLIENTS

Final rule:

```text
Action: Block
Log: enabled
Interface: CLIENTS
Direction: in
TCP/IP Version: IPv4+IPv6
Protocol: any
Source: any
Destination: any
Description: A3_BLOCK_LOG_DEFAULT_DENY_CLIENTS
```

## Why?

This rule blocks everything that was not explicitly allowed.

Examples of traffic that must be blocked:

```text
normal client → Greenbone Web UI
normal client → Graylog Web UI
client → unauthorized internal servers
client → Main Firewall management
client → direct Internet HTTP/HTTPS
```

---

# 5. Final rule order on the CLIENTS tab

The order is important because OPNsense evaluates rules from top to bottom.

Final order:

```text
1. A3_ALLOW_ADMIN_TO_MAIN_FW_GUI_HTTP
2. A3_ALLOW_ADMIN_TO_INTERNAL_FW_GUI_HTTP
3. A3_ALLOW_CLIENTS_TO_DNS
4. A3_ALLOW_CLIENTS_TO_FORWARD_PROXY
5. A3_ALLOW_CLIENTS_TO_REVERSE_PROXY
6. A3_ALLOW_CLIENTS_TO_SYSLOG
7. A3_ALLOW_CLIENTS_TO_GRAYLOG_SYSLOG
8. A3_ALLOW_CLIENTS_TO_GRAYLOG_GELF
9. A3_ALLOW_ADMIN_TO_GREENBONE
10. A3_ALLOW_ADMIN_TO_GRAYLOG_WEB
11. A3_ALLOW_CLIENTS_ICMP
12. A3_BLOCK_LOG_DEFAULT_DENY_CLIENTS
```

The old `IPv4+6 * → * PASS` rule remains disabled.

---

# 6. Configuration of the SERVERS tab

The `SERVERS` tab controls the traffic entering the Internal Firewall from the internal server network:

```text
net_srv = 100.100.1.0/24
```

This network contains services such as:

```text
dnsserver
logserver
greenbone
graylog
```

Also here, the old generic rule:

```text
IPv4+6 * → * PASS
```

was disabled.

---

## 6.1 DNS server to external DNS

Rule:

```text
Action: Pass
Interface: SERVERS
Direction: in
TCP/IP Version: IPv4
Protocol: TCP/UDP
Source: host_dnsserver
Destination: any
Destination port: port_dns
Description: A3_ALLOW_DNSSERVER_TO_EXTERNAL_DNS
```

## Why?

The internal DNS server must be able to forward DNS requests to the outside or resolve external names.

We allowed this outgoing flow only to:

```text
host_dnsserver
```

and not to the whole `net_srv` network.

This keeps DNS resolution centralized.

---

## 6.2 Internal servers to forward proxy

Rule:

```text
Action: Pass
Interface: SERVERS
Direction: in
TCP/IP Version: IPv4
Protocol: TCP
Source: net_srv
Destination: host_proxyserver
Destination port: port_proxy
Description: A3_ALLOW_SERVERS_TO_FORWARD_PROXY
```

## Why?

We decided to also allow internal servers to use Squid for possible HTTP/HTTPS requests toward the Internet.

This rule does not allow:

```text
net_srv → direct Internet
```

but only:

```text
net_srv → proxyserver:3128
```

Therefore, it remains consistent with the policy:

```text
HTTP/HTTPS Internet access through the proxy
```

Important: this rule must also be present on the Main Firewall, on the `INTERNAL` tab, because traffic from an internal server to the proxyserver crosses both firewalls:

```text
internal server
  ↓
Internal Firewall - SERVERS
  ↓
Main Firewall - INTERNAL
  ↓
proxyserver:3128
```

For this reason, we also added the following rule on the Main Firewall:

```text
net_srv → host_proxyserver : port_proxy
```

---

## 6.3 Greenbone to clients

Rule:

```text
Action: Pass
Interface: SERVERS
Direction: in
Protocol: any
Source: host_greenbone
Destination: net_clients
Description: A3_ALLOW_GREENBONE_SCAN_CLIENTS
```

## Why?

Greenbone is the vulnerability scanner.  
It must be able to scan clients, so we allowed broad traffic toward `net_clients`.

The rule is broad in terms of protocol, but restricted by source:

```text
host_greenbone
```

This means that not all servers can scan the clients, only Greenbone can.

---

## 6.4 Greenbone to DMZ

Rule:

```text
Action: Pass
Interface: SERVERS
Direction: in
Protocol: any
Source: host_greenbone
Destination: net_dmz
Description: A3_ALLOW_GREENBONE_SCAN_DMZ
```

## Why?

Greenbone must be able to test the exposed services in the DMZ, for example:

```text
webserver
proxyserver
```

Here too, the rule is broad because a scanner must test multiple ports and protocols, but the source is restricted to Greenbone.

---

## 6.5 Greenbone to external services

Rule:

```text
Action: Pass
Interface: SERVERS
Direction: in
Protocol: any
Source: host_greenbone
Destination: net_ext
Description: A3_ALLOW_GREENBONE_SCAN_EXTERNAL_SERVICES
```

## Why?

Greenbone must also be able to scan the external services network, especially `fantasticcoffee`.

---

## 6.6 Final block rule on SERVERS

Final rule:

```text
Action: Block
Log: enabled
Interface: SERVERS
Direction: in
TCP/IP Version: IPv4+IPv6
Protocol: any
Source: any
Destination: any
Description: A3_BLOCK_LOG_DEFAULT_DENY_SERVERS
```

## Why?

This rule blocks all other traffic from the server network.

Examples of traffic that must not pass freely:

```text
generic server → clients:any
generic server → DMZ:any
generic server → Internet:any
generic server → external services:any
```

Only explicit flows are allowed.

---

# 7. Final rule order on the SERVERS tab

Final order:

```text
1. A3_ALLOW_DNSSERVER_TO_EXTERNAL_DNS
2. A3_ALLOW_SERVERS_TO_FORWARD_PROXY
3. A3_ALLOW_GREENBONE_SCAN_CLIENTS
4. A3_ALLOW_GREENBONE_SCAN_DMZ
5. A3_ALLOW_GREENBONE_SCAN_EXTERNAL_SERVICES
6. A3_BLOCK_LOG_DEFAULT_DENY_SERVERS
```

The old `IPv4+6 * → * PASS` rule is disabled.

---

# 8. Configuration of the EXTERNAL tab

The `EXTERNAL` tab of the Internal Firewall manages traffic coming from the side that is external to the Internal Firewall, that is, from networks such as:

```text
DMZ
external services
Main Firewall side
```

This tab is important because it allows some hosts that do not belong to the internal server network to reach internal support services, such as DNS and logging.

Here too, the old rule:

```text
IPv4+6 * → * PASS
```

was disabled.

---

## 8.1 DMZ to DNS server

Rule:

```text
Action: Pass
Interface: EXTERNAL
Direction: in
TCP/IP Version: IPv4
Protocol: TCP/UDP
Source: net_dmz
Destination: host_dnsserver
Destination port: port_dns
Description: A3_ALLOW_DMZ_TO_DNS
```

## Why?

DMZ hosts such as `webserver` and `proxyserver` must be able to use the internal DNS server.

---

## 8.2 Fantasticcoffee to DNS server

Rule:

```text
Action: Pass
Interface: EXTERNAL
Direction: in
TCP/IP Version: IPv4
Protocol: TCP/UDP
Source: host_fantasticcoffee
Destination: host_dnsserver
Destination port: port_dns
Description: A3_ALLOW_FANTASTICCOFFEE_TO_DNS
```

## Why?

`fantasticcoffee` must also be able to resolve names using the internal DNS.

---

## 8.3 DMZ to Syslog server

Rule:

```text
Action: Pass
Interface: EXTERNAL
Direction: in
TCP/IP Version: IPv4
Protocol: UDP
Source: net_dmz
Destination: host_logserver
Destination port: port_syslog
Description: A3_ALLOW_DMZ_TO_SYSLOG
```

## Why?

DMZ hosts must be able to send logs to the internal Syslog server.

---

## 8.4 Fantasticcoffee to Syslog server

Rule:

```text
Action: Pass
Interface: EXTERNAL
Direction: in
TCP/IP Version: IPv4
Protocol: UDP
Source: host_fantasticcoffee
Destination: host_logserver
Destination port: port_syslog
Description: A3_ALLOW_FANTASTICCOFFEE_TO_SYSLOG
```

## Why?

The vending machine can send logs to the Syslog server.

---

## 8.5 DMZ to Graylog Syslog

Rule:

```text
Action: Pass
Interface: EXTERNAL
Direction: in
TCP/IP Version: IPv4
Protocol: UDP
Source: net_dmz
Destination: host_graylog
Destination port: port_graylog_syslog
Description: A3_ALLOW_DMZ_TO_GRAYLOG_SYSLOG
```

## Why?

DMZ hosts can send logs to Graylog through the Syslog input on port `5140`.

---

## 8.6 DMZ to Graylog GELF

Rule:

```text
Action: Pass
Interface: EXTERNAL
Direction: in
TCP/IP Version: IPv4
Protocol: UDP
Source: net_dmz
Destination: host_graylog
Destination port: port_graylog_gelf
Description: A3_ALLOW_DMZ_TO_GRAYLOG_GELF
```

## Why?

Some services can use GELF UDP to send events to Graylog.

---

## 8.7 Fantasticcoffee to Graylog Syslog

Rule:

```text
Action: Pass
Interface: EXTERNAL
Direction: in
TCP/IP Version: IPv4
Protocol: UDP
Source: host_fantasticcoffee
Destination: host_graylog
Destination port: port_graylog_syslog
Description: A3_ALLOW_FANTASTICCOFFEE_TO_GRAYLOG_SYSLOG
```

## Why?

`fantasticcoffee` can send events to Graylog through Syslog.

We did not necessarily add GELF for `fantasticcoffee`, because the required and tested flow was Syslog.

---

## 8.8 Final block rule on EXTERNAL

Final rule:

```text
Action: Block
Log: enabled
Interface: EXTERNAL
Direction: in
TCP/IP Version: IPv4+IPv6
Protocol: any
Source: any
Destination: any
Description: A3_BLOCK_LOG_DEFAULT_DENY_EXTERNAL
```

## Why?

This rule blocks all traffic coming from outside the Internal Firewall that does not match the authorized flows.

Examples of blocked traffic:

```text
DMZ → Greenbone Web UI
DMZ → Graylog Web UI
fantasticcoffee → unauthorized internal servers
DMZ → clients
```

---

# 9. Final rule order on the EXTERNAL tab

Final order:

```text
1. A3_ALLOW_DMZ_TO_DNS
2. A3_ALLOW_FANTASTICCOFFEE_TO_DNS
3. A3_ALLOW_DMZ_TO_SYSLOG
4. A3_ALLOW_FANTASTICCOFFEE_TO_SYSLOG
5. A3_ALLOW_DMZ_TO_GRAYLOG_SYSLOG
6. A3_ALLOW_DMZ_TO_GRAYLOG_GELF
7. A3_ALLOW_FANTASTICCOFFEE_TO_GRAYLOG_SYSLOG
8. A3_BLOCK_LOG_DEFAULT_DENY_EXTERNAL
```

The old `IPv4+6 * → * PASS` rule is disabled.

---

# 10. Problems encountered during the configuration

## 10.1 Access to the Main Firewall was blocked

Problem:

```text
From Kali, we could not access the Main Firewall.
```

Test:

```bash
curl -I http://100.100.254.1
```

failed.

We checked on the Main Firewall that the GUI was on port 80.  
Then we realized that traffic from Kali first crossed the Internal Firewall.

Solution:

```text
Internal Firewall → CLIENTS:
host_admin → 100.100.254.1/32 : 80
```

After this rule, access worked.

---

## 10.2 `/24` instead of `/32` error

In the destination field for the Main Firewall IP, OPNsense tended to display a netmask.  
The correct value was:

```text
100.100.254.1/32
```

and not:

```text
100.100.254.1/24
```

## Why?

`/32` means a single host.

`/24` would mean the whole network:

```text
100.100.254.0/24
```

which is much broader than necessary.

---

## 10.3 Graylog Web UI on port 80, not 9000

Initially, we defined:

```text
port_graylog_web = 9000
```

but from Kali the test remained pending.

On the Graylog container, we ran:

```bash
ss -lntp | grep 9000
curl -v --max-time 10 http://127.0.0.1:9000/
```

Result:

```text
no service listening on 9000
connection refused
```

Then we checked:

```bash
ss -lntup | grep -E '80|9000|5140|12201|graylog|java'
```

Result:

```text
tcp LISTEN [::ffff:100.100.1.10]:80
udp 5140
udp 12201
```

Therefore, we corrected:

```text
port_graylog_web = 80
```

and the admin rule toward Graylog started working.

---

# 11. Final tests on the Internal Firewall

## 11.1 Admin to Internal Firewall GUI

From Kali:

```bash
curl -I http://100.100.2.1
```

Expected:

```text
ALLOW
```

Reason: `host_admin` can administer the Internal Firewall.

---

## 11.2 Admin to Main Firewall GUI

From Kali:

```bash
curl -I http://100.100.254.1
```

Expected:

```text
ALLOW
```

Reason: `host_admin` can also administer the Main Firewall by crossing the Internal Firewall.

---

## 11.3 Clients to DNS

From client/Kali:

```bash
dig @100.100.1.2 webserver.acme-30.test
dig @100.100.1.2 fantasticcoffee.acme-30.test
```

Expected:

```text
ALLOW
```

Reason: clients must use the internal DNS.

---

## 11.4 Clients to forward proxy

From client/Kali:

```bash
curl -x http://100.100.6.3:3128 -I http://debian.org
curl -x http://100.100.6.3:3128 -I https://debian.org
```

Expected:

```text
ALLOW
```

Reason: clients browse through Squid.

---

## 11.5 Clients to direct Internet

From client/Kali:

```bash
curl -I https://debian.org --connect-timeout 5
```

Expected:

```text
DENY / timeout
```

Reason: direct HTTP/HTTPS Internet access is not allowed for clients.

---

## 11.6 Admin to Greenbone

From Kali:

```bash
curl -kI https://100.100.1.4:9392
```

Expected:

```text
ALLOW
```

Reason: only `host_admin` should access the Greenbone UI.

---

## 11.7 Non-admin client to Greenbone

From a client different from Kali:

```bash
curl -kI https://100.100.1.4:9392 --connect-timeout 5
```

Expected:

```text
DENY / timeout
```

Reason: Greenbone must not be accessible by all clients.

---

## 11.8 Admin to Graylog Web UI

From Kali:

```bash
curl -I http://100.100.1.10
```

Expected:

```text
ALLOW
```

Reason: the Graylog Web UI is administrative and must be reachable from `host_admin`.

---

## 11.9 Client or host to Syslog server

From a client or an authorized host:

```bash
logger -n 100.100.1.3 -P 514 "TEST FINAL A3 SYSLOG"
```

On the logserver:

```bash
find /var/log/remote/ -type f -exec tail -n 10 {} +
```

Expected:

```text
ALLOW, message present in the logs
```

---

## 11.10 Host to Graylog Syslog input

From a client or an authorized host:

```bash
logger -n 100.100.1.10 -P 5140 "TEST FINAL A3 GRAYLOG SYSLOG"
```

Expected:

```text
ALLOW, message visible in the Graylog UI
```

---

## 11.11 Greenbone to networks to be scanned

From Greenbone or through the Greenbone UI:

```bash
ping -c 2 100.100.2.100
ping -c 2 100.100.6.2
ping -c 2 100.100.4.10
```

Expected:

```text
ALLOW where expected
```

Reason: Greenbone has specific rules to scan clients, DMZ and external services.

---

# 12. Final state of the Internal Firewall

At the end of the configuration, the Internal Firewall applies the following policy:

```text
CLIENTS:
  host_admin can administer the Internal Firewall and the Main Firewall;
  clients can use the internal DNS;
  clients can use the Squid proxy;
  clients can reach the reverse proxy;
  clients can send logs to Syslog and Graylog;
  host_admin can reach Greenbone and the Graylog Web UI;
  ICMP is allowed;
  everything else is blocked.

SERVERS:
  dnsserver can perform external DNS queries;
  internal servers can use the proxy;
  Greenbone can scan clients, DMZ and external services;
  everything else is blocked.

EXTERNAL:
  DMZ and fantasticcoffee can use the internal DNS;
  DMZ and fantasticcoffee can send logs to Syslog/Graylog;
  everything else is blocked.
```

The final configuration is therefore consistent with:

```text
least privilege
default deny
logging of blocked traffic
separation between clients, servers and exposed services
```

and is ready to be exported as:

```text
ACME_30_internal.xml
```
