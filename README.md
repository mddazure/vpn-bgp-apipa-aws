# **Highly available Site-to-Site VPN to AWS with BGP over APIPA addresses**
A site-to-site VPN connection to Amazon Web Services is somewhat different from the usual Azure-to-onprem or Azure-to-Azure S2S VPN connections. 

The main complexities are:
- AWS uses APIPA addresses for the tunnel endpoints and BGP neighbors. Azure supports APIPA addresses for BGP over VPN, but common practice (and default) is to use the VNET Gateway instance IP addresses, taken from the Gateway Subnet.
- The AWS VPN Gateway has *two* public IP addresses *per Instance*. The whole Gateway has *four* public IPs and each public IP sources a single tunnel. The Azure VNET Gateway has one public IP address per Instance, with two tunnels (one to each remote device instance) sourced from the single address. This means that in Azure, the remote AWS Gateway is represented by *four* Local Network Gateways, and *four* Connection objects are required.

Common practice is for remote devices to have a single public IP address per instance (same as the Azure VNET Gateway). Each remote instance is represented by a single LNG - so *two* in total. Two Connection objects (each representing two tunnels) then connect the Azurte VNET Gateway to the pair of remote devices. 

[How to connect AWS and Azure using a BGP-enabled VPN gateway](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-aws-bgp) describes how to build a highly available S2S VPN connection between AWS and Azure.

This lab deploys a S2S VPN in the configuration required by AWS.

## Architecture

The deployment consists of a Client-VNET, holding a VNET Gateway, and a Provider-VNET containing a pair of Cisco 8000v NVAs that simulates the AWS end of the connection. Each NVA has *two* outside interfaces with a Public IP attached, on separate subnets.

Four Local Network Gateways represent the NVA's:
#### Local Network Gateways

| LNG          |NVA Public IP | NVA BGP IP   | 
|--------------|----------    |--------------|
|lng-c8k-10-1  |c8k-10-pip1   | 169.254.21.1 |
|lng-c8k-10-2  |c8k-10-pip2   | 169.254.22.5 |
|lng-c8k-20-1  |c8k-20-pip1   | 169.254.22.1 |
|lng-c8k-20-2  |c8k-20-pip2   | 169.254.21.5 |

Connection objects connect the VNET Gateway to the LNGs. With an Active-Active VNET Gateway each Connection object represents *two* tunnels, one from each Gateway Instance to the LNG it connects to. When the remote device has *two* public endpoints, and is represented by *two* LNGs (which is the more common configuration), this reults in a full bow-tie of four tunnels. 

In the AWS set-up we have *four* LNGs, and we need *four* Connections - of which only one tunnel of each is actually used. The other tunnel does not have a corresponding tunnel interface configuration on the NVA (or AWS VPN Gateway) and remains unused.

#### Connections

|Connection   |From GW |To LNG      | NVA Public IP|
|-------------|--------|------------|--------------|
|con-c8k-10-1 |Inst 0  |lng-c8k-10-1|c8k-10-pip1   |
|             |Inst 1  |            |              |
|con-c8k-10-2 |Inst 0  |lng-c8k-10-2|              |
|             |Inst 1  |            |c8k-10-pip2   |
|con-c8k-20-1 |Inst 0  |lng-c8k-20-1|c8k-20-pip1   |
|             |Inst 1  |            |              |
|con-c8k-20-2 |Inst 0  |lng-c8k-20-2|              |
|             |Inst 1  |            |c8k-20-pip2   |

