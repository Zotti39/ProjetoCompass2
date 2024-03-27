#!/bin/bash

# Este script serve para instalar o docker e suas dependencias em uma instancia Amazon Linux 2023 na data de 26/03/2024 de acordo com a documentação oficial da AWS
# Parte presente na documentação oficial:
sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user

# Fora da documentação oficial:
# Inicia o docker automaticamente
sudo systemctl enable docker 

# Configurar o EFS
sudo yum install amazon-efs-utils -y
sudo mkdir /efs 
# O seguinte comando é encontrado na aba "attach" na pagina do EFS
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-0e491dfe79b5218d0.efs.us-east-1.amazonaws.com:/ efs
# Agora com o objetivo de tornar o efs persistente nas instancias, passaremos o seguinte comando, com objetivo de adicionar a linha dentro de echo para o arquivo fstab, que permitirá a montagem automatica do efs toda vez que rebootar a maquina
echo "fs-0e491dfe79b5218d0.efs.us-east-1.amazonaws.com:/     /efs      nfs4      nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev      0      0" >> /etc/fstab


