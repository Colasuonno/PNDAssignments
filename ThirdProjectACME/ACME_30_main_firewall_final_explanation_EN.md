# ACME 30 — Main Firewall final configuration
## Reasoning, practical configuration and tests performed

This file summarizes in detail the work performed to configure the **Main Firewall-Router** for the ACME assignment.
The goal was not simply to “make the traffic pass”, but to build a configuration consistent with a real **security policy**:

```text
Default deny:
everything is blocked, except what is explicitly allowed.
```

For this reason, we started from an initial situation where several services were already working, but the firewall still had permissive rules such as:

```text
IPv4+6 * → * PASS
```

These rules are convenient during the setup phase, but they are not acceptable as a final configuration because they allow generic traffic between networks.
Therefore, the work on the Main Firewall consisted of:

1. defining which traffic flows are actually necessary;
2. creating readable aliases;
3. adding specific rules for each interface;
4. disabling the old `allow any` rules;
5. adding final `block log` rules;
6. testing both the `ALLOW` and the `DENY` cases;
7. fixing some issues found during the tests, especially related to the firewall GUI, Squid and Graylog.

---

# 1. Role of the Main Firewall

The Main Firewall is the firewall that connects the outermost zones of the ACME network.

Its main interfaces are:

| Interface | Role |
|---|---|
| `WAN` | Internet / external network / VPN access |
| `DMZ` | network of exposed services, mainly `webserver` and `proxyserver` |
| `EXTERNAL_CLIENTS` | external services network, where `fantasticcoffee` is located |
| `INTERNAL` | link towards the Internal Firewall, and therefore towards clients and internal servers |
| `OpenVPN` | VPN rules already present from the previous assignment |
| `IPsec` | IPsec rules already present |
| `Loopback` | internal automatic rules |

The final configuration must therefore mainly control:

```text
Internet/WAN → DMZ
DMZ → Internet
DMZ → internal servers
External services → internal servers
Internal clients/servers → DMZ/Internet through authorized paths
```

---

# 2. Main design choice: exposing services through a reverse proxy

We already configured `proxyserver` in the DMZ with two roles:

```text
1. Squid forward proxy
2. Nginx reverse proxy
```

We decided to use this architecture.

The final choice was:

```text
Internet/WAN → proxyserver:80/443
proxyserver → webserver
proxyserver → fantasticcoffee
```

and not:

```text
Internet/WAN → webserver directly
Internet/WAN → fantasticcoffee directly
```

## Why this choice?

Because it is more secure and more organized:

- the external world only sees the reverse proxy;
- the real backend hosts are not directly exposed;
- public access control is concentrated on a single host;
- firewall rules are simpler.

Therefore, the `proxyserver` became the public entry point for the web services.

---

# 3. Aliases created on the Main Firewall

Before writing the rules, we created aliases.
This avoids rules that are hard to read because they are based only on numeric IP addresses.

For example, instead of writing:

```text
100.100.2.0/24 → 100.100.6.3 : 3128
```

we wrote:

```text
net_clients → host_proxyserver : port_proxy
```

The second form is much clearer and makes the report more understandable.

---

## 3.1 Host aliases

| Alias | Value | Meaning |
|---|---:|---|
| `host_webserver` | `100.100.6.2` | Web server in the DMZ |
| `host_proxyserver` | `100.100.6.3` | Proxy server in the DMZ |
| `host_dnsserver` | `100.100.1.2` | Internal DNS server |
| `host_logserver` | `100.100.1.3` | Internal syslog server |
| `host_greenbone` | `100.100.1.4` | Vulnerability scanner |
| `host_graylog` | `100.100.1.10` | Graylog log collector |
| `host_fantasticcoffee` | `100.100.4.10` | Vending machine / external service |
| `host_admin` | `100.100.2.100` | Kali / administrative machine |

---

## 3.2 Network aliases

