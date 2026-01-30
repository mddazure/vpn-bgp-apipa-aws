param location string = 'swedencentral'
param rgname string = 'vpn-bgp-apipa-aws-rg'

param customerVnetName string = 'client-Vnet'
param customerVnetIPrange string = '10.0.0.0/16'
param customerVmSubnetIPrange string = '10.0.2.0/24'
param customerGwSubnetIPrange string = '10.0.3.0/24'

param customerVmName string = 'client-Vm'
param customerVNETGWName string = 'client-Vnet-gw'
param customerPip1Name string = 'gw-1-pip'
param customerPip2Name string = 'gw-2-pip'
param customerPip3Name string = 'client-Vm-pip'
param customerVmprivateip string = '10.0.2.4'

param providerVnetName string = 'provider-Vnet'
param providerVnetIPrange string = '10.10.0.0/16'
param providerOutsideSubnet0IPrange string = '10.10.0.0/24'
param providerOutsideSubnet1IPrange string = '10.10.10.0/24'
param providerInsideSubnetIPrange string = '10.10.1.0/24'
param providerVmSubnetIPrange string = '10.10.2.0/24'
param arsSubnetIPrange string = '10.10.4.0/24'
param arsIP1 string = '10.10.4.4'
param arsIP2 string = '10.10.4.5'

param providerVmName string = 'provider-Vm'
param providerWeb1Name string = 'provider-Web1'
param providerWeb2Name string = 'provider-Web2'
param providerC8k10Name string = 'c8k-10'
param providerC8k20Name string = 'c8k-20'
param providerPip1Name string = 'c8k-10-pip1'
param providerPip2Name string = 'c8k-10-pip2'
param providerPip3Name string = 'c8k-20-pip1'
param providerPip4Name string = 'c8k-20-pip2'
param c8k10asn int = 65002
param c8k20asn int = 65002
param c8k10insideIP string = '10.10.1.4'
param c8k20insideIP string = '10.10.1.5'
param c8k10outside0IP string = '10.10.0.4'
param c8k10outside1IP string = '10.10.10.4'
param c8k20outside0IP string = '10.10.0.5'
param c8k20outside1IP string = '10.10.10.5'
param providerVmprivateip string = '10.10.2.4'
param providerWeb1privateip string = '10.10.2.5'
param providerWeb2privateip string = '10.10.2.6'

param c8k10Apipa1 string = '169.254.21.1' // tunnel101 on c8k-10 = bgp neighbor 169.254.21.2 update source - lng-c8k-10-1
param c8k10Apipa2 string = '169.254.22.5' // tunnel102 on c8k-10 = bgp neighbor 169.254.22.6 update source - lng-c8k-10-2
param c8k20Apipa1 string = '169.254.22.1' // tunnel101 on c8k-20 = bgp neighbor 169.254.21.6 update source - lng-c8k-20-1
param c8k20Apipa2 string = '169.254.21.5' // tunnel102 on c8k-20 = bgp neighbor 169.254.22.2update source - lng-c8k-20-2

param instance0Apipa1 string = '169.254.21.2'  // Gateway Instance 0 IP
param instance0Apipa2 string = '169.254.22.2'  // Gateway Instance 1 IP
param instance1Apipa1 string = '169.254.21.6'  // Gateway Instance 0 IP
param instance1Apipa2 string = '169.254.22.6'  // Gateway Instance 1 IP

param adminUsername string = 'AzureAdmin'
@secure()
param adminPassword string = 'vpn@123456'
@secure()
param vpnkey string = 'vpnkey123'

targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgname
  location: location
}

module prefix 'prefix.bicep' = {
  name: 'prefix'
  scope: rg
}
module customerVnet 'vnet.bicep' = {
  name: 'customerVnet'
  scope: rg
  params: {
    vnetname: customerVnetName
    vnetIPrange: customerVnetIPrange
    vmSubnetIPrange: customerVmSubnetIPrange
    gwSubnetIPrange: customerGwSubnetIPrange
    prefixId: prefix.outputs.prefixId
    pip1Name: customerPip1Name
    pip2Name: customerPip2Name
    pip3Name: customerPip3Name
  }
}
module providerVnet 'vnet.bicep' = {
  name: 'providerVnet'
  scope: rg
  params: {
    vnetname: providerVnetName
    vnetIPrange: providerVnetIPrange
    outsideSubnet0IPrange: providerOutsideSubnet0IPrange
    outsideSubnet1IPrange: providerOutsideSubnet1IPrange
    insideSubnetIPrange: providerInsideSubnetIPrange
    vmSubnetIPrange: providerVmSubnetIPrange
    arsSubnetIPrange: arsSubnetIPrange
    pip1Name: providerPip1Name
    pip2Name: providerPip2Name
    pip3Name: providerPip3Name
    pip4Name: providerPip4Name
    prefixId: prefix.outputs.prefixId
  }
}
module outsideNsg 'nsg.bicep' = {
  name: 'outsideNsg'
  scope: rg
  params: {
    customerPip1: customerVnet.outputs.pubIp1
    customerPip2: customerVnet.outputs.pubIp2
    providerPip1: providerVnet.outputs.pubIp1
    providerPip2: providerVnet.outputs.pubIp2
    providerPip3: providerVnet.outputs.pubIp3
    providerPip4: providerVnet.outputs.pubIp4
  }
}
module customerVm 'vm.bicep' = {
  name: 'customerVm'
  scope: rg
  params: {
    vmname: customerVmName
    subnetId: customerVnet.outputs.vmSubnetId
    vmprivateip: customerVmprivateip
    vmpublicipid: customerVnet.outputs.pubip3Id
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
module providerVm 'vm.bicep' = {
  name: 'providerVm'
  scope: rg
  params: {
    vmname: providerVmName
    subnetId: providerVnet.outputs.vmSubnetId
    vmprivateip: providerVmprivateip
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
module providerWeb1 'vm-web.bicep' = {
  name: 'providerWeb1'
  scope: rg
  dependsOn: [
    providerVm
  ]
  params: {
    vmname: providerWeb1Name
    subnetId: providerVnet.outputs.vmSubnetId
    vmprivateip: providerWeb1privateip
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
module providerWeb2 'vm-web.bicep' = {
  name: 'providerWeb2'
  scope: rg
  dependsOn: [
    providerWeb1
  ]
  params: {
    vmname: providerWeb2Name
    subnetId: providerVnet.outputs.vmSubnetId
    vmprivateip: providerWeb2privateip
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
  module providerC8k10 'c8k.bicep' = {
  name: 'providerC8k-10'
  scope: rg
  params: {
    ck8name: providerC8k10Name
    vnetname: providerVnet.outputs.vnetId
    insideSubnetid: providerVnet.outputs.insideSubnetId
    insideIP: c8k10insideIP
    outsideSubnet0id: providerVnet.outputs.outsideSubnet0Id
    outsideSubnet1id: providerVnet.outputs.outsideSubnet1Id
    outsideIP0: c8k10outside0IP
    outsideIP1: c8k10outside1IP
    nsGId: outsideNsg.outputs.nsgId
    pubIp1Id: providerVnet.outputs.pubip1Id
    pubIp2Id: providerVnet.outputs.pubip2Id
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
module providerC8k20 'c8k.bicep' = {
  name: 'providerC8k-20'
  scope: rg
  params: {
    ck8name: providerC8k20Name
    vnetname: providerVnet.outputs.vnetId
    insideSubnetid: providerVnet.outputs.insideSubnetId
    insideIP: c8k20insideIP
    outsideSubnet0id: providerVnet.outputs.outsideSubnet0Id
    outsideSubnet1id: providerVnet.outputs.outsideSubnet1Id
    outsideIP0: c8k20outside0IP
    outsideIP1: c8k20outside1IP
    nsGId: outsideNsg.outputs.nsgId
    pubIp1Id: providerVnet.outputs.pubip3Id
    pubIp2Id: providerVnet.outputs.pubip4Id
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
module clientgw 'gw.bicep' = {
  name: 'clientgw'
  scope: rg
  params: {
  customerVNETGWName: customerVNETGWName
  customerPip1Id: customerVnet.outputs.pubip1Id
  customerPip2Id: customerVnet.outputs.pubip2Id
  customerVnetId: customerVnet.outputs.vnetId  
  instance0Apipa1: instance0Apipa1
  instance1Apipa1: instance1Apipa1
  instance0Apipa2: instance0Apipa2
  instance1Apipa2: instance1Apipa2
  }
}
module lngc8k101'lng.bicep' ={
  name: 'lng-c8k-10-1'
  scope: rg   
  params: {
    lngname: 'lng-c8k-10-1'
    localbgpasn: c8k10asn
    c8kApipa: c8k10Apipa1
    remotepubip: providerVnet.outputs.pubIp1
  }
}
module lngc8k102'lng.bicep' ={
  name: 'lng-c8k-10-2'
  scope: rg   
  params: {
    lngname: 'lng-c8k-10-2'
    localbgpasn: c8k10asn
    c8kApipa: c8k10Apipa2
    remotepubip: providerVnet.outputs.pubIp2
  }
}
module lngc8k201 'lng.bicep' ={
  name: 'lng-c8k-20-1'
  scope: rg   
  params: {
    lngname: 'lng-c8k-20-1'
    localbgpasn: c8k20asn
    c8kApipa: c8k20Apipa1
    remotepubip: providerVnet.outputs.pubIp3
  }
}
module lngc8k202 'lng.bicep' ={
  name: 'lng-c8k-20-2'
  scope: rg   
  params: {
    lngname: 'lng-c8k-20-2'
    localbgpasn: c8k20asn
    c8kApipa: c8k20Apipa2
    remotepubip: providerVnet.outputs.pubIp4
  }
}
module conc8k101 'connection.bicep' ={
  // connection from instance0 of VPN GW to c8k-10-pip1 (represented by lngc8k101)
  // instance0 <- 169.254.21.2(10.0.3.4) <- T101 -> 169.254.21.1 -> c8k-10-pip1
  // see documentation: https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-aws-bgp
  name: 'con-c8k-10-1'
  scope: rg   
  params: {
    connectionname: 'con-c8k-10-1'
    vnetgwid: clientgw.outputs.vnetgwId
    lngid: lngc8k101.outputs.lngid
    key: vpnkey
    custombgpip1: instance0Apipa1 // 169.254.21.2
    custombgpip2: instance1Apipa1 // 169.254.21.6 (not used)
  }
}
module conc8k102 'connection.bicep' ={
  // connection from instances of VPN GW to c8k-10-pip2 (represented by lngc8k102)
  // 
  name: 'con-c8k-10-2'
  dependsOn:[
    conc8k101
  ]
  scope: rg   
  params: {
    connectionname: 'con-c8k-10-2'
    vnetgwid: clientgw.outputs.vnetgwId
    lngid: lngc8k102.outputs.lngid
    key: vpnkey
    custombgpip1: instance0Apipa2 // 169.254.22.2
    custombgpip2: instance1Apipa1 // 169.254.21.6 (not used)
  }
}
module conc8k201 'connection.bicep' ={
  // connection from both instances of VPN GW to c8k-20-pip1 (represented by lngc8k201)
  name: 'con-c8k-20-1'
  scope: rg   
  params: {
    connectionname: 'con-c8k-20-1'
    vnetgwid: clientgw.outputs.vnetgwId
    lngid: lngc8k201.outputs.lngid
    key: vpnkey
    custombgpip1: instance0Apipa1 // 169.254.21.2 (not used)
    custombgpip2: instance1Apipa1 // 169.254.21.6 
  }
}
module conc8k202 'connection.bicep' ={
  // connection from both instances of VPN GW to c8k-20-pip2 (represented by lngc8k202)
  name: 'con-c8k-20-2'
  dependsOn:[
    conc8k201
  ]
  scope: rg   
  params: {
    connectionname: 'con-c8k-20-2'
    vnetgwid: clientgw.outputs.vnetgwId
    lngid: lngc8k202.outputs.lngid
    key: vpnkey
    custombgpip1: instance0Apipa1 // 169.254.21.2 (not used)
    custombgpip2: instance1Apipa1 // 169.254.22.6 
  }
}
module ars 'rs.bicep' = {
  name: 'ars'
  dependsOn:[
    providerC8k10
    providerC8k20
  ]
  scope: rg
  params: {
    c8k10asn: c8k10asn
    c8k20asn: c8k20asn
    arssubnetId: providerVnet.outputs.arsSubnetId
    prefixId: prefix.outputs.prefixId
    c8k10privateIPv4: c8k10insideIP
    c8k20privateIPv4: c8k20insideIP
    arsIP1: arsIP1
    arsIP2: arsIP2
  }
}
output clientgwvnetgwIp1 string = clientgw.outputs.vnetgwIp1
output clientgwvnetgwIp2 string = clientgw.outputs.vnetgwIp2
