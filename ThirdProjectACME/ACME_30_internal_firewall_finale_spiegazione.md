# ACME 30 — Internal Firewall finale  
## Ragionamento, configurazione pratica e test svolti

Questo file descrive in modo dettagliato come è stato configurato l’**Internal Firewall-Router** della rete ACME.  
L’obiettivo dell’Internal Firewall è separare e proteggere le reti interne, applicando una policy restrittiva basata sul principio:

```text
Default deny:
tutto è bloccato, tranne ciò che è esplicitamente permesso.
```

Il lavoro fatto sull’Internal Firewall è stato complementare a quello fatto sul Main Firewall.  
Il Main Firewall controlla il traffico tra DMZ, WAN, rete external services e lato interno; l’Internal Firewall invece controlla soprattutto:

```text
CLIENTS ↔ SERVERS
CLIENTS/SERVERS ↔ Main Firewall
CLIENTS/SERVERS ↔ DMZ
CLIENTS/SERVERS ↔ servizi di logging, DNS, Graylog, Greenbone
```

In pratica, l’Internal Firewall è quello che decide cosa possono fare i client e i server interni.

---

# 1. Ruolo dell’Internal Firewall

L’Internal Firewall ha tre tab principali:

| Tab / Interfaccia | Ruolo |
|---|---|
| `CLIENTS` | traffico proveniente dalla rete client `100.100.2.0/24` |
| `SERVERS` | traffico proveniente dalla rete server interna `100.100.1.0/24` |
| `EXTERNAL` | traffico proveniente dal lato verso Main Firewall / DMZ / external services |
| `IPsec` | regole IPsec già presenti, da non modificare se non necessario |
| `Loopback` | regole interne automatiche, da non toccare |

Le reti principali sono:

```text
net_clients = 100.100.2.0/24
net_srv     = 100.100.1.0/24
net_dmz     = 100.100.6.0/24
net_ext     = 100.100.4.0/24
```

Gli IP più importanti sono:

```text
Internal Firewall lato SERVERS = 100.100.1.1
Internal Firewall lato CLIENTS = 100.100.2.1
Main Firewall lato interno     = 100.100.254.1
```

La macchina amministrativa è:

```text
host_admin = 100.100.2.100
```

cioè Kali.

---

# 2. Obiettivo della policy sull’Internal Firewall

La policy finale deve permettere solo i flussi necessari.

In particolare:

```text
CLIENTS:
  possono usare DNS interno;
  possono usare Squid proxy;
  possono raggiungere reverse proxy;
  possono inviare log;
  possono raggiungere Graylog/Greenbone solo se host_admin;
  possono fare ping dove previsto;
  non devono avere accesso libero ai server interni.

SERVERS:
  possono usare DNS esterno tramite il DNS server;
  possono usare il proxy se necessario;
  Greenbone può scansionare le reti autorizzate;
  il resto è bloccato.

EXTERNAL:
  permette alcuni flussi da DMZ/external services verso server interni di supporto:
  DNS, Syslog, Graylog;
  blocca tutto il resto.
```

Il punto importante è che l’Internal Firewall non deve essere una semplice porta aperta tra clients e servers.  
Deve invece impedire movimenti laterali non autorizzati.

---

# 3. Alias usati sull’Internal Firewall

Abbiamo usato gli stessi alias creati anche sul Main Firewall, in modo da mantenere coerenza.

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

## 3.2 Alias reti

| Alias | Valore | Significato |
|---|---:|---|
| `net_clients` | `100.100.2.0/24` | Rete client |
| `net_srv` | `100.100.1.0/24` | Rete server interni |
| `net_dmz` | `100.100.6.0/24` | Rete DMZ |
| `net_ext` | `100.100.4.0/24` | Rete external services |

## 3.3 Alias porte

| Alias | Valore | Significato |
|---|---:|---|
| `port_web` | `80,443` | HTTP/HTTPS |
| `port_dns` | `53` | DNS TCP/UDP |
| `port_proxy` | `3128` | Squid forward proxy |
| `port_syslog` | `514` | Syslog UDP standard |
| `port_graylog_syslog` | `5140` | Graylog Syslog input |
| `port_graylog_gelf` | `12201` | Graylog GELF input |
| `port_graylog_web` | `80` | Graylog Web UI nel nostro setup |
| `port_greenbone` | `9392` | Greenbone Web UI |

Nota importante: anche sull’Internal Firewall l’alias `port_graylog_web` deve essere `80`, non `9000`, perché Graylog nel nostro setup ascolta sulla porta `80`.

---

# 4. Configurazione della tab CLIENTS

