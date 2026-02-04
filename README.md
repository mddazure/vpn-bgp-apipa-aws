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

| LNG          |NVA Public IP | NVA BGP IP   | 
|--------------|----------    |--------------|
|lng-c8k-10-1  |c8k-10-pip1   | 169.254.21.1 |
|lng-c8k-10-2  |c8k-10-pip2   | 169.254.22.5 |
|lng-c8k-20-1  |c8k-20-pip1   | 169.254.22.1 |
|lng-c8k-20-2  |c8k-20-pip2   | 169.254.21.5 |

Connection objects connect the VNET Gateway to the LNGs. With an Active-Active VNET Gateway each Connection object represents *two* tunnels, one from each Gateway Instance to the LNG it connects to. When the remote device has *two* public endpoints, and is represented by *two* LNGs (which is the more common configuration), this reults in a full bow-tie of four tunnels. 

In the the AWS set-up we have *four* LNGs, and we need *four* Connections - of which only one tunnel is actually used. The other tunnel does not have a corresponding tunnel interface configuration on the NVA (or AWS VPN Gateway) and remains unused.

|Connection   |From GW Instance |To LNG        | NVA Public IP |Custom BGP Address     |NVA Tunnel int  | NVA BGP IP | 
|-------------|-----------------|--------------|-------------- |--------------------   |----------------|------------|
|con-c8k-10-1 |Instance 0       |lng-c8k-10-1  |c8k-10-pip1    |169.254.21.2           |c8k-10 Tunnel101|169.254.21.1|
|             |Instance 1       |              |               |169.254.21.6 (not used)|none            |none        |
|con-c8k-10-2 |Instance 0       |lng-c8k-10-2  |               |169.254.22.2 (not used)|none            |none        |
|             |Instance 1       |              |c8k-10-pip2    |169.254.22.6           |c8k-10 Tunnel102|169.254.22.5|
|con-c8k-20-1 |Instance 0       |lng-c8k-20-1  |c8k-20-pip1    |169.254.22.2           |c8k-20 Tunnel101|169.254.22.1|
|             |Instance 1       |              |               |169.254.21.6 (not used)|none            |none        |
|con-c8k-20-2 |Instance 0       |lng-c8k-20-2  |               |169.254.22.2 (not used)|none            |none        |
|             |Instance 1       |              |c8k-20-pip2    |169.254.21.6           |c8k-20 Tunnel102|169.254.21.5|

Each instance of the VNET Gateway is configured with two Custom (APIPA) BGP addresses. Each Connection object has two APIPA addresses selected, of which only one is used per the table above. The tunnel interfaces on the NVA's are assigned APIPA addresses, which are also used to source the neighbors to the VNET Gateway. This configuration does not use Loopback addresses.

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

On both Cisco 8000v NVA's:

- Verify that the Tunnel interfaces are up by entering `sh ip int brief`: