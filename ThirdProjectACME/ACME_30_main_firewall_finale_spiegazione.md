# ACME 30 — Main Firewall finale  
## Ragionamento, configurazione pratica e test svolti

Questo file riassume in modo dettagliato il lavoro fatto per configurare il **Main Firewall-Router** dell’assignment ACME.  
L’obiettivo non era semplicemente “far passare il traffico”, ma costruire una configurazione coerente con una vera **security policy**:

```text
Default deny:
tutto è bloccato, tranne ciò che è esplicitamente permesso.
```

Per questo motivo siamo partiti da una situazione iniziale in cui diversi servizi funzionavano già, ma il firewall aveva ancora regole permissive del tipo:

```text
IPv4+6 * → * PASS
```

Queste regole sono comode durante il setup, ma non sono accettabili come configurazione finale perché permettono traffico generico tra le reti.  
Il lavoro sul Main Firewall è quindi consistito nel:

1. definire quali flussi sono davvero necessari;
2. creare alias leggibili;
3. aggiungere regole specifiche per ogni interfaccia;
4. disabilitare le vecchie regole `allow any`;
5. aggiungere regole finali di `block log`;
6. testare sia gli `ALLOW` sia i `DENY`;
7. correggere alcuni problemi emersi durante i test, soprattutto su GUI firewall, Squid e Graylog.

---

# 1. Ruolo del Main Firewall

Il Main Firewall è il firewall che collega le zone più esterne della rete ACME.

Le sue interfacce principali sono:

| Interfaccia | Ruolo |
|---|---|
| `WAN` | lato Internet / rete esterna / accessi VPN |
| `DMZ` | rete dei servizi esposti, principalmente `webserver` e `proxyserver` |
| `EXTERNAL_CLIENTS` | rete external services, dove si trova `fantasticcoffee` |
| `INTERNAL` | collegamento verso l’Internal Firewall, quindi verso clients e server interni |
| `OpenVPN` | regole VPN già presenti dall’assignment precedente |
| `IPsec` | regole IPsec già presenti |
| `Loopback` | regole interne automatiche, da non toccare |

La configurazione finale deve quindi controllare soprattutto:

```text
Internet/WAN → DMZ
DMZ → Internet
DMZ → server interni
External services → server interni
Clients/server interni → DMZ/Internet tramite passaggi autorizzati
```

---

# 2. Scelta principale: esporre i servizi tramite reverse proxy

Il collega aveva già configurato `proxyserver` in DMZ con due ruoli:

```text
1. Squid forward proxy
2. Nginx reverse proxy
```

Noi abbiamo deciso di sfruttare questa architettura.

La scelta finale è stata:

```text
Internet/WAN → proxyserver:80/443
proxyserver → webserver
proxyserver → fantasticcoffee
```

e non:

```text
Internet/WAN → webserver diretto
Internet/WAN → fantasticcoffee diretto
```

## Perché questa scelta?

Perché è più sicura e più ordinata:

- il mondo esterno vede solo il reverse proxy;
- i backend reali non sono esposti direttamente;
- il controllo dell’accesso pubblico è concentrato su un solo host;
- le regole firewall sono più semplici e più difendibili nel report.

Quindi il `proxyserver` è diventato il punto pubblico di ingresso per i servizi web.

---

# 3. Alias creati sul Main Firewall

Prima di scrivere le regole abbiamo creato gli alias.  
Questo serve per evitare regole difficili da leggere basate solo su IP numerici.

Esempio: invece di scrivere:

```text
100.100.2.0/24 → 100.100.6.3 : 3128
```

abbiamo scritto:

```text
net_clients → host_proxyserver : port_proxy
```

La seconda forma è molto più chiara e rende il report più comprensibile.

---

## 3.1 Alias host

| Alias | Valore | Significato |
|---|---:|---|
| `host_webserver` | `100.100.6.2` | Web server in DMZ |
| `host_proxyserver` | `100.100.6.3` | Proxy server in DMZ |
| `host_dnsserver` | `100.100.1.2` | DNS server interno |
| `host_logserver` | `100.100.1.3` | Syslog server interno |
| `host_greenbone` | `100.100.1.4` | Vulnerability scanner |
| `host_graylog` | `100.100.1.10` | Graylog log collector |
| `host_fantasticcoffee` | `100.100.4.10` | Vending machine / external service |
| `host_admin` | `100.100.2.100` | Kali / macchina amministrativa |

---

## 3.2 Alias reti