La tab `CLIENTS` controlla il traffico che entra nell’Internal Firewall dalla rete client:

```text
net_clients = 100.100.2.0/24
```

Questa è la tab più importante per controllare cosa possono fare gli utenti/client.

La vecchia regola:

```text
IPv4+6 * → * PASS
```

è stata disabilitata.

## Perché?

Perché una regola `any → any` dalla rete client permetterebbe ai client di raggiungere liberamente server interni, firewall, DMZ e altri servizi.  
Questo sarebbe contrario al principio di least privilege.

---

## 4.1 Admin verso GUI del Main Firewall

Abbiamo aggiunto:

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

## Perché?

Durante i test non riuscivamo ad accedere alla GUI del Main Firewall da Kali.  
Avevamo già verificato che la GUI del Main Firewall ascoltava su HTTP porta `80`, non su HTTPS `443`.

Il traffico da Kali al Main Firewall però attraversa prima l’Internal Firewall:

```text
Kali 100.100.2.100
    ↓
Internal Firewall
    ↓
Main Firewall 100.100.254.1
```

Quindi serviva una regola anche sull’Internal Firewall.

Abbiamo usato destinazione:

```text
100.100.254.1/32
```

e non:

```text
100.100.254.1/24
```

perché vogliamo permettere l’accesso solo al singolo host `100.100.254.1`, non a tutta la rete `100.100.254.0/24`.

---

## 4.2 Admin verso GUI dell’Internal Firewall

Abbiamo aggiunto:

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

## Perché?

Kali è la macchina amministrativa, quindi deve poter gestire anche l’Internal Firewall.

Abbiamo limitato la sorgente a:

```text
host_admin
```

e non a:

```text
net_clients
```

perché non tutti i client devono poter amministrare il firewall.

---

## 4.3 Clients verso DNS interno

Regola:

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

## Perché?

I client devono poter risolvere nomi interni ed eventualmente nomi esterni attraverso il DNS server interno.

Non abbiamo permesso:

```text
net_clients → Internet : 53
```

perché vogliamo centralizzare le query DNS sul server interno.

---

## 4.4 Clients verso forward proxy Squid

Regola:

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

## Perché?

I client devono poter navigare in HTTP/HTTPS usando Squid:

```text
client → proxyserver:3128 → Internet
```

Questa regola non dà Internet diretto ai client.  
Permette solo di raggiungere il proxy.

Il traffico successivo verso Internet viene poi controllato dal Main Firewall sulla tab `DMZ`, dove solo `host_proxyserver` è autorizzato a uscire verso HTTP/HTTPS.

---

## 4.5 Clients verso reverse proxy

Regola:

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

## Perché?

I client devono poter raggiungere i servizi pubblicati dal reverse proxy:

```text
webserver.acme-30.test
fantasticcoffee.acme-30.test
```

Il traffico va verso:

```text
host_proxyserver : 80/443
```

e non direttamente verso i backend.

---

## 4.6 Clients verso Syslog server

Regola:

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

## Perché?

I client possono inviare log al server syslog centralizzato.

Questo serve per logging e auditing.

---

## 4.7 Clients verso Graylog Syslog input

Regola:

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

## Perché?

I client possono inviare log anche a Graylog tramite Syslog UDP sulla porta `5140`.

---

## 4.8 Clients verso Graylog GELF input

Regola:

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

## Perché?

Graylog supporta anche l’input GELF UDP sulla porta `12201`.  
La regola permette agli host autorizzati della rete client di inviare eventi anche in questo formato.

---

## 4.9 Admin verso Greenbone

Regola:

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

## Perché?

Greenbone è uno strumento amministrativo/sensibile.  
La sua interfaccia web non deve essere accessibile da tutti i client.

Per questo abbiamo permesso:

```text
host_admin → Greenbone:9392
```

e non:

```text
net_clients → Greenbone:9392
```

---

## 4.10 Admin verso Graylog Web UI

Regola finale corretta:

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

dove:

```text
port_graylog_web = 80
```

## Perché?

La Web UI di Graylog è uno strumento amministrativo.  
Deve essere raggiungibile da Kali, ma non da tutti i client.

Durante i test abbiamo scoperto che Graylog non ascoltava sulla porta `9000`.

Sul container `graylog` abbiamo eseguito:

```bash
ss -lntup | grep -E '80|9000|5140|12201|graylog|java'
```

Il risultato mostrava:

```text
tcp LISTEN [::ffff:100.100.1.10]:80
udp UNCONN *:5140
udp UNCONN *:12201
```

Quindi la UI è su:

```text
http://100.100.1.10:80
```

