 Output: due XML di rollback.                                                                                                                                               
                                                                                                                                                                             
  ---                                                                                                                                                                        
  Fase 1 — Configurazione dei servizi (sez. 4 del report)                                                                                                                    
                                                                                                                                                                             
  Obiettivo: ogni servizio della traccia gira con un setup minimo ma realistico.
                                                                                                                                                                             
  1. Web server (DMZ, .6.2): genera cert self-signed con la CA interna creata in A2 → vhost HTTPS su 443 → redirect 80→443 in nginx/apache.                                  
  2. DNS (SRV, .1.2): già fatto in A1, verifica solo che resolv.conf di tutti gli host punti lì.                                                                             
  3. Syslog server (SRV, .1.3): rsyslog in ascolto UDP 514, log per host in /var/log/remote/.                                                                                
  4. Proxy (DMZ, .6.3): Squid in forward (client interni → Internet) + reverse per Web se vuoi (port 80/443 da Internet).                                                    
  5. Graylog (SRV, .1.10): GELF UDP input su 12201 + Syslog input su 5140; controlla che la UI risponda su 9000.                                                             
  6. Greenbone (SRV, .1.4): crea uno scan target con tutti gli host ACME, esegui una scan dummy per validare l'agente.                                                       
  7. fantasticcoffee (EXT, .4.10): pagina HTTPS su 443 (anche solo statica).                                                                                                 
                                                                                                                                                                             
  Output: screenshot dei servizi attivi + snippet di config per il report.                                                                                                   
                                                                                                                                                                             
  ---                                                                                                                                                                        
  Fase 2 — Definizione formale della policy (sez. 5 del report)
                                                               
  Obiettivo: scrivere la policy prima di implementarla. Niente click sulla GUI in questa fase.
                                                                                                                                                                             
  - Apri un foglio (o direttamente il report.tex) e scrivi:                                                                                                                  
    a. Matrice zone × zone (quella che ti ho mostrato).                                                                                                                      
    b. Tabella dei flussi consentiti (src → dst : porta : motivo).                                                                                                           
    c. Eccezioni speciali: Greenbone outbound-only, traffico ICMPv6 minimo per IPv6, anti-spoofing WAN.                                                                      
                                                                                                                                                                             
  Output: due tabelle pronte da incollare nel report. Tutto ciò che farai dopo deve derivare solo da queste tabelle.                                                         
                                                                                                                                                                             
  ---                                                                                                                                                                        
  Fase 3 — Pulizia delle regole esistenti su entrambi i FW
                                                                                                                                                                             
  Obiettivo: partire da default-deny vero.
                                                                                                                                                                             
  Per ogni interfaccia (WAN, DMZ, EXT, Transit, IntSrv, Clients, OpenVPN, IPSec):                                                                                            
  - Rimuovi tutte le pass rules tranne quelle dell'A2 (OpenVPN per ruolo, IPSec selectors). Quelle restano: la policy A3 le ingloba.
  - Rimuovi la Default allow LAN to any se ancora presente.                                                                                                                  
  - Non disabilitare la regola anti-lockout sulla rete da cui amministri.
                                                                                                                                                                             
  Su WAN: abilita Block private networks e Block bogon networks (anti-spoofing nativo di OPNsense).                                                                          
                                                                                                                                                                             
  Output: test rapido — un host nella rete Clients non deve più riuscire a fare ping 8.8.8.8 (perché manca il proxy/internet allow). Se ancora pinga, c'è una pass rule      
  sporca.                                                                                                                                                                    
                                                                                                                                                                             
  ---             
  Fase 4 — Alias su entrambi i FW
                                 
  Obiettivo: scrivere regole parlanti, non IP raw.
                                                                                                                                                                             
  Crea questi alias (Firewall → Aliases):                                                                                                                                    
  - Host: webserver (.6.2), proxy (.6.3), dns (.1.2), logserver (.1.3), greenbone (.1.4), graylog (.1.10), fantasticcoffee (.4.10), admin_pc (.2.100).                       
  - Network: dmz_net, ext_net, srv_net, cli_net.                                                                                                                             
  - Port: web_ports (80,443), proxy_ports (3128,8080), syslog_port (514), gelf_port (12201).
  - Riusa quelli VPN dell'A2: vpn_external, vpn_standard, vpn_power, vpn_admin.                                                                                              
                                                                                                                                                                             
  Output: lista alias replicata su Main e Internal (gli alias devono esistere su entrambi i FW se servono lì).                                                               
                                                                                                                                                                             
  ---                                                                                                                                                                        
  Fase 5 — Regole sul Main Firewall                                                                                                                                          
                                                                                                                                                                             
  Obiettivo: tradurre la tabella dei flussi nelle pass rules su Main, una riga per riga.
                                                                                                                                                                             
  Ordine consigliato (interfaccia per interfaccia):                                                                                                                          
  1. WAN: pass per OpenVPN 1194 (già presente), pass Internet → webserver:443, pass → proxy:80,443, pass → fantasticcoffee:443. Niente altro.                                
  2. DMZ: pass proxy → Internet (80/443), pass DMZ hosts → dns:53, → logserver:514, → graylog:12201.                                                                         
  3. EXT: pass fantasticcoffee → logserver:514, pass restrittivo verso Internet se serve.           
  4. Transit: pass per IPSec/ESP, pass per i flussi che devono attraversare verso SRV/CLI.                                                                                   
  5. OpenVPN: lascia le regole role-based dell'A2.                                                                                                                           
  6. Su ogni interfaccia aggiungi in fondo: block log any → any.                                                                                                             
                                                                                                                                                                             
  Output: screenshot delle 6 interfacce con le regole + export intermedio ACME_30_main.xml per sicurezza.                                                                    
                                                                                                                                                                             
  ---                                                                                                                                                                        
  Fase 6 — Regole sull'Internal Firewall                                                                                                                                     
                                        
  Obiettivo: stessa logica, lato interno.
                                                                                                                                                                             
  1. Transit (verso Main): pass del traffico autorizzato in uscita (clients → proxy DMZ, DNS replies, ecc.), IPSec già presente.                                             
  2. IntSrv: pass dns → Internet (forward DNS), pass greenbone → tutte le zone, pass logging in entrata.                                                                     
  3. Clients: pass cli_net → proxy:3128, pass → dns:53, pass → webserver:443; pass admin_pc → mgmt (SSH/443) verso srv_net e DMZ.                                            
  4. OpenVPN/IPSec: regole simmetriche di A2.                                                                                                                                
  5. Fondo di ogni interfaccia: block log any → any.                                                                                                                         
                                                                                                                                                                             
  Output: screenshot + ACME_30_internal.xml.                                                                                                                                 
                  
  ---                                                                                                                                                                        
  Fase 7 — Logging del firewall stesso
                                      
  Obiettivo: chiudere il loop: i FW devono mandare i loro log a Graylog.
                                                                                                                                                                             
  - System → Settings → Logging / targets → +Add: target Syslog → graylog su UDP 5140 (o 12201 GELF), facility Local0, applications: filter, suricata se attivo.             
  - Su entrambi i FW.                                                                                                                                                        
  - Verifica su Graylog che arrivino eventi Block in tempo reale.                                                                                                            
                                                                                                                                                                             
  Output: screenshot della dashboard Graylog con drop count crescente quando provi un ping vietato.                                                                          
                                                                                                                                                                             
  ---                                                                                                                                                                        
  Fase 8 — Test di enforcement (sez. 7 del report)
                                                                                                                                                                             
  Obiettivo: prova per ogni riga della tabella flussi che funziona, e per almeno una combinazione vietata per ogni zona che è bloccata.
                                                                                                                                                                             
  Per ogni test annota:
  - comando esatto (es. curl -kI https://100.100.6.2, ping 100.100.0.2, nmap -Pn -p 22 100.100.1.2)                                                                          
  - atteso (ALLOW/DENY)                                                                                                                                                      
  - osservato          
  - riga di log del FW corrispondente                                                                                                                                        
                  
  Test minimi obbligatori:                                                                                                                                                   
  - Internet → web HTTPS (allow), Internet → web SSH (deny), Internet → FW WAN ICMP (deny)
  - Client → proxy 3128 (allow), Client → Internet diretto 443 (deny)                                                                                                        
  - VPN Alice → EXT (allow), VPN Alice → SRV (deny)                  
  - Greenbone → un host random (allow), un host random → Greenbone:9392 (deny)                                                                                               
  - ping IPv6 cross-zone, controllo che ICMPv6 NS/NA continui a funzionare    
                                                                                                                                                                             
  Output: tabella test pronta per il report + qualche screenshot del Firewall Live View sul drop.                                                                            
                                                                                                                                                                             
  ---                                                                                                                                                                        
  Fase 9 — Export finale, report e zip                                                                                                                                       
                                                                                                                                                                             
  Obiettivo: consegna.
                                                                                                                                                                             
  1. Export XML definitivi: Configuration → Backups → Download → rinomina in ACME_30_main.xml e ACME_30_internal.xml.                                                        
  2. Compila il report ACME_30_a3_report.pdf con le 8 sezioni della traccia, riusando il template NobArticle. Tabelle/screenshot già accumulati nelle fasi 1-8.
  3. Crea ACME_30_a3.zip con i tre file alla radice (no sottocartelle). Se includi script di test, mettili in root.                                                          
  4. Verifica con unzip -l che non ci siano .DS_Store o cartelle annidate.                                                                                                   
                                                                                                                                                                             
  Output: ACME_30_a3.zip pronto da caricare in Classroom.                                                                                                                    
                                                                                                                                                                             
  ---             
  Stima tempi (indicativa, in coppia/gruppo)
                                                                                                                                                                             
  ┌──────┬────────┬───────────────────────────────────────────┐
  │ Fase │ Tempo  │                    Chi                    │                                                                                                              
  ├──────┼────────┼───────────────────────────────────────────┤
  │ 0    │ 10 min │ 1 persona                                 │                                                                                                              
  ├──────┼────────┼───────────────────────────────────────────┤
  │ 1    │ 3-4 h  │ 2 in parallelo (servizi indipendenti)     │
  ├──────┼────────┼───────────────────────────────────────────┤                                                                                                              
  │ 2    │ 1 h    │ tutti insieme, lavagna                    │
  ├──────┼────────┼───────────────────────────────────────────┤                                                                                                              
  │ 3    │ 30 min │ 1 persona per FW                          │
  ├──────┼────────┼───────────────────────────────────────────┤                                                                                                              
  │ 4    │ 30 min │ 1 persona                                 │
  ├──────┼────────┼───────────────────────────────────────────┤                                                                                                              
  │ 5    │ 2 h    │ 1 persona                                 │
  ├──────┼────────┼───────────────────────────────────────────┤
  │ 6    │ 1.5 h  │ 1 persona                                 │
  ├──────┼────────┼───────────────────────────────────────────┤                                                                                                              
  │ 7    │ 30 min │ 1 persona                                 │
  ├──────┼────────┼───────────────────────────────────────────┤                                                                                                              
  │ 8    │ 2 h    │ a coppie (uno spara, uno guarda i log)    │
  ├──────┼────────┼───────────────────────────────────────────┤                                                                                                              
  │ 9    │ 2-3 h  │ uno scrive il report, gli altri rileggono │
  └──────┴────────┴───────────────────────────────────────────┘