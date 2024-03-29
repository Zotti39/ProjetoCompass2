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

# Instalar o Docker Compose 2.0
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Estranhamente sem esse pip3 o docker-compose não funciona, descobri por acaso dia 28/03 as 21:30, não esta em nenhuma documentação que encontrei
sudo yum install python3-pip -y

# Agora criamos o arquivo docker-compose.yaml dentro da instancia ec2
# Usei um tutorial como base para criar esse arquivo, disponivel em "https://www.alphabold.com/deploy-dockerized-wordpress-with-aws-rds-aws-efs/"
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

# E finalmente subimos o container com a app Wordpress
sudo docker-compose -f /home/ec2-user/docker-compose.yaml up -d