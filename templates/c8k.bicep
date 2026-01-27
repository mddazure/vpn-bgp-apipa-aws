param ck8name string
param vnetname string
param insideSubnetid string
param outsideSubnet0id string
param outsideSubnet1id string
param insideIP string
param outsideIP0 string
param outsideIP1 string
param pubIp1Id string
param pubIp2Id string
param adminUsername string
param adminPassword string
param nsGId string


resource insidenic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${ck8name}-insidenic'
  location: resourceGroup().location
  properties: {
    enableIPForwarding: true
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: insideSubnetid
          }
          primary: true
          privateIPAllocationMethod: 'Static'
          privateIPAddress: insideIP
        }
      }
    ]
  }
}
resource outsidenic0 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${ck8name}-outsidenic0'
  location: resourceGroup().location
  properties: {
    enableIPForwarding: true
    networkSecurityGroup: {
      id: nsGId
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: outsideSubnet0id
          }
          publicIPAddress: {
            id: pubIp1Id
          }
          primary: true
          privateIPAllocationMethod: 'Static'
          privateIPAddress: outsideIP0
        }
      }
    ]
  }
}
resource outsidenic1 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${ck8name}-outsidenic1'
  location: resourceGroup().location
  properties: {
    enableIPForwarding: true
    networkSecurityGroup: {
      id: nsGId
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: outsideSubnet1id
          }
          publicIPAddress: {
            id: pubIp2Id
          }
          primary: true
          privateIPAllocationMethod: 'Static'
          privateIPAddress: outsideIP1
        }
      }
    ]
  }
}
resource ck8 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: ck8name
  location: resourceGroup().location
  plan: {
    publisher: 'cisco'
    name: '17_15_01a-byol'
    product: 'cisco-c8000v-byol'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D8as_v5'
    }
    storageProfile: {
      imageReference: {
        publisher: 'cisco'
        offer: 'cisco-c8000v-byol'
        sku: '17_15_01a-byol'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: ck8name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: insidenic.id
          properties: {
            primary: false
          }
        }
        {
          id: outsidenic0.id
          properties: {
            primary: true
          }
        }
        {
          id: outsidenic1.id
          properties: {
            primary: false
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