Each instance of the VNET Gateway is configured with two Custom (APIPA) BGP addresses. Each Connection object has two APIPA addresses selected, of which only one is used per the table above. The tunnel interfaces on the NVA's are assigned APIPA addresses, which are also used to source the neighbors to the VNET Gateway. 
(This configuration does *not* use Loopback addresses to terminate the BGP neighbors, as opposed to the common standard configuration with a single public IP per remote vpn device described here: [Highly available Site-to-Site VPN with BGP over APIPA addresses](https://github.com/mddazure/vpn-bgp-apipa)).

#### APIPA BGP Endpoints

|Connection   |Custom BGP Address     |NVA Tunnel int  | NVA BGP IP | 
|-------------|-----------------------|----------------|------------|
|con-c8k-10-1 |169.254.21.2           |c8k-10 Tunnel101|169.254.21.1|
|             |169.254.21.6 (not used)|none            |none        |
|con-c8k-10-2 |169.254.22.2 (not used)|none            |none        |
|             |169.254.22.6           |c8k-10 Tunnel102|169.254.22.5|
|con-c8k-20-1 |169.254.22.2           |c8k-20 Tunnel101|169.254.22.1|
|             |169.254.21.6 (not used)|none            |none        |
|con-c8k-20-2 |169.254.22.2 (not used)|none            |none        |
|             |169.254.21.6           |c8k-20 Tunnel102|169.254.21.5|



![image](/images/vpn-bgp-apipa-aws.png)

 ## Deploy
Log in to Azure Cloud Shell at https://shell.azure.com/ and select Bash.

Ensure Azure CLI and extensions are up to date:
  
      az upgrade --yes
  
If necessary select your target subscription:
  
      az account set --subscription <Name or ID of subscription>
  
Clone the  GitHub repository:
  
      git clone https://github.com/mddazure/vpn-bgp-apipa-aws
  
Change directory:
  
      cd ./vpn-bgp-apipa-aws

Accept the terms for the CSR8000v Marketplace offer:

      az vm image terms accept -p cisco -f cisco-c8000v-byol --plan 17_13_01a-byol -o none

Deploy the Bicep template:

      az deployment sub create --location swedencentral --template-file templates/main.bicep

Verify that all components in the diagram above have been deployed to the resourcegroup `vpn-bgp-apipa-aws-rg` and are healthy. 

Credentials to the Cisco 8000v NVAs and the other VMs:

Username = `AzureAdmin`

Password = `vpn@123456`

## Configure
Both Cisco 8000v NVA's are up but must still be configured.

Log in to the each NVA, preferably via the Serial console in the portal as this does not rely on network connectivity in the VNET. 
  - Serial console is under Support + troubleshooting in the Virtual Machine blade.

Enter credentials.

Enter Enable mode by typing `en` at the prompt, then enter Configuration mode by typing `conf t`. Paste in the below commands:

      license boot level network-advantage addon dna-advantage
      do wr mem
      do reload

The NVA will now reboot. When rebooting is complete log on again through Serial Console. Enter Enable mode by typing `en` at the prompt, then enter Configuration mode by typing `conf t`.

Retrieve the instance public IP addresses of VNET Gateway `client-Vnet-gw`  either from the output of the deployment or from the portal.

Copy [c8k-10.ios](https://raw.githubusercontent.com/mddazure/vpn-bgp-apipa-aws/refs/heads/main/templates/c8k-10.ios) and [c8k-20.ios](https://raw.githubusercontent.com/mddazure/vpn-bgp-apipa-aws/refs/heads/main/templates/c8k-10.ios) into Notepad and replace the [gw-1-pip] and [gw-2-pip] placeholders by  the gateway's public IP addresses.

Copy and paste the configurations into each of the NVAs. 

## Inspect

On both Cisco 8000v NVA's:

- Verify that the Tunnel interfaces are up by entering `sh ip int brief`:

```
c8k-10#sh ip int brief
Interface              IP-Address      OK? Method Status                Protocol
GigabitEthernet1       10.10.0.4       YES DHCP   up                    up      
GigabitEthernet2       10.10.1.4       YES DHCP   up                    up      
GigabitEthernet3       10.10.10.4      YES DHCP   up                    up      
Tunnel101              169.254.21.1    YES manual up                    up      
Tunnel102              169.254.22.5    YES manual up                    up      
VirtualPortGroup0      192.168.35.101  YES NVRAM  up                    up

c8k-20#sh ip int brief
Interface              IP-Address      OK? Method Status                Protocol
GigabitEthernet1       10.10.0.5       YES DHCP   up                    up      
GigabitEthernet2       10.10.1.5       YES DHCP   up                    up      
GigabitEthernet3       10.10.10.5      YES DHCP   up                    up      
Tunnel101              169.254.22.1    YES manual up                    up      
Tunnel102              169.254.21.5    YES manual up                    up      
VirtualPortGroup0      192.168.35.101  YES NVRAM  up                    up      
```
- Verify that the BGP neighbors relationships to the VNET Gateway and to Azure Route Server are established by entering `sh ip bgp summary`:

```
c8k-10#sh ip bgp summary
BGP router identifier 169.254.22.5, local AS number 65002
BGP table version is 252, main routing table version 252
2 network entries using 496 bytes of memory
4 path entries using 544 bytes of memory
2/2 BGP path/bestpath attribute entries using 592 bytes of memory
2 BGP AS-PATH entries using 48 bytes of memory
0 BGP route-map cache entries using 0 bytes of memory
0 BGP filter-list cache entries using 0 bytes of memory
BGP using 1680 total bytes of memory
BGP activity 7/5 prefixes, 133/129 paths, scan interval 60 secs
5 networks peaked at 11:36:04 Jan 30 2026 UTC (5d22h ago)

Neighbor        V           AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
10.10.4.4       4        65515   12742   12272      252    0    0 1w0d            1
10.10.4.5       4        65515   12741   12268      252    0    0 1w0d            1
169.254.21.2    4        65001   12883   12492      252    0    0 1w0d            1
169.254.22.6    4        65001    9834    9496      252    0    0 5d22h           1

c8k-20#sh ip bgp summary
BGP router identifier 169.254.22.1, local AS number 65002
BGP table version is 5, main routing table version 5
2 network entries using 496 bytes of memory
4 path entries using 544 bytes of memory
2/2 BGP path/bestpath attribute entries using 592 bytes of memory
2 BGP AS-PATH entries using 48 bytes of memory
0 BGP route-map cache entries using 0 bytes of memory
0 BGP filter-list cache entries using 0 bytes of memory
BGP using 1680 total bytes of memory
BGP activity 7/5 prefixes, 13/9 paths, scan interval 60 secs
3 networks peaked at 11:38:46 Jan 30 2026 UTC (5d22h ago)

Neighbor        V           AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
10.10.4.4       4        65515    9814    9460        5    0    0 5d23h           1
10.10.4.5       4        65515    9816    9459        5    0    0 5d23h           1
169.254.21.6    4        65001    9828    9486        5    0    0 5d22h           1
169.254.22.2    4        65001    9808    9461        5    0    0 5d22h           1
```
Now let's look at the BGP table, which shows the routes received via BGP:

```
c8k-10#sh ip bgp
BGP table version is 252, local router ID is 169.254.22.5
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *    10.0.0.0/16      169.254.21.6                           0 65001 i
 *>                    169.254.21.2                           0 65001 i
 *>   10.10.0.0/16     10.10.4.4                              0 65515 i
 *                     10.10.4.5                              0 65515 i

c8k-20#sh ip bgp       
BGP table version is 5, local router ID is 169.254.22.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *    10.0.0.0/16      169.254.21.6                           0 65001 i
 *>                    169.254.21.2                           0 65001 i
 *    10.10.0.0/16     10.10.4.5                              0 65515 i
 *>                    10.10.4.4                              0 65515 i
 ```
 This shows that each NVA learns the local VNET prefix from Route Server (AS Path 65515), and the remote prefix via the VPN (AS Path 65001). Note that on both NVA's the Next Hop addresses for the remote prefix are the same, even though they have neighbor relationships with different endpoints on the VNET Gateway. Apparently the VNET Gateway advertises this prefix with the same Next Hop to all neighbors:
```
c8k-10#sh ip bgp detail 
BGP routing table entry for 10.0.0.0/16, version 2
  Paths: (2 available, best #2, table default)
  Advertised to update-groups:
     1         
  Refresh Epoch 1
  65001, (received & used)
    169.254.21.6 from 169.254.22.6 (10.0.3.5)           <-----
      Origin IGP, localpref 100, valid, external
      rx pathid: 0, tx pathid: 0
      Updated on Jan 30 2026 11:36:07 UTC
  Refresh Epoch 1
  65001, (received & used)
    169.254.21.2 from 169.254.21.2 (10.0.3.4)           <-----
      Origin IGP, localpref 100, valid, external, best
      rx pathid: 0, tx pathid: 0x0
      Updated on Jan 28 2026 15:32:20 UTC


c8k-20#sh ip bgp detail
BGP routing table entry for 10.0.0.0/16, version 3
  Paths: (2 available, best #2, table default)
  Advertised to update-groups:
     5         
  Refresh Epoch 1
  65001, (received & used)
    169.254.21.6 from 169.254.21.6 (10.0.3.5)           <-----
      Origin IGP, localpref 100, valid, external
      rx pathid: 0, tx pathid: 0
      Updated on Jan 30 2026 11:39:47 UTC
  Refresh Epoch 1
  65001, (received & used)
    169.254.21.2 from 169.254.22.2 (10.0.3.4)           <-----
      Origin IGP, localpref 100, valid, external, best
      rx pathid: 0, tx pathid: 0x0
      Updated on Jan 30 2026 11:38:46 UTC
```
The route marked "best" is installed in the routing table, which means that all traffic is sent over that single path (VPN tunnel). This is the default in BGP.
```
c8k-10#sh ip route
...
Gateway of last resort is 10.10.0.1 to network 0.0.0.0

S*    0.0.0.0/0 [1/0] via 10.10.0.1
      10.0.0.0/8 is variably subnetted, 9 subnets, 3 masks
B        10.0.0.0/16 [20/0] via 169.254.21.2, 1w0d      <-----
B        10.10.0.0/16 [20/0] via 10.10.4.4, 1w0d
...
```
The device can be configured to use both tunnels by including the `maximum-paths 2` statement under the BGP configuration.
```
c8k-10#sh run | section bgp
router bgp 65002
...
 maximum-paths 2
 ```
The route table now shows two equal cost routes for networks 10.0.0.0/16 (learned from VPN) and 10.10.0.0/16 (learned from ARS):
```
c8k-10#sh ip route
Gateway of last resort is 10.10.0.1 to network 0.0.0.0

S*    0.0.0.0/0 [1/0] via 10.10.0.1
      10.0.0.0/8 is variably subnetted, 9 subnets, 3 masks
B        10.0.0.0/16 [20/0] via 169.254.21.6, 00:00:06  <-----
                     [20/0] via 169.254.21.2, 00:00:06  <-----
B        10.10.0.0/16 [20/0] via 10.10.4.5, 00:00:06
                      [20/0] via 10.10.4.4, 00:00:06
```
Now let's look at the configuration on the Azure end of the connection.

In the portal, navigate to client-Vnet-gw under the vpn-bgp-apipa-lab-rg Resource group. The overview page shows graphs for Total tunnel ingress and Total tunnel egress traffic:

![image](/images/client-vnet-gw-overview.png)

The Configuration page shows the Custom APIPA BGP addresses configured during the deployment:

![image](/images/client-vnet-gw-configuration.png)

Now navigate to the "Local Network Gateways" page under Hybrid Connectivty, and filter on the resource group the lab is deployed in. Note that there are *four* LNG's:

![image](/images/local-network-gateways.png) 

Each LNG is configured with one of the four remote device Public IP's and APIPA BGP endpoint addresses, per the [Local Network Gateways](#Local-Network-Gateways) table above:

![image](/images/lng-c8k-10-1-config.png)

Now navigate to Connections. There are four Connections, one from each Local Network Gateway to the VNET Gateway, per the [Connections](#Connections) table:

![image](/images/connections.png)

 Each connection actually represents two tunnels - one to each instance of the VNET Gateway. In the configuration deployed here, one tunnel of each Connection is left unused; it does not have a matching tunnel interface on the remote VPN devices and one BGP APIPA address is left unused per the [APIPA BGP Endpoints](#APIPA-BGP-Endpoints) table:

![image](/images/con-8k-10-1-config.png)

## Test
Log on to `client-Vm` via Serial Console in the portal.

Call the web servers `provider-Web1` and `provider-Web2` at `10.10.2.5` and 10.10.2.6` via Curl. Both should respond with their names:

```
AzureAdmin@client-Vm:~$ curl 10.10.2.5
provider-Web1
AzureAdmin@client-Vm:~$ curl 10.10.2.6
provider-Web2
```
Download and run a shell script to continuously call both web servers:
```
wget https://raw.githubusercontent.com/mddazure/vpn-bgp-apipa-aws/refs/heads/main/templates/loop.sh && sudo chmod +x loop.sh && ./loop.sh
...
loop.sh.1           100%[===================>]      91  --.-KB/s    in 0s      

2026-02-09 12:50:46 (5.72 MB/s) - ‘loop.sh.1’ saved [91/91]

provider-Web1
provider-Web2
provider-Web1
provider-Web2
provider-Web1
provider-Web2
provider-Web1
...
```
Now simulate a failure of NVA c8k-10:
- log on to the device via Serial Console
- shut down both outside interfaces

```
c8k-10(config-if)#int gig1
c8k-10(config-if)#shut    
c8k-10(config-if)#
*Feb  9 13:11:25.194: %LINEPROTO-5-UPDOWN: Line protocol on Interface Tunnel101, changed state to downshut
*Feb  9 13:11:27.198: %LINK-5-CHANGED: Interface GigabitEthernet1, changed state to administratively down
*Feb  9 13:11:28.198: %LINEPROTO-5-UPDOWN: Line protocol on Interface GigabitEthernet1, changed state to down
c8k-10(config-if)#int gig3
c8k-10(config-if)#shut    
c8k-10(config-if)#
*Feb  9 13:12:41.121: %LINEPROTO-5-UPDOWN: Line protocol on Interface Tunnel102, changed state to down
*Feb  9 13:12:41.153: %CRYPTO-6-ISAKMP_ON_OFF: ISAKMP is OFF
*Feb  9 13:12:43.124: %LINK-5-CHANGED: Interface GigabitEthernet3, changed state to administratively down
*Feb  9 13:12:44.125: %LINEPROTO-5-UPDOWN: Line protocol on Interface GigabitEthernet3, changed state to down
```
Depending on through which instance and tunnel the gateway sends traffic to the remote network, the flow of responses observed on Client-VM may be interrupted. If the flow continues when the outside interfaces on c8k-10 are shut, try shutting down on c8k-20.

It may take up to three minutes for BGP to detect the failure: the default setting for the BGP Hold Timer is 180 seconds, which is the time that a BGP speaker waits for keep-alives before declaring its neighbor dead and reconverging the routing.

The VNET Gateway does not do equal cost multipath routing over BGP-learned routes, even though it shows multiple routes in its BGP table. The connection may be interrupted for up to three minutes when a device fails or looses connectivity.

In Expressroute, this is mitigated by [Bidirectional Forward Detection](https://learn.microsoft.com/en-us/azure/expressroute/expressroute-bfd) which detects a link failure in seconds. Unfortunately, BFD is not available on VPN connections.
