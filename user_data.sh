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