| Alias | Value | Meaning |
|---|---:|---|
| `net_dmz` | `100.100.6.0/24` | DMZ network |
| `net_srv` | `100.100.1.0/24` | Internal servers network |
| `net_clients` | `100.100.2.0/24` | Clients network |
| `net_ext` | `100.100.4.0/24` | External services network |

---

## 3.3 Port aliases

| Alias | Value | Meaning |
|---|---:|---|
| `port_web` | `80,443` | HTTP/HTTPS |
| `port_dns` | `53` | DNS TCP/UDP |
| `port_proxy` | `3128` | Squid forward proxy |
| `port_syslog` | `514` | Standard UDP syslog |
| `port_graylog_syslog` | `5140` | Graylog UDP syslog input |
| `port_graylog_gelf` | `12201` | Graylog UDP GELF input |
| `port_graylog_web` | `80` | Graylog Web UI in our setup |
| `port_greenbone` | `9392` | Greenbone Web UI |

Note: initially we assumed `port_graylog_web = 9000`, but during the tests on `graylog` we discovered that the UI was listening on `100.100.1.10:80`. Therefore, the alias was corrected to `80`.

---

# 4. WAN tab configuration

The `WAN` tab controls traffic arriving from the outside towards the Main Firewall.

## 4.1 Existing rules to keep

We kept the rules related to:

```text
OpenVPN UDP 1194
IPsec IKE UDP 500
IPsec NAT-T UDP 4500
ESP
```

## Why?

Because these rules were related to the previous assignment and were needed to keep VPN/IPsec working.
They should not be deleted without a reason.

---

## 4.2 WAN rule towards the reverse proxy

We added:

```text
Action: Pass
Interface: WAN
Direction: in
TCP/IP Version: IPv4
Protocol: TCP
Source: any
Destination: host_proxyserver
Destination port: port_web
Description: A3_ALLOW_WAN_TO_REVERSE_PROXY_HTTP_HTTPS
```

This rule allows:

```text
Internet/WAN → proxyserver : 80/443
```

## Why?

Because we decided that public services must be reachable only through the reverse proxy.
Therefore, from the outside we did not open:

```text
WAN → webserver
WAN → fantasticcoffee
WAN → greenbone
WAN → graylog
WAN → internal servers
```

---

## 4.3 ICMP rules on WAN

The generic ICMP rules on the WAN interface were disabled.

## Why?

Because we do not want to unnecessarily expose the firewall to generic ping requests from the external side.
The policy must be restrictive: from the WAN side, only the required traffic is allowed.

---

## 4.4 Defualt WAN block rule

We added at the end:

```text
Action: Block
Log: enabled
Interface: WAN
Direction: in
TCP/IP Version: IPv4+IPv6
Protocol: any
Source: any
Destination: any
Description: A3_BLOCK_LOG_DEFAULT_DENY
```

## Why?

Because everything that is not explicitly allowed must be blocked and logged.
This is also useful to demonstrate the negative tests in the report.

---

# 5. DMZ tab configuration

The `DMZ` tab manages traffic originating from the DMZ towards other zones.

The main hosts are:

```text
webserver   = 100.100.6.2
proxyserver = 100.100.6.3
```

The old rule:

```text
IPv4+6 * → * PASS
```

was disabled.

---

## 5.1 Proxyserver towards the Internet over HTTP/HTTPS

Rule:

```text
Action: Pass
Interface: DMZ
Direction: in
TCP/IP Version: IPv4
Protocol: TCP
Source: host_proxyserver
Destination: any
Destination port: port_web
Description: A3_ALLOW_PROXY_TO_INTERNET_HTTP_HTTPS
```

## Why?

Because Squid must be able to reach the Internet over HTTP/HTTPS on behalf of the authorized clients.

This rule does not give direct Internet access to the clients.
It only allows the proxyserver to go out.

---

## 5.2 Proxyserver towards Fantasticcoffee

Rule:

```text
Action: Pass
Interface: DMZ
Direction: in
TCP/IP Version: IPv4
Protocol: TCP
Source: host_proxyserver
Destination: host_fantasticcoffee
Destination port: port_web
Description: A3_ALLOW_REVERSE_PROXY_TO_FANTASTICCOFFEE
```

## Why?

Because the Nginx reverse proxy must be able to forward requests to `fantasticcoffee`.

---

## 5.3 DMZ towards DNS

Rule:

```text
Action: Pass
Interface: DMZ
Direction: in
TCP/IP Version: IPv4
Protocol: TCP/UDP
Source: net_dmz
Destination: host_dnsserver
Destination port: port_dns
Description: A3_ALLOW_DMZ_TO_DNS
```

## Why?

DMZ hosts must be able to resolve names through the internal DNS server.

---

## 5.4 DMZ towards Syslog

Rule:

```text
Action: Pass
Interface: DMZ
Direction: in
TCP/IP Version: IPv4
Protocol: UDP
Source: net_dmz
Destination: host_logserver
Destination port: port_syslog
Description: A3_ALLOW_DMZ_TO_SYSLOG
```

## Why?

DMZ hosts can send logs to the central syslog server.

---

## 5.5 DMZ towards Graylog

Rules:

```text
Action: Pass
Interface: DMZ
Direction: in
TCP/IP Version: IPv4
Protocol: UDP
Source: net_dmz
Destination: host_graylog
Destination port: port_graylog_syslog
Description: A3_ALLOW_DMZ_TO_GRAYLOG_SYSLOG
```

```text
Action: Pass
Interface: DMZ
Direction: in
TCP/IP Version: IPv4
Protocol: UDP
Source: net_dmz
Destination: host_graylog
Destination port: port_graylog_gelf
Description: A3_ALLOW_DMZ_TO_GRAYLOG_GELF
```

## Why?

Services in the DMZ can send events to Graylog using both UDP syslog and UDP GELF.

During the review, we corrected a rule that initially had `any` as the source.
We restricted it to `net_dmz`.

## Why this correction?

Because the rule must represent the policy:

```text
DMZ → Graylog
```

not:

```text
any → Graylog
```

---

## 5.6 Final DMZ block rule

Rule:

```text
Action: Block
Log: enabled
Interface: DMZ
Protocol: any
Source: any
Destination: any
Description: A3_BLOCK_LOG_DEFAULT_DENY
```

## Why?

To block all other traffic coming from the DMZ.

---

# 6. EXTERNAL_CLIENTS tab configuration

The `EXTERNAL_CLIENTS` tab manages the network:

```text
net_ext = 100.100.4.0/24
```

where `fantasticcoffee` is located.

Here too, the old `PASS any` rule was disabled.

---

## 6.1 External clients towards the reverse proxy

Rule:

```text
Action: Pass
Interface: EXTERNAL_CLIENTS
Direction: in
TCP/IP Version: IPv4
Protocol: TCP
Source: net_ext
Destination: host_proxyserver
Destination port: port_web
Description: A3_ALLOW_EXTERNAL_CLIENTS_TO_REVERSE_PROXY
```

## Why?

Hosts in the external services network can reach the published services only through the reverse proxy.

---

## 6.2 Fantasticcoffee towards DNS

Rule:

```text
Action: Pass
Interface: EXTERNAL_CLIENTS
Direction: in
TCP/IP Version: IPv4
Protocol: TCP/UDP
Source: host_fantasticcoffee
Destination: host_dnsserver
Destination port: port_dns
Description: A3_ALLOW_FANTASTICCOFFEE_TO_DNS
```

## Why?

`fantasticcoffee` can use the internal DNS server.

---

## 6.3 Fantasticcoffee towards Syslog

Rule:

```text
Action: Pass
Interface: EXTERNAL_CLIENTS
Direction: in
TCP/IP Version: IPv4
Protocol: UDP
Source: host_fantasticcoffee
Destination: host_logserver
Destination port: port_syslog
Description: A3_ALLOW_FANTASTICCOFFEE_TO_SYSLOG
```

## Why?