| Alias | Valore | Significato |
|---|---:|---|
| `net_dmz` | `100.100.6.0/24` | Rete DMZ |
| `net_srv` | `100.100.1.0/24` | Rete server interni |
| `net_clients` | `100.100.2.0/24` | Rete clients |
| `net_ext` | `100.100.4.0/24` | Rete external services |

---

## 3.3 Alias porte

| Alias | Valore | Significato |
|---|---:|---|
| `port_web` | `80,443` | HTTP/HTTPS |
| `port_dns` | `53` | DNS TCP/UDP |
| `port_proxy` | `3128` | Squid forward proxy |
| `port_syslog` | `514` | Syslog UDP standard |
| `port_graylog_syslog` | `5140` | Input Syslog UDP di Graylog |
| `port_graylog_gelf` | `12201` | Input GELF UDP di Graylog |
| `port_graylog_web` | `80` | Web UI Graylog nel nostro setup |
| `port_greenbone` | `9392` | Web UI Greenbone |

Nota: inizialmente avevamo ipotizzato `port_graylog_web = 9000`, ma dai test su `graylog` abbiamo scoperto che la UI ascoltava su `100.100.1.10:80`. Quindi l’alias è stato corretto a `80`.

---

# 4. Configurazione della tab WAN

La tab `WAN` controlla il traffico che arriva dall’esterno verso il Main Firewall.

## 4.1 Regole già presenti da mantenere

Abbiamo mantenuto le regole relative a:

```text
OpenVPN UDP 1194
IPsec IKE UDP 500
IPsec NAT-T UDP 4500
ESP
```

## Perché?

Perché queste regole erano legate all’assignment precedente e servivano per mantenere funzionanti VPN/IPsec.  
Non andavano cancellate a caso.

---

## 4.2 Regola WAN verso reverse proxy

Abbiamo aggiunto:

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

Questa regola permette:

```text
Internet/WAN → proxyserver : 80/443
```

## Perché?

Perché abbiamo deciso che i servizi pubblici devono essere raggiungibili solo tramite il reverse proxy.  
Quindi dall’esterno non abbiamo aperto:

```text
WAN → webserver
WAN → fantasticcoffee
WAN → greenbone
WAN → graylog
WAN → server interni
```

---

## 4.3 Regole ICMP sulla WAN

Le regole ICMP generiche sulla WAN sono state disabilitate.

## Perché?

Perché non vogliamo esporre inutilmente il firewall a ping generici dal lato esterno.  
La policy deve essere restrittiva: dalla WAN passa solo ciò che serve.

---

## 4.4 Block finale WAN

Abbiamo aggiunto in fondo:

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

## Perché?

Perché tutto ciò che non è esplicitamente permesso deve essere bloccato e loggato.  
Questo serve anche per dimostrare nel report i test negativi.

---

# 5. Configurazione della tab DMZ

La tab `DMZ` gestisce il traffico che parte dalla DMZ verso altre zone.

Gli host principali sono:

```text
webserver   = 100.100.6.2
proxyserver = 100.100.6.3
```

La vecchia regola:

```text
IPv4+6 * → * PASS
```

è stata disabilitata.

---

## 5.1 Proxyserver verso Internet HTTP/HTTPS

Regola:

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

## Perché?

Perché Squid deve poter uscire verso Internet in HTTP/HTTPS per conto dei client autorizzati.

Questa regola non dà Internet diretto ai client.  
Permette solo al proxyserver di uscire.

---

## 5.2 Proxyserver verso Fantasticcoffee

Regola:

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

## Perché?

Perché Nginx reverse proxy deve poter inoltrare le richieste verso `fantasticcoffee`.

---

## 5.3 DMZ verso DNS

Regola:

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

## Perché?

Gli host della DMZ devono poter risolvere nomi tramite il DNS interno.

---

## 5.4 DMZ verso Syslog

Regola:

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

## Perché?

Gli host della DMZ possono inviare log al server syslog centrale.

---

## 5.5 DMZ verso Graylog

Regole:

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

## Perché?

I servizi in DMZ possono inviare eventi a Graylog, sia tramite Syslog UDP sia tramite GELF UDP.

Durante il controllo abbiamo corretto una regola che inizialmente aveva sorgente `any`.  
L’abbiamo ristretta a `net_dmz`.

## Perché questa correzione?

Perché la regola deve rappresentare la policy:

```text
DMZ → Graylog
```

non:

```text
any → Graylog
```

---

## 5.6 Block finale DMZ

