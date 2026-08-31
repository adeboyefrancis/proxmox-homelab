## Creating Golden Image for Azure and Managing via HCP Registry

### Create Resource Group

```bash
AZ_RG=$(az group create --name "HCP-Builder-RG" --location centralus --query name --output tsv)
```

### Create Service Principal for Packer

```bash
AZ_SUB_ID=$(az account show --query id --output tsv)
az ad sp create-for-rbac --name "Packer-Builder" --role Contributor --scopes "/subscriptions/${AZ_SUB_ID}"
```

### Create Shared Image Gallery

```bash
az sig create --resource-group $AZ_RG --gallery-name "Packergoldenartifact2026"
```

### Create Image Definition

```bash
SIG_NAME="Packergoldenartifact2026"

az sig image-definition create \
  --resource-group $AZ_RG \
  --gallery-name $SIG_NAME \
  --gallery-image-definition ubuntu-server \
  --publisher CompanyImages \
  --offer UbuntuServer \
  --sku 22.04-hardened \
  --os-type Linux \
  --os-state Generalized \
  --hyper-v-generation V2
```

### Create a temporary resource group for Packer builds

```bash
TEMP_AZ_RG=$(az group create --name "TMP-HCP-Builder-RG" --location centralus --query name --output tsv)
```

### Create Packer Template