The vending machine can send logs to the syslog server.

---

## 6.4 Fantasticcoffee towards Graylog

Rule:

```text
Action: Pass
Interface: EXTERNAL_CLIENTS
Direction: in
TCP/IP Version: IPv4
Protocol: UDP
Source: host_fantasticcoffee
Destination: host_graylog
Destination port: port_graylog_syslog
Description: A3_ALLOW_FANTASTICCOFFEE_TO_GRAYLOG_SYSLOG
```

## Why?

`fantasticcoffee` can also send events to Graylog through the syslog input.

We did not necessarily add GELF from `fantasticcoffee` because, in the tested setup, the useful flow was Syslog.

---

## 6.5 Final EXTERNAL_CLIENTS block rule

Rule:

```text
Action: Block
Log: enabled
Interface: EXTERNAL_CLIENTS
Protocol: any
Source: any
Destination: any
Description: A3_BLOCK_LOG_DEFAULT_DENY
```

## Why?

All other traffic from the external services network is blocked.

---

# 7. INTERNAL tab configuration

The `INTERNAL` tab of the Main Firewall was the most delicate one, because administrative access also passes through it.

Traffic arrives from the Internal Firewall side, so it can originate from:

```text
clients
internal servers
host_admin
dnsserver
greenbone
```

---

## 7.1 Problem: Main Firewall GUI on HTTP/80

At first, we thought that the Main Firewall GUI was on HTTPS port `443`.

However, the test:

```bash
curl -kI https://100.100.254.1
```

timed out.

From the Main Firewall console, we ran:

```sh
sockstat -4 -l | grep -E ':80|:443|lighttpd'
```

The result showed that `lighttpd` was listening on:

```text
*:80
```

Therefore, the GUI was available at:

```text
http://100.100.254.1
```

and not over HTTPS.

We therefore changed the rules from port `443` to port `80`.

---

## 7.2 Problem: the Internal Firewall was blocking access to the Main Firewall

Even with the packet filter disabled on the Main Firewall through:

```sh
pfctl -d
```

from Kali we still could not access:

```bash
curl http://100.100.254.1
```

This proved that the problem was not on the Main Firewall, but along the path:

```text
Kali → Internal Firewall → Main Firewall
```

Therefore, on the Internal Firewall we added a rule:

```text
host_admin → 100.100.254.1 : 80
```

After this rule, access to the Main Firewall GUI worked again.

---

## 7.3 Admin rule towards the Main Firewall

On the Main Firewall, in the `INTERNAL` tab, we kept the final rule:

```text
Action: Pass
Interface: INTERNAL
Direction: in
TCP/IP Version: IPv4
Protocol: TCP
Source: host_admin
Destination: 100.100.254.1/32
Destination port: 80
Description: A3_ALLOW_ADMIN_TO_MAIN_FW_GUI_HTTP
```

## Why?

Only `host_admin`, i.e. Kali `100.100.2.100`, should be able to administer the Main Firewall.

We did not keep broad rules such as:

```text
net_clients → main firewall : 80
any → main firewall : 80
```

because they would be too permissive.

---

## 7.4 Clients towards the forward proxy

Rule:

```text
Action: Pass
Interface: INTERNAL
Direction: in
TCP/IP Version: IPv4
Protocol: TCP
Source: net_clients
Destination: host_proxyserver
Destination port: port_proxy
Description: A3_ALLOW_CLIENTS_TO_FORWARD_PROXY
```

## Why?

Clients must browse HTTP/HTTPS through Squid, not directly towards the Internet.

---

## 7.5 Clients towards the reverse proxy

Rule:

```text
Action: Pass
Interface: INTERNAL
Direction: in
TCP/IP Version: IPv4
Protocol: TCP
Source: net_clients
Destination: host_proxyserver
Destination port: port_web
Description: A3_ALLOW_CLIENTS_TO_REVERSE_PROXY
```

## Why?

Clients can reach the services published by the reverse proxy.

---