Per questo abbiamo corretto l’alias:

```text
port_graylog_web = 80
```

---

## 4.11 Clients verso ICMP

Regola:

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

## Perché?

Il ping è utile per test diagnostici e verifica di raggiungibilità.

L’importante è che questa regola permette solo ICMP, non traffico TCP/UDP libero.

---

## 4.12 Block finale CLIENTS

Regola finale:

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

## Perché?

Serve a bloccare tutto ciò che non è stato permesso esplicitamente.

Esempi di traffico che deve essere bloccato:

```text
client normale → Greenbone Web UI
client normale → Graylog Web UI
client → server interni non autorizzati
client → Main Firewall management
client → Internet diretto HTTP/HTTPS
```

---

# 5. Ordine finale della tab CLIENTS

L’ordine è importante perché OPNsense valuta le regole dall’alto verso il basso.

Ordine finale:

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

La vecchia regola `IPv4+6 * → * PASS` è rimasta disabilitata.

---

# 6. Configurazione della tab SERVERS

La tab `SERVERS` controlla il traffico che entra nell’Internal Firewall dalla rete server interna:

```text
net_srv = 100.100.1.0/24
```

Qui si trovano servizi come:

```text
dnsserver
logserver
greenbone
graylog
```

Anche qui la vecchia regola generica:

```text
IPv4+6 * → * PASS
```

è stata disabilitata.

---

## 6.1 DNS server verso DNS esterno

Regola:

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

## Perché?

Il DNS server interno deve poter inoltrare richieste DNS verso l’esterno o risolvere nomi esterni.

Abbiamo permesso questa uscita solo a:

```text
host_dnsserver
```

e non a tutta la rete `net_srv`.

Questo mantiene centralizzata la risoluzione DNS.

---

## 6.2 Server interni verso forward proxy

Regola:

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

## Perché?

Abbiamo scelto di permettere anche ai server interni di usare Squid per eventuali richieste HTTP/HTTPS verso Internet.

Questa regola non consente:

```text
net_srv → Internet diretto
```

ma solo:

```text
net_srv → proxyserver:3128
```

Quindi rimane coerente con la policy:

```text
Internet HTTP/HTTPS tramite proxy
```

Importante: questa regola deve essere presente anche sul Main Firewall, tab `INTERNAL`, perché il traffico dal server interno al proxyserver attraversa entrambi i firewall:

```text
server interno
  ↓
Internal Firewall - SERVERS
  ↓
Main Firewall - INTERNAL
  ↓
proxyserver:3128
```

Per questo abbiamo aggiunto anche sul Main Firewall:

```text
net_srv → host_proxyserver : port_proxy
```

---

## 6.3 Greenbone verso clients

Regola:

```text
Action: Pass
Interface: SERVERS
Direction: in
Protocol: any
Source: host_greenbone
Destination: net_clients
Description: A3_ALLOW_GREENBONE_SCAN_CLIENTS
```

## Perché?

Greenbone è il vulnerability scanner.  
Deve poter scansionare i client, quindi gli abbiamo permesso traffico ampio verso `net_clients`.

La regola è ampia sul protocollo, ma limitata alla sorgente:

```text
host_greenbone
```

Questo significa che non tutti i server possono scansionare i client, ma solo Greenbone.

---

## 6.4 Greenbone verso DMZ

Regola:

```text
Action: Pass
Interface: SERVERS
Direction: in
Protocol: any
Source: host_greenbone
Destination: net_dmz
Description: A3_ALLOW_GREENBONE_SCAN_DMZ
```

## Perché?

Greenbone deve poter testare i servizi esposti in DMZ, per esempio:

```text
webserver
proxyserver
```

Anche qui la regola è ampia perché uno scanner deve testare più porte e protocolli, ma la sorgente è limitata a Greenbone.

---

## 6.5 Greenbone verso external services

Regola:

```text
Action: Pass
Interface: SERVERS
Direction: in
Protocol: any
Source: host_greenbone
Destination: net_ext
Description: A3_ALLOW_GREENBONE_SCAN_EXTERNAL_SERVICES
```

## Perché?

Greenbone deve poter scansionare anche la rete degli external services, in particolare `fantasticcoffee`.

---

## 6.6 Block finale SERVERS

Regola finale:

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

## Perché?

Serve a bloccare tutto il resto dalla rete server.

Esempi di traffico che non deve passare liberamente:

```text
server generico → clients:any
server generico → DMZ:any
server generico → Internet:any
server generico → external services:any
```

Solo i flussi espliciti sono consentiti.

---

# 7. Ordine finale della tab SERVERS

Ordine finale:

