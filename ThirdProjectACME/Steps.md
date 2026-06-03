# Fase 1 Setup services 

1) Web server in DMZ (.6.2)

After enabling apache2 server we create a certificate from the main firewall

common name: webserver.acme-30.test

-> we export .cert .key and ca file to webserver

We moved ssl cert to /etc/ssl/acme with specifc perms

```bash
root@webserver:~# ls -la /etc/ssl/acme/
total 27
drwxr-xr-x 2 root root    6 Jun  3 14:03 .
drwxr-xr-x 5 root root    6 Jun  3 14:03 ..
-rw-r--r-- 1 root root 1359 Jun  3 14:03 ca.crt
-rw-r--r-- 1 root root 3002 Jun  3 14:03 fullchain.crt
-rw-r--r-- 1 root root 1643 Jun  3 14:03 webserver.crt
-rw------- 1 root root 1704 Jun  3 14:03 webserver.key
root@webserver:~# 
```

webserver.crt (644 - everyone can read)
webserver.key (600 - only root)
ca.crt (644)
fullchain.crt (644) (webserver.crt + ca.crt)

Now we setup apache2 with this certs

```xml
<VirtualHost *:80> 
      ServerName webserver.acme-30.test                                                                                                                                      
      ServerAlias webserver                                                                                                                                                  
      Redirect permanent / https://webserver.acme-30.test/                                                                                                                   
  </VirtualHost>                                                                                                                                                             
                                                                                                                                                                             
  <VirtualHost *:443>                                                                                                                                                        
      ServerName webserver.acme-30.test
      ServerAlias webserver                                                                                                                                                  
      DocumentRoot /var/www/html
                                                                                                                                                                             
      SSLEngine on
      SSLCertificateFile      /etc/ssl/acme/fullchain.crt
      SSLCertificateKeyFile   /etc/ssl/acme/webserver.key                                                                                                                    
                                                                                                                                                                             
      SSLProtocol             all -SSLv3 -TLSv1 -TLSv1.1                                                                                                                     
      SSLHonorCipherOrder     off                                                                                                                                            
                                                                                                                                                                             
      Header always set Strict-Transport-Security "max-age=31536000"                                                                                                         
  </VirtualHost>
```

```bash
root@webserver:~# curl -I http://localhost/
HTTP/1.1 301 Moved Permanently
Date: Wed, 03 Jun 2026 14:15:27 GMT
Server: Apache/2.4.67 (Debian)
Location: https://webserver.acme-30.test/
Content-Type: text/html; charset=iso-8859-1

root@webserver:~# curl -kI https://localhost/
HTTP/1.1 200 OK
Date: Wed, 03 Jun 2026 14:15:31 GMT
Server: Apache/2.4.67 (Debian)
Strict-Transport-Security: max-age=31536000
Last-Modified: Mon, 10 Feb 2020 21:21:10 GMT
ETag: "29cd-59e3f517d9a69"
Accept-Ranges: bytes
Content-Length: 10701
Vary: Accept-Encoding
Content-Type: text/html

root@webserver:~# 
```

As we can see, :80 redirects to :443

:443 works 

```bash
root@dnsserver:~# openssl s_client -connect 100.100.6.2:443 -servername webserver.acme-30.test </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
subject=C = IT, ST = RM, L = Rome, O = Sapienza, CN = webserver.acme-30.test
issuer=C = IT, ST = RM, L = Rome, O = Sapienza, CN = internal-ca
notBefore=Jun  3 13:53:29 2026 GMT
notAfter=Jul  5 13:53:29 2027 GMT
X509v3 Subject Alternative Name: 
    DNS:webserver.acme-30.test, IP Address:100.100.6.2, IP Address:2001:470:B5B8:1E06:40FA:57FF:FE4A:2073, DNS:webserver
root@dnsserver:~# 
```

certificate working


# Syslog


Remote conf for rsyslog

```conf
module(load="imudp")                                                                                                                                                       
  input(type="imudp" port="514")                                                                                                                                             
                                                                                                                                                                             
  # log per host in file separati                                                                                                                                            
  template(name="RemoteLogs" type="string"                                                                                                                                   
           string="/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log")                                                                                                            
  *.* ?RemoteLogs                         
  & stop
```

then from webserver

```bash
root@webserver:~# logger -n logserver.acme-30.test -P 514 "TEST DA WEBSERVER"
```

we then read

```bash
root@logserver:~# find /var/log/remote/ -type f -exec tail -n 20 {} +
==> /var/log/remote/webserver/root.log <==
Jun  3 14:25:36 webserver root TEST DA WEBSERVER
```

## Setup NTP on logserver

                                                                                                                                                                             
  ▎ I timestamp dei log sono coerenti tra gli host perché tutti gli host ACME sono container LXC sullo stesso host Proxmox e condividono il clock del kernel. Su             
  ▎ un'infrastruttura mista (VM/bare-metal) andrebbe configurato un NTP server centralizzato (es. il Main Firewall via OPNsense Services → Network Time) con tutti i client  
  ▎ puntati a quello.


  # TODO: HARDENING ON SYSLOG TO USE CERT


# Proxy

we use SQUID (Both forward and reverse)

Proxy conf for forward proxy for internal host