## 7.6 Clients towards the Internet: ICMP only

Rule:

```text
Action: Pass
Interface: INTERNAL
Direction: in
TCP/IP Version: IPv4
Protocol: ICMP
Source: net_clients
Destination: any
Description: A3_ALLOW_CLIENTS_ICMP_TO_INTERNET
```

## Why?

Ping towards the Internet is allowed as diagnostic traffic.
Direct HTTP/HTTPS traffic, instead, must be blocked.

---

## 7.7 DNS server towards external DNS

Rule:

```text
Action: Pass
Interface: INTERNAL
Direction: in
TCP/IP Version: IPv4
Protocol: TCP/UDP
Source: host_dnsserver
Destination: any
Destination port: port_dns
Description: A3_ALLOW_DNSSERVER_TO_EXTERNAL_DNS
```

## Why?

The internal DNS server must be able to forward DNS queries or resolve external names.

---

## 7.8 Internal servers towards the proxy

We decided to also allow internal servers to use the proxy, so we added:

```text
Action: Pass
Interface: INTERNAL
Direction: in
TCP/IP Version: IPv4
Protocol: TCP
Source: net_srv
Destination: host_proxyserver
Destination port: port_proxy
Description: A3_ALLOW_SERVERS_TO_FORWARD_PROXY
```

## Why?

The assignment text states that the proxy is used by ACME network hosts to perform HTTP/HTTPS requests towards the Internet.
Allowing internal servers to use Squid is consistent with this interpretation.

The rule is still restrictive because it does not give unrestricted Internet access to the servers:

```text
net_srv → proxyserver:3128
```

and not:

```text
net_srv → Internet:any
```

---

## 7.9 Greenbone towards the DMZ and external services

Rules:

```text
Action: Pass
Interface: INTERNAL
Direction: in
Protocol: any
Source: host_greenbone
Destination: net_dmz
Description: A3_ALLOW_GREENBONE_SCAN_DMZ
```

```text
Action: Pass
Interface: INTERNAL
Direction: in
Protocol: any
Source: host_greenbone
Destination: net_ext
Description: A3_ALLOW_GREENBONE_SCAN_EXTERNAL_SERVICES
```

## Why?

Greenbone is the vulnerability scanner, so it must be able to scan hosts and ports in the ACME networks.
The rule is broad in terms of protocol, but very limited in terms of source:

```text
only host_greenbone
```

---

## 7.10 Final INTERNAL block rule

Final rule:

```text
Action: Block
Log: enabled
Interface: INTERNAL
Protocol: any
Source: any
Destination: any
Description: A3_BLOCK_LOG_DEFAULT_DENY
```

## Why?

It blocks all internal traffic that is not allowed by the policy and produces useful logs for the enforcement tests.

---

# 8. Final rule order

## 8.1 WAN

```text
1. A3_ALLOW_WAN_TO_REVERSE_PROXY_HTTP_HTTPS
2. OpenVPN UDP 1194
3. IPsec IKE UDP 500
4. IPsec NAT-T UDP 4500
5. IPsec ESP
6. any existing IPv6 IPsec rules
7. A3_BLOCK_LOG_DEFAULT_DENY
```

---

## 8.2 DMZ

```text
1. A3_ALLOW_PROXY_TO_INTERNET_HTTP_HTTPS
2. A3_ALLOW_REVERSE_PROXY_TO_FANTASTICCOFFEE
3. A3_ALLOW_DMZ_TO_DNS
4. A3_ALLOW_DMZ_TO_SYSLOG
5. A3_ALLOW_DMZ_TO_GRAYLOG_SYSLOG
6. A3_ALLOW_DMZ_TO_GRAYLOG_GELF
7. A3_BLOCK_LOG_DEFAULT_DENY
```

---

## 8.3 EXTERNAL_CLIENTS