```text
1. A3_ALLOW_DNSSERVER_TO_EXTERNAL_DNS
2. A3_ALLOW_SERVERS_TO_FORWARD_PROXY
3. A3_ALLOW_GREENBONE_SCAN_CLIENTS
4. A3_ALLOW_GREENBONE_SCAN_DMZ
5. A3_ALLOW_GREENBONE_SCAN_EXTERNAL_SERVICES
6. A3_BLOCK_LOG_DEFAULT_DENY_SERVERS
```

La vecchia `IPv4+6 * → * PASS` è disabilitata.

---

# 8. Configurazione della tab EXTERNAL

La tab `EXTERNAL` dell’Internal Firewall gestisce il traffico che arriva dal lato esterno rispetto all’Internal Firewall, cioè da reti come:

```text
DMZ
external services
Main Firewall side
```

Questa tab è importante perché permette ad alcuni host non appartenenti alla rete server interna di raggiungere servizi interni di supporto, come DNS e logging.

Anche qui la vecchia regola:

```text
IPv4+6 * → * PASS
```

è stata disabilitata.

---

## 8.1 DMZ verso DNS server

Regola:

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

## Perché?

Gli host DMZ come `webserver` e `proxyserver` devono poter usare il DNS server interno.

---

## 8.2 Fantasticcoffee verso DNS server

Regola:

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

## Perché?

Anche `fantasticcoffee` deve poter risolvere nomi usando il DNS interno.

---

## 8.3 DMZ verso Syslog server

Regola:

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

## Perché?

Gli host in DMZ devono poter inviare log al syslog server interno.

---

## 8.4 Fantasticcoffee verso Syslog server

Regola:

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

## Perché?

La vending machine può inviare log al syslog server.

---

## 8.5 DMZ verso Graylog Syslog

Regola:

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

## Perché?

Gli host in DMZ possono inviare log a Graylog tramite Syslog input sulla porta `5140`.

---

## 8.6 DMZ verso Graylog GELF

Regola:

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

## Perché?

Alcuni servizi possono usare GELF UDP per inviare eventi a Graylog.

---

## 8.7 Fantasticcoffee verso Graylog Syslog

Regola:

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

## Perché?

`fantasticcoffee` può inviare eventi a Graylog tramite Syslog.

Non abbiamo necessariamente aggiunto GELF per `fantasticcoffee`, perché il flusso richiesto e testato era Syslog.

---

## 8.8 Block finale EXTERNAL

Regola finale:

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

## Perché?

Serve a bloccare tutto il traffico proveniente dall’esterno dell’Internal Firewall che non rientra nei flussi autorizzati.

Esempi di traffico bloccato:

```text
DMZ → Greenbone Web UI
DMZ → Graylog Web UI
fantasticcoffee → server interni non autorizzati
DMZ → clients
```

---

# 9. Ordine finale della tab EXTERNAL

Ordine finale:

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

La vecchia `IPv4+6 * → * PASS` è disabilitata.

---

# 10. Problemi incontrati durante la configurazione

## 10.1 Accesso al Main Firewall bloccato

Problema:

```text
Da Kali non riuscivamo ad accedere al Main Firewall.
```

Test:

```bash
curl -I http://100.100.254.1
```

falliva.

Abbiamo controllato sul Main Firewall che la GUI fosse su porta 80.  
Poi abbiamo capito che il traffico da Kali passava prima dall’Internal Firewall.

Soluzione:

```text
Internal Firewall → CLIENTS:
host_admin → 100.100.254.1/32 : 80
```

Dopo questa regola, l’accesso ha funzionato.

---

## 10.2 Errore `/24` invece di `/32`

Nel campo destinazione dell’IP del Main Firewall, OPNsense tendeva a mostrare una maschera.  
Il valore corretto era:

```text
100.100.254.1/32
```

e non:

```text
100.100.254.1/24
```

## Perché?

`/32` significa singolo host.

`/24` significherebbe tutta la rete:

```text
100.100.254.0/24
```

che è molto più ampia del necessario.

---

## 10.3 Graylog Web UI su porta 80, non 9000

Inizialmente avevamo definito:

```text
port_graylog_web = 9000
```

ma da Kali il test restava pending.

Sul container Graylog abbiamo eseguito:

```bash
ss -lntp | grep 9000
curl -v --max-time 10 http://127.0.0.1:9000/
```

Risultato:

```text
nessun servizio in ascolto su 9000
connection refused
```

Poi abbiamo controllato:

```bash
ss -lntup | grep -E '80|9000|5140|12201|graylog|java'
```

Risultato:

