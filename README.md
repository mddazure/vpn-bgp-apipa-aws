# **Highly available Site-to-Site VPN to AWS with BGP over APIPA addresses**
A site-to-site VPN connection to Amazon Web Services is somewhat different from the usual Azure-to-onprem or Azure-to-Azure S2S VPN connections. 

The main complexities are:
- AWS uses APIPA addresses for the tunnel endpoints and BGP neighbors. Azure supports APIPA addresses for BGP over VPN, but common practice (and default) is to use the VNET Gateway instance IP addresses, taken from the Gateway Subnet.
- The AWS VPN Gateway has *two* public IP addresses *per Instance*. The whole Gateway has *four* public IPs and each public IP sources a single tunnel. The Azure VNET Gateway has one public IP address per Instance, with two tunnels (one to each remote device instance) sourced from the single address. This means that in Azure, the remote AWS Gateway is represented by *four* Local Network Gateways, and *four* Connection objects are required.

Common practice is for remote devices to have a single public IP address per instance (same as the Azure VNET Gateway). Each remote instance is represented by a single LNG - so *two* in total. Two Connection objects (each representing two tunnels) then connect the Azurte VNET Gateway to the pair of remote devices. 

[How to connect AWS and Azure using a BGP-enabled VPN gateway](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-aws-bgp) describes how to build a highly available S2S VPN connection between AWS and Azure.

![image](/images/vpn-bgp-apipa-aws.png)

 