```conf
# ACME internal subnets (allowed to use forward proxy)
acl acme_v4 src 100.100.1.0/24          
acl acme_v4 src 100.100.2.0/24
acl acme_v4 src 100.100.4.0/24                                                                                                                                             
acl acme_v4 src 100.100.6.0/24          
                                                                                                                                                                             
# Road-warrior VPN pools                                                                                                                                                   
acl acme_v4 src 10.8.0.0/22             
                                                                                                                                                                             
acl acme_v6 src 2001:470:b5b8:1e81::/64                                                                                                                                    
acl acme_v6 src 2001:470:b5b8:1e82::/64 
acl acme_v6 src 2001:470:b5b8:1e04::/64                                                                                                                                    
acl acme_v6 src 2001:470:b5b8:1e06::/64                                                                                                                                    
acl acme_v6 src fd00:8::/64             
                                                                                                                                                                             
http_access allow acme_v4                                                                                                                                                  
http_access allow acme_v6
```

This rules are above the http_access deny all so we allow 

```bash
root@webserver:~# curl -x http://100.100.6.3:3128 -I http://debian.org
HTTP/1.1 302 Found
Content-Length: 0
Server: Varnish
Retry-After: 0
Location: https://www.debian.org/
Accept-Ranges: bytes
Date: Wed, 03 Jun 2026 14:53:31 GMT
X-Served-By: cache-bgy-lime1210028-BGY
X-Cache: HIT
X-Cache-Hits: 0
X-Timer: S1780498411.143323,VS0,VE0
X-Cache: MISS from proxyserver
X-Cache-Lookup: MISS from proxyserver:3128
Via: 1.1 varnish, 1.1 proxyserver (squid/4.13)
Connection: keep-alive

root@webserver:~# curl -x http://100.100.6.3:3128 -I https://debian.org
HTTP/1.1 200 Connection established

HTTP/2 302 
server: Varnish
retry-after: 0
location: https://www.debian.org/
accept-ranges: bytes
date: Wed, 03 Jun 2026 14:53:35 GMT
via: 1.1 varnish
x-served-by: cache-bgy-lime1210031-BGY
x-cache: HIT
x-cache-hits: 0
x-timer: S1780498416.948195,VS0,VE0
content-length: 0

root@webserver:~# 
```

- HTTP → 302 con Via: 1.1 proxyserver (squid/4.13) ✓
  - HTTPS → Connection established (tunnel CONNECT) + response del server ✓


Policy futura:

 ▎ Gli host della rete Clients non hanno accesso diretto a Internet su HTTP/HTTPS. L'unico cammino consentito è attraverso il forward proxy in DMZ (proxyserver:3128). I 
  ▎ client sono configurati esplicitamente (variabile d'ambiente HTTP_PROXY o impostazioni del browser); il transparent proxy con SSL inspection è stato valutato ma scartato
  ▎  perché richiede SSL bumping, che rompe la fiducia end-to-end del certificato (RFC 8744, considerazioni sul HTTPS intercept).
       


## Reverse proxy using Nginx




```json
server {                                                                                                                                                                   
      listen 80;                                                                                                                                                             
      listen [::]:80;                                                                                                                                                        
      server_name webserver.acme-30.test webserver fantasticcoffee.acme-30.test fantasticcoffee;                                                                             
      return 301 https://$host$request_uri;                                                                                                                                  
  }
                                                                                                                                                                             
  # Webserver (backend HTTPS in DMZ)
  server {
      listen 443 ssl http2;
      listen [::]:443 ssl http2;
      server_name webserver.acme-30.test webserver;                                                                                                                          
  
      ssl_certificate     /etc/nginx/ssl/webserver-fullchain.crt;                                                                                                            
      ssl_certificate_key /etc/nginx/ssl/webserver.key;
      ssl_protocols TLSv1.2 TLSv1.3;                                                                                                                                         
      add_header Strict-Transport-Security "max-age=31536000" always;
                                                                                                                                                                             
      location / {
          proxy_pass https://100.100.6.2;                                                                                                                                    
          proxy_ssl_verify off;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;                                                                                                                           
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;                                                                                                                        
      }                                                                                                                                                                      
  }
                                                                                                                                                                             
  # Fantasticcoffee (backend HTTP in External Services)
  server {
      listen 443 ssl http2;
      listen [::]:443 ssl http2;                                                                                                                                             
      server_name fantasticcoffee.acme-30.test fantasticcoffee;
                                                                                                                                                                             
      ssl_certificate     /etc/nginx/ssl/fantasticcoffee-fullchain.crt;                                                                                                      
      ssl_certificate_key /etc/nginx/ssl/fantasticcoffee.key;
      ssl_protocols TLSv1.2 TLSv1.3;                                                                                                                                         
      add_header Strict-Transport-Security "max-age=31536000" always;                                                                                                        
  
      location / {                                                                                                                                                           
          proxy_pass http://100.100.4.10;
          proxy_set_header Host $host;                                                                                                                                       
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;                                                                                                       
          proxy_set_header X-Forwarded-Proto $scheme;                                                                                                                        
      }
  }
```






# Graylog

We add new input:

- Syslog UDP (on port 5140)
- GELF UDP (on port 12201)

## Test

```bash
root@dnsserver:~# logger -n 100.100.1.10 -P 5140 "TEST verso Graylog da webserver"
```

![graylog](imgs/graylog_log_from_dnsserver.png)


# Greenbone

just put it up... and reachable by kali linux to 100.100.1.4:9392... it works


# Fantastic coffe


![FC](image.png)

