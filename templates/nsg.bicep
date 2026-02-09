param clientPip1 string
param clientPip2 string
param providerPip1 string
param providerPip2 string
param providerPip3 string
param providerPip4 string

resource nsg  'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'outsidensg'
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'Allow-VPN-in'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefixes: [
            clientPip1
            clientPip2
            providerPip1
            providerPip2
            providerPip3
            providerPip4
          ]                 
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}
output nsgId string = nsg.id
