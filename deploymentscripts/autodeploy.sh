export RESOURCE_GROUP=$(az group list --query "[0].name" -o tsv)
git clone https://github.com/phya-williams/cloudtopia-4
cd cloudtopia-4
chmod +x deploy.sh
./deploy.sh