Regola:

```text
Action: Block
Log: enabled
Interface: DMZ
Protocol: any
Source: any
Destination: any
Description: A3_BLOCK_LOG_DEFAULT_DENY
```

## Perché?

Per bloccare ogni altro traffico proveniente dalla DMZ.

---

# 6. Configurazione della tab EXTERNAL_CLIENTS

La tab `EXTERNAL_CLIENTS` gestisce la rete:

```text
net_ext = 100.100.4.0/24
```

dove si trova `fantasticcoffee`.

Anche qui la vecchia `PASS any` è stata disabilitata.

---

## 6.1 External clients verso reverse proxy

Regola:

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

## Perché?

Gli host della rete external services possono raggiungere i servizi pubblicati solo tramite reverse proxy.

---

## 6.2 Fantasticcoffee verso DNS

Regola:

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

## Perché?

`fantasticcoffee` può usare il DNS interno.

---

## 6.3 Fantasticcoffee verso Syslog

Regola:

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

## Perché?

La vending machine può inviare log al syslog server.

---

## 6.4 Fantasticcoffee verso Graylog

Regola:

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

## Perché?

`fantasticcoffee` può inviare eventi anche a Graylog via Syslog input.

Non abbiamo aggiunto obbligatoriamente GELF da fantasticcoffee perché nel setup testato il flusso utile era Syslog.

---

## 6.5 Block finale EXTERNAL_CLIENTS

Regola:

```text
Action: Block
Log: enabled
Interface: EXTERNAL_CLIENTS
Protocol: any
Source: any
Destination: any
Description: A3_BLOCK_LOG_DEFAULT_DENY
```

## Perché?

Tutto il resto dalla rete external services viene bloccato.

---

# 7. Configurazione della tab INTERNAL

La tab `INTERNAL` del Main Firewall è stata la più delicata, perché da qui passa anche l’accesso amministrativo.

Il traffico arriva dal lato dell’Internal Firewall, quindi può provenire da:

```text
clients
server interni
host_admin
dnsserver
greenbone
```

---

## 7.1 Problema: GUI del Main Firewall su HTTP/80

All’inizio pensavamo che la GUI del Main Firewall fosse su HTTPS porta `443`.

Il test:

```bash
curl -kI https://100.100.254.1
```

andava però in timeout.

Dalla console del Main Firewall abbiamo eseguito:

```sh
sockstat -4 -l | grep -E ':80|:443|lighttpd'
```

Il risultato mostrava che `lighttpd` ascoltava su:

```text
*:80
```

Quindi la GUI era su:

```text
http://100.100.254.1
```

non su HTTPS.

Abbiamo quindi modificato le regole da porta `443` a porta `80`.

---

## 7.2 Problema: l’Internal Firewall bloccava l’accesso al Main Firewall

Anche con il packet filter del Main Firewall disabilitato tramite:

```sh
pfctl -d
```

da Kali non riuscivamo ad accedere a:

```bash
curl http://100.100.254.1
```

Questo ha dimostrato che il problema non era il Main Firewall, ma il percorso:

```text
Kali → Internal Firewall → Main Firewall
```

Abbiamo quindi aggiunto sull’Internal Firewall una regola:

```text
host_admin → 100.100.254.1 : 80
```

Dopo questa regola, l’accesso alla GUI del Main Firewall è tornato funzionante.

---

## 7.3 Regola admin verso Main Firewall

Sul Main Firewall, tab `INTERNAL`, abbiamo lasciato la regola definitiva:

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

## Perché?

Solo `host_admin`, cioè Kali `100.100.2.100`, deve poter amministrare il Main Firewall.

Non abbiamo lasciato regole larghe come:

```text
net_clients → main firewall : 80
any → main firewall : 80
```

perché sarebbero troppo permissive.

---

## 7.4 Clients verso forward proxy

Regola:

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

## Perché?

I client devono navigare in HTTP/HTTPS tramite Squid, non direttamente verso Internet.

---

## 7.5 Clients verso reverse proxy

Regola:

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

## Perché?

I client possono raggiungere i servizi pubblicati dal reverse proxy.

---

## 7.6 Clients verso Internet solo ICMP

Regola:

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

## Perché?

Il ping verso Internet è consentito come traffico diagnostico.  
Invece HTTP/HTTPS diretto deve essere bloccato.

---

## 7.7 DNS server verso DNS esterno

Regola:

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

## Perché?

Il DNS server interno deve poter inoltrare query DNS o risolvere nomi esterni.