```text
1. A3_ALLOW_EXTERNAL_CLIENTS_TO_REVERSE_PROXY
2. A3_ALLOW_FANTASTICCOFFEE_TO_DNS
3. A3_ALLOW_FANTASTICCOFFEE_TO_SYSLOG
4. A3_ALLOW_FANTASTICCOFFEE_TO_GRAYLOG_SYSLOG
5. A3_BLOCK_LOG_DEFAULT_DENY
```

---

## 8.4 INTERNAL

```text
1. A3_ALLOW_ADMIN_TO_MAIN_FW_GUI_HTTP
2. A3_ALLOW_CLIENTS_TO_FORWARD_PROXY
3. A3_ALLOW_CLIENTS_TO_REVERSE_PROXY
4. A3_ALLOW_CLIENTS_ICMP_TO_INTERNET
5. A3_ALLOW_DNSSERVER_TO_EXTERNAL_DNS
6. A3_ALLOW_SERVERS_TO_FORWARD_PROXY
7. A3_ALLOW_GREENBONE_SCAN_DMZ
8. A3_ALLOW_GREENBONE_SCAN_EXTERNAL_SERVICES
9. A3_BLOCK_LOG_DEFAULT_DENY
```

---

# 9. Squid issue: timeout caused by IPv6

During the tests, the client was able to reach Squid:

```bash
nc -vz -w 5 100.100.6.3 3128
```

The port was open, so:

```text
client → proxyserver:3128
```

was working.

However, requests through the proxy timed out:

```bash
curl -v --connect-timeout 5 -x http://100.100.6.3:3128 -I http://debian.org
```

---

## 9.1 Direct tests from the proxyserver

On the proxyserver, we checked:

```bash
ip route
cat /etc/resolv.conf
dig debian.org
curl -I http://debian.org --connect-timeout 5
curl -I https://debian.org --connect-timeout 5
```

Result:

```text
DNS working
direct HTTP working
direct HTTPS working
```

Therefore, the rule:

```text
host_proxyserver → Internet : 80/443
```

was correct.

---

## 9.2 Squid log analysis

We checked:

```bash
tail -n 80 /var/log/squid/access.log
```

and we saw lines such as:

```text
HIER_DIRECT/2a04:4e42:600::644
HIER_DIRECT/2a04:4e42:200::644
HIER_DIRECT/2a04:4e42:400::644
```

These are IPv6 addresses.

Conclusion:

```text
Squid was trying to reach debian.org using IPv6.
```

The configured rules were mainly IPv4 rules, so the traffic timed out.

---

## 9.3 Squid fix

We modified `/etc/squid/squid.conf`.

First, we created a backup:

```bash
cp /etc/squid/squid.conf /etc/squid/squid.conf.bak_a3
```

Then we added:

```conf
dns_v4_first on
```

Configuration check:

```bash
squid -k parse
```

Restart:

```bash
systemctl restart squid
systemctl status squid --no-pager
```

---

## 9.4 Squid test after the fix

On the proxyserver:

```bash
curl -v --max-time 15 -x http://127.0.0.1:3128 -I http://debian.org
```

Result:

```text
HTTP/1.1 302 Found
Via: 1.1 proxyserver (squid/4.13)
```

For HTTPS:

```bash
curl -v --max-time 15 -x http://127.0.0.1:3128 -I https://debian.org
```

Result:

```text
HTTP/1.1 200 Connection established
```

From the client:

```bash
curl -x http://100.100.6.3:3128 -I http://debian.org
curl -x http://100.100.6.3:3128 -I https://debian.org
```

The log then showed IPv4 lines:

```text
100.100.2.100 TCP_MISS/302 ... HIER_DIRECT/151.101.130.132
100.100.2.100 TCP_TUNNEL/200 ... HIER_DIRECT/151.101.130.132
```

Therefore, the issue was fixed.

---

# 10. Final tests of the Main Firewall

## 10.1 Main Firewall GUI

From Kali:

```bash
curl -I http://100.100.254.1
```

Expected result:

```text
ALLOW
```

Reason: `host_admin` can administer the Main Firewall.

---

## 10.2 HTTP forward proxy

From client/Kali:

```bash
curl -x http://100.100.6.3:3128 -I http://debian.org
```

Expected result:

```text
ALLOW
Via: proxyserver
```

---

## 10.3 HTTPS forward proxy

From client/Kali:

```bash
curl -x http://100.100.6.3:3128 -I https://debian.org
```

Expected result:

```text
ALLOW
HTTP/1.1 200 Connection established
```

---

## 10.4 Direct Internet access blocked

From client/Kali:

```bash
curl -I https://debian.org --connect-timeout 5
```

Expected result:

```text
DENY / timeout
```

Reason: clients must not access HTTP/HTTPS directly.

---

## 10.5 ICMP towards the Internet

From client/Kali:

```bash
ping -c 3 8.8.8.8
```

Expected result:

```text
ALLOW
```

Reason: ping was left allowed for diagnostics.

---

## 10.6 Reverse proxy towards webserver

From client/Kali:

```bash
curl -vkI --resolve webserver.acme-30.test:443:100.100.6.3 https://webserver.acme-30.test/
```

Expected result:

```text
ALLOW
```

---

## 10.7 Reverse proxy towards fantasticcoffee

From client/Kali:

```bash
curl -vkI --resolve fantasticcoffee.acme-30.test:443:100.100.6.3 https://fantasticcoffee.acme-30.test/
```

Expected result:

```text
ALLOW
```

---

## 10.8 Proxyserver towards the Internet

From proxyserver:

```bash
curl -I http://debian.org --connect-timeout 5
curl -I https://debian.org --connect-timeout 5
```

Expected result:

```text
ALLOW
```

---

## 10.9 DNS from the proxyserver

From proxyserver:

```bash
dig debian.org
```

Expected result:

```text
ALLOW, response from the internal DNS server 100.100.1.2
```

---

# 11. Errors/issues encountered and their meaning

## 11.1 HTTPS curl towards the Main Firewall did not work

Error:

```text
curl: failed to connect to 100.100.254.1 port 443
```

Reason:

```text
the GUI was not on port 443, but on port 80.
```

Solution:

```text
use http://100.100.254.1
and firewall rules on port 80.
```

---

## 11.2 With `pfctl -d` on the Main Firewall, access still did not work

Reason:

```text
the block was on the Internal Firewall.
```

Solution:

```text
added a rule on the Internal Firewall:
host_admin → 100.100.254.1 : 80
```

---

## 11.3 Squid received connections but did not reply

Reason:

```text
Squid was trying to go out using IPv6.
```

Solution:

```text
dns_v4_first on
```

---

## 11.4 Graylog did not respond on port 9000

Reason:

```text
Graylog was not listening on port 9000.
```

Test on the container:

```bash
ss -lntup | grep -E '80|9000|5140|12201|graylog|java'
```

Result:

```text
100.100.1.10:80
UDP 5140
UDP 12201
```

Solution:

```text
port_graylog_web = 80
```

---

# 12. Final state

At the end, the Main Firewall follows this policy:

```text
WAN:
  allows only the reverse proxy, OpenVPN and IPsec;
  blocks everything else.

DMZ:
  allows the proxyserver to reach the Internet over HTTP/HTTPS;
  allows DNS and logging towards the internal servers;
  allows the reverse proxy to reach fantasticcoffee;
  blocks everything else.

EXTERNAL_CLIENTS:
  allows access to the reverse proxy;
  allows DNS/logging from fantasticcoffee;
  blocks everything else.

INTERNAL:
  allows management only from host_admin;
  allows clients → proxyserver;
  allows clients → reverse proxy;
  allows ICMP towards the Internet;
  allows DNS server → external DNS;
  allows internal servers → proxyserver;
  allows Greenbone → DMZ/external services;
  blocks everything else.
```

The final configuration therefore follows the principle:

```text
least privilege + default deny + logging of blocked traffic
```

and is ready to be exported as the final configuration:

```text
ACME_30_main.xml
```