```text
tcp LISTEN [::ffff:100.100.1.10]:80
udp 5140
udp 12201
```

Quindi abbiamo corretto:

```text
port_graylog_web = 80
```

e la regola admin verso Graylog ha iniziato a funzionare.

---

# 11. Test finali sull’Internal Firewall

## 11.1 Admin verso Internal Firewall GUI

Da Kali:

```bash
curl -I http://100.100.2.1
```

Atteso:

```text
ALLOW
```

Motivo: `host_admin` può amministrare l’Internal Firewall.

---

## 11.2 Admin verso Main Firewall GUI

Da Kali:

```bash
curl -I http://100.100.254.1
```

Atteso:

```text
ALLOW
```

Motivo: `host_admin` può amministrare anche il Main Firewall attraversando l’Internal Firewall.

---

## 11.3 Clients verso DNS

Da client/Kali:

```bash
dig @100.100.1.2 webserver.acme-30.test
dig @100.100.1.2 fantasticcoffee.acme-30.test
```

Atteso:

```text
ALLOW
```

Motivo: i client devono usare il DNS interno.

---

## 11.4 Clients verso forward proxy

Da client/Kali:

```bash
curl -x http://100.100.6.3:3128 -I http://debian.org
curl -x http://100.100.6.3:3128 -I https://debian.org
```

Atteso:

```text
ALLOW
```

Motivo: i client navigano tramite Squid.

---

## 11.5 Clients verso Internet diretto

Da client/Kali:

```bash
curl -I https://debian.org --connect-timeout 5
```

Atteso:

```text
DENY / timeout
```

Motivo: Internet diretto HTTP/HTTPS non è consentito ai client.

---

## 11.6 Admin verso Greenbone

Da Kali:

```bash
curl -kI https://100.100.1.4:9392
```

Atteso:

```text
ALLOW
```

Motivo: solo `host_admin` deve accedere alla UI Greenbone.

---

## 11.7 Client non admin verso Greenbone

Da un client diverso da Kali:

```bash
curl -kI https://100.100.1.4:9392 --connect-timeout 5
```

Atteso:

```text
DENY / timeout
```

Motivo: Greenbone non deve essere accessibile a tutti i client.

---

## 11.8 Admin verso Graylog Web UI

Da Kali:

```bash
curl -I http://100.100.1.10
```

Atteso:

```text
ALLOW
```

Motivo: la Web UI Graylog è amministrativa e deve essere raggiungibile da `host_admin`.

---

## 11.9 Client o host verso Syslog server

Da client o host autorizzato:

```bash
logger -n 100.100.1.3 -P 514 "TEST FINAL A3 SYSLOG"
```

Sul logserver:

```bash
find /var/log/remote/ -type f -exec tail -n 10 {} +
```

Atteso:

```text
ALLOW, messaggio presente nei log
```

---

## 11.10 Host verso Graylog Syslog input

Da client o host autorizzato:

```bash
logger -n 100.100.1.10 -P 5140 "TEST FINAL A3 GRAYLOG SYSLOG"
```

Atteso:

```text
ALLOW, messaggio visibile nella UI Graylog
```

---

## 11.11 Greenbone verso reti da scansionare

Da Greenbone o tramite UI Greenbone:

```bash
ping -c 2 100.100.2.100
ping -c 2 100.100.6.2
ping -c 2 100.100.4.10
```

Atteso:

```text
ALLOW dove previsto
```

Motivo: Greenbone ha regole specifiche per scansionare clients, DMZ ed external services.

---

# 12. Stato finale dell’Internal Firewall

Alla fine della configurazione l’Internal Firewall applica questa policy:

```text
CLIENTS:
  host_admin può amministrare Internal Firewall e Main Firewall;
  i client possono usare DNS interno;
  i client possono usare Squid proxy;
  i client possono raggiungere reverse proxy;
  i client possono inviare log a Syslog e Graylog;
  host_admin può raggiungere Greenbone e Graylog Web UI;
  ICMP è consentito;
  tutto il resto è bloccato.

SERVERS:
  dnsserver può fare query DNS esterne;
  i server interni possono usare il proxy;
  Greenbone può scansionare clients, DMZ ed external services;
  tutto il resto è bloccato.

EXTERNAL:
  DMZ e fantasticcoffee possono usare DNS interno;
  DMZ e fantasticcoffee possono inviare log a syslog/Graylog;
  tutto il resto è bloccato.
```

La configurazione finale è quindi coerente con:

```text
least privilege
default deny
logging dei blocchi
separazione tra client, server e servizi esposti
```

ed è pronta per essere esportata come:

```text
ACME_30_internal.xml
```