---

## 7.8 Server interni verso proxy

Abbiamo deciso di permettere anche ai server interni di usare il proxy, quindi abbiamo aggiunto:

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

## Perché?

La traccia dice che il proxy è usato dagli host della rete ACME per richieste HTTP/HTTPS verso Internet.  
Permettere anche ai server interni di usare Squid è coerente con questa interpretazione.

La regola resta comunque restrittiva perché non dà Internet libero ai server:

```text
net_srv → proxyserver:3128
```

e non:

```text
net_srv → Internet:any
```

---

## 7.9 Greenbone verso DMZ ed external services

Regole:

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

## Perché?

Greenbone è il vulnerability scanner, quindi deve poter scansionare host e porte nelle reti ACME.  
La regola è ampia sul protocollo, ma molto limitata sulla sorgente:

```text
solo host_greenbone
```

---

## 7.10 Block finale INTERNAL

Regola finale:

```text
Action: Block
Log: enabled
Interface: INTERNAL
Protocol: any
Source: any
Destination: any
Description: A3_BLOCK_LOG_DEFAULT_DENY
```

## Perché?

Serve a bloccare ogni traffico interno non previsto dalla policy e a produrre log utili per i test di enforcement.

---

# 8. Ordine finale delle regole

## 8.1 WAN

