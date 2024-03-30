#!/bin/bash
### 1. Docker
# Instala e configura o Docker 
sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo systemctl enable docker 

### 2. EFS
# Instala dependencias do EFS
sudo yum install amazon-efs-utils -y
sudo mkdir /efs 
# Monta o EFS na instancia, comando encontrado na aba "Attach" do EFS
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-0e491dfe79b5218d0.efs.us-east-1.amazonaws.com:/ efs
# Passa uma linha que mantem o EFS persistente na instancia para dentro do arquivo /etc/fstab
echo "fs-0e491dfe79b5218d0.efs.us-east-1.amazonaws.com:/     /efs      nfs4      nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev      0      0" >> /etc/fstab

### 3. Docker-Compose
# Download Docker-Compose
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
# Corrige as permissões após o download
sudo chmod +x /usr/local/bin/docker-compose

### 4. Containers
# Cria o arquivo docker-compose.yaml com a app Wordpress dentro da instancia EC2
echo "version: '3.8'
services: 
  wordpress:
    image: wordpress
    volumes:
      - /efs/website:/var/www/html
    ports:
      - "80:80"
    restart: always
    environment:
      WORDPRESS_DB_HOST: projeto02-rds.cj8e4qgw0xn6.us-east-1.rds.amazonaws.com 
      WORDPRESS_DB_USER: admin
      WORDPRESS_DB_PASSWORD: admin123
      WORDPRESS_DB_NAME: Projeto02_DataBase
      WORDPRESS_TABLE_CONFIG: wp_" | sudo tee /home/ec2-user/docker-compose.yaml 
# Sobe o container com a app Wordpress
sudo docker-compose -f /home/ec2-user/docker-compose.yaml up -d