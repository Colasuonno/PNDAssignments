# Where to place VPN for main firewall? (OpenVPN)


## The choice
OpenVPN runs **on the Main firewall** (OPNsense has it built in). Road warriors hit the firewall's public IP, the tunnel terminates there, and the decrypted traffic pops out on a virtual interface (`tun0`) right inside the firewall.

## Why this works

The whole point of the assignment is that Alice, Bob, Christina and Diana have different access. The only way to enforce that is to let the firewall see their traffic in plaintext and apply rules.

Picture what happens after Diana connects:

1. Her laptop sends a packet to the internal server `10.0.30.5`.
2. The packet gets encrypted by OpenVPN and travels over the internet as UDP to the firewall's public IP.
3. The firewall decrypts it and the cleartext packet shows up on `tun0` with source IP `10.8.40.2` (Diana's VPN address).
4. The firewall checks its rules: "traffic from the admin pool → any internal net → allow." Forwarded.

Now Alice tries the same trick. Her packet arrives on `tun0` with source `10.8.10.2` (external-user pool). Firewall rule: "external pool → only external services net." Packet to the internal server gets dropped. Done.

The trick is that the **VPN pool subnet acts as the identity tag**. One subnet per role, four sets of rules, and the firewall does the rest.

## Why not the other options

**VPN box sitting in the internal network.** The encrypted tunnel crosses the firewall before being decrypted, so when the firewall sees the packet it just looks like "UDP 1194 toward the VPN box." It has no idea whether it's Alice or Diana inside. You'd lose role enforcement completely.

**VPN box in the DMZ.** Now the decrypted traffic has to leave the DMZ box and re-enter the firewall to reach internal stuff. You end up poking a bunch of holes from DMZ to internal networks, and the decrypted packets float around the DMZ where other DMZ hosts could potentially see them.

**Dual-interface VPN box in DMZ.** Cleaner than the previous one, but you're adding a whole extra machine, two interfaces, and routing gymnastics, just to end up writing the same per-role rules you'd write on the firewall anyway.

## What gets exposed
Just one UDP port (1194 or whatever you pick) open on the firewall's WAN. Everything else stays closed.