```text
1. A3_ALLOW_WAN_TO_REVERSE_PROXY_HTTP_HTTPS
2. OpenVPN UDP 1194
3. IPsec IKE UDP 500
4. IPsec NAT-T UDP 4500
5. IPsec ESP
6. eventuali regole IPv6 IPsec già presenti
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

# 9. Problema Squid: timeout causato da IPv6

Durante i test, il client riusciva a raggiungere Squid:

```bash
nc -vz -w 5 100.100.6.3 3128
```

La porta era aperta, quindi:

```text
client → proxyserver:3128
```

funzionava.

Però le richieste tramite proxy andavano in timeout:

```bash
curl -v --connect-timeout 5 -x http://100.100.6.3:3128 -I http://debian.org
```

---

## 9.1 Test diretti dal proxyserver

Sul proxyserver abbiamo verificato:

```bash
ip route
cat /etc/resolv.conf
dig debian.org
curl -I http://debian.org --connect-timeout 5
curl -I https://debian.org --connect-timeout 5
```

Risultato:

```text
DNS funzionante
HTTP diretto funzionante
HTTPS diretto funzionante
```

Quindi la regola:

```text
host_proxyserver → Internet : 80/443
```

era corretta.

---

## 9.2 Analisi dei log Squid

Abbiamo controllato:

```bash
tail -n 80 /var/log/squid/access.log
```

e abbiamo visto righe come:

```text
HIER_DIRECT/2a04:4e42:600::644
HIER_DIRECT/2a04:4e42:200::644
HIER_DIRECT/2a04:4e42:400::644
```

Questi sono indirizzi IPv6.

Conclusione:

```text
Squid provava a uscire verso debian.org usando IPv6.
```

Le regole configurate invece erano principalmente IPv4, quindi il traffico restava in timeout.

---

## 9.3 Correzione Squid

Abbiamo modificato `/etc/squid/squid.conf`.

Prima backup:

```bash
cp /etc/squid/squid.conf /etc/squid/squid.conf.bak_a3
```

Poi abbiamo aggiunto:

```conf
dns_v4_first on
```

Controllo configurazione:

```bash
squid -k parse
```

Riavvio:

```bash
systemctl restart squid
systemctl status squid --no-pager
```

---

## 9.4 Test Squid dopo correzione

Sul proxyserver:

```bash
curl -v --max-time 15 -x http://127.0.0.1:3128 -I http://debian.org
```

Risultato:

```text
HTTP/1.1 302 Found
Via: 1.1 proxyserver (squid/4.13)
```

Per HTTPS:

```bash
curl -v --max-time 15 -x http://127.0.0.1:3128 -I https://debian.org
```

Risultato:

```text
HTTP/1.1 200 Connection established
```

Da client:

```bash
curl -x http://100.100.6.3:3128 -I http://debian.org
curl -x http://100.100.6.3:3128 -I https://debian.org
```

Nel log sono poi apparse righe IPv4:

```text
100.100.2.100 TCP_MISS/302 ... HIER_DIRECT/151.101.130.132
100.100.2.100 TCP_TUNNEL/200 ... HIER_DIRECT/151.101.130.132
```

Quindi il problema era risolto.

---

# 10. Test finali del Main Firewall

## 10.1 GUI Main Firewall

Da Kali:

```bash
curl -I http://100.100.254.1
```

Atteso:

```text
ALLOW
```

Motivo: `host_admin` può amministrare il Main Firewall.

---

## 10.2 Forward proxy HTTP

Da client/Kali:

```bash
curl -x http://100.100.6.3:3128 -I http://debian.org
```

Atteso:

```text
ALLOW
Via: proxyserver
```

---

## 10.3 Forward proxy HTTPS

Da client/Kali:

```bash
curl -x http://100.100.6.3:3128 -I https://debian.org
```

Atteso:

```text
ALLOW
HTTP/1.1 200 Connection established
```

---

## 10.4 Internet diretto bloccato

Da client/Kali:

```bash
curl -I https://debian.org --connect-timeout 5
```

Atteso:

```text
DENY / timeout
```

Motivo: i client non devono uscire direttamente in HTTP/HTTPS.

---

## 10.5 ICMP verso Internet

Da client/Kali:

```bash
ping -c 3 8.8.8.8
```

Atteso:

```text
ALLOW
```

Motivo: il ping è stato lasciato permesso per diagnostica.

---

## 10.6 Reverse proxy verso webserver

Da client/Kali:

```bash
curl -vkI --resolve webserver.acme-30.test:443:100.100.6.3 https://webserver.acme-30.test/
```

Atteso:

```text
ALLOW
```

---

## 10.7 Reverse proxy verso fantasticcoffee

Da client/Kali:

```bash
curl -vkI --resolve fantasticcoffee.acme-30.test:443:100.100.6.3 https://fantasticcoffee.acme-30.test/
```

Atteso:

```text
ALLOW
```

---

## 10.8 Proxyserver verso Internet

Da proxyserver:

```bash
curl -I http://debian.org --connect-timeout 5
curl -I https://debian.org --connect-timeout 5
```

Atteso:

```text
ALLOW
```

---

## 10.9 DNS dal proxyserver

Da proxyserver:

```bash
dig debian.org
```

Atteso:

```text
ALLOW, risposta dal DNS interno 100.100.1.2
```

---

# 11. Errori/problemi incontrati e loro significato

## 11.1 Curl HTTPS verso Main Firewall non funzionava

Errore:

```text
curl: failed to connect to 100.100.254.1 port 443
```

Motivo:

```text
la GUI non era su 443, ma su 80.
```

Soluzione:

```text
usare http://100.100.254.1
e regole firewall su porta 80.
```

---

## 11.2 Con `pfctl -d` sul Main Firewall l’accesso non funzionava ancora

Motivo:

```text
il blocco era sull’Internal Firewall.
```

Soluzione:

```text
aggiunta regola sull’Internal Firewall:
host_admin → 100.100.254.1 : 80
```

---

## 11.3 Squid riceveva ma non rispondeva

Motivo:

```text
Squid provava a uscire in IPv6.
```

Soluzione:

```text
dns_v4_first on
```

---

## 11.4 Graylog non rispondeva su 9000

Motivo:

```text
Graylog non ascoltava su 9000.
```

Test sul container:

```bash
ss -lntup | grep -E '80|9000|5140|12201|graylog|java'
```

Risultato:

```text
100.100.1.10:80
UDP 5140
UDP 12201
```

Soluzione:

```text
port_graylog_web = 80
```

---

# 12. Stato finale

Alla fine il Main Firewall rispetta questa policy:

```text
WAN:
  permette solo reverse proxy, OpenVPN e IPsec;
  blocca il resto.

DMZ:
  permette al proxyserver di uscire su HTTP/HTTPS;
  permette DNS e logging verso i server interni;
  permette reverse proxy verso fantasticcoffee;
  blocca il resto.

EXTERNAL_CLIENTS:
  permette accesso al reverse proxy;
  permette DNS/logging da fantasticcoffee;
  blocca il resto.

INTERNAL:
  permette management solo da host_admin;
  permette client → proxyserver;
  permette client → reverse proxy;
  permette ICMP verso Internet;
  permette DNS server → DNS esterno;
  permette server interni → proxyserver;
  permette Greenbone → DMZ/external services;
  blocca il resto.
```

La configurazione finale segue quindi il principio:

```text
least privilege + default deny + logging dei blocchi
```

ed è adatta a essere esportata come configurazione finale:

```text
ACME_30_main.xml
```
