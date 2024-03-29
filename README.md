# ProjetoCompass2
Repositorio para o segundo projeto do programa de bolsas DevSecOps + AWS da Compass

# 1. Instalação do Oracle Linux

### VirtualBox instalation
Para este projeto usarei a Versão 7.0.12 do Oracle VirtualBox para windows que pode ser baixada no site oficial https://www.virtualbox.org/wiki/Downloads

### Oracle Linux
Tambem usei uma maquina virtual com sistema Oracle Linux versão 9.3, criada a partir da imagem `OracleLinux-R9-U3-x86_64-dvd.iso` que pode ser encontrada no site https://yum.oracle.com/oracle-linux-isos.html , e utilizando uma unica placa de rede em modo bridge.
	
Durante a instalação da VM configurei para a mesma usar o idioma ingles e não possuir interface grafica (selecionando a opção `Server` no item `Software Selection` no sumario da instalação), e adicionei os seguintes users:

    Usuario: root
    Password: 123456

    Usuario: gabriel
    Password: 123456

Assim está concluida a instalação da virtual machine que usarei em algumas etapas deste projeto

# 2. Criação do ambiente na AWS
Seguindo a arquitetura da aplicação que deve ser criada, é necessario que se tenha uma VPC com duas subnets privadas em diferentes AZs com acesso a internet por meio de um NAT Gateway.

Segue na imagem a seguir o esquema da vpc usada

<img src="https://github.com/Zotti39/ProjetoCompass2/blob/main/Imagens/imagem1.png">

# 3. EFS do sistema
### Usei como guia o tutorial disponivel em: https://www.alphabold.com/deploy-dockerized-wordpress-with-aws-rds-aws-efs/

Para armazenar os estáticos do container de aplicação Wordpress utilizei um Elastic File System (EFS) da AWS, que poderá ser acessado por todas as instancias EC2. Seu processo de configuração e montagem será feito por meio do script de inicialização `user_data.sh`. 

Mantive todas as opçoes default na criação deste recurso:
- Name : Projeto02-EFS
- VPC : Projeto02-VPC
- File system type : Regional
- Throughput mode : Enhanced/Elastic
- Performance mode : General Purpose

Para garantir que apenas as instancias EC2 tenham acesso ao NFS criaremos um security group para o EFS com as seguintes regras de acesso:

Nome: EFS-SG
| TYPE  | PROTOCOL | PORT RANGE | SOURCE |
| ----- | ---- | --- | ---------- |
| NFS  | TCP  | 2049  | instanciasEC2 |

Podemos conferir se o EFS foi devidamente montado na instancia quando a acessamos e passamos o comando `df -h` no terminal, devemos encontrar um resultado como o seguinte:

<img src="https://github.com/Zotti39/ProjetoCompass2/blob/main/Imagens/df-h(2).png">

### OBS: Tentei criar o EFS como One Zone para poupar custos mas aparentemente eçe so fica acessivel a instancias que estejam na mesma AZ do file system, assim tive que manter a configuração regional.

# 4. Criação do RDS
### De acordo com a documentação disponivel em: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_CreateDBInstance.html

Na aba "Create Database", selecionaremos as seguintes opçoes para criar o RDS desejado:

- Standard create
- Engine type:  MySQL
- Engine Version:  8.0.35
- Templates:  Free tier 
- Instance configuration:  db.t3.micro (2vCPUs 1GiB RAM)
- Storage:  gp2 com 20GiB alocados

E os dados personalizados :

- DB instance identifier:  Projeto02-RDS
- Master username:  admin
- Master password:  admin123
- Aditional configuration -> Initial database name:  Projeto02_DataBase
- Availability Zone:  No preference

Em Connectivity, mantive a opção `Don’t connect to an EC2 compute resource` pois as EC2s ainda não foram criadas. Selecionei a VPC e subnets do projeto, mantive o acesso publico desativado, tendo em vista que apenas recursos dentro da VPC devem ter acesso ao RDS. 

Considerando que apenas as EC2s devem ter acesso ao banco de dados, configurei o seguinte security group para o RDS: 

Nome: RDS-SG
| TYPE  | PROTOCOL | PORT RANGE | SOURCE |
| ----- | ---- | --- | ---------- |
| MYSQL/AURORA  | TCP  | 3306  | instanciasEC2 |

# 5. Criação do script data_user.sh

Separei esta seção para explicar com mais detalhes a escrita do script de inicialização das EC2s

A primeira parte, mostra como instalar o plugin docker na instancia, e usa como base a propria documentação da AWS, disponivel em: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-docker.html#install-docker-instructions

    sudo yum update -y
    sudo yum install -y docker
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    sudo systemctl enable docker 

As seguintes linhas de codigo tem como objetivo configurar o ambiente para a conexão com o EFS, montar o sistema de arquivos na máquina e, ao passar a ultima linha para o arquivo `/etc/fstab`, fazer com que o EFS se mantenha persistente mesmo após um possivel reboot da instancia. Para isso usei como base a documentação disponivel em: https://docs.aws.amazon.com/efs/latest/ug/nfs-automount-efs.html

    sudo yum install amazon-efs-utils -y
    sudo mkdir /efs 
    sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev fs-0e491dfe79b5218d0.efs.us-east-1.amazonaws.com:/ efs
    echo "fs-0e491dfe79b5218d0.efs.us-east-1.amazonaws.com:/     /efs      nfs4      nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev      0      0" >> /etc/fstab

Para instalar o Docker-compose, como não encontrei nenhuma documetação oficial da amazon sobre a instalação em sistemas Amazon Linux 2023, utilizei como base um guia disponivel em https://medium.com/@fredmanre/how-to-configure-docker-docker-compose-in-aws-ec2-amazon-linux-2023-ami-ab4d10b2bcdc, metodo tambem utilizado pelo professor Leandro no primeiro curso de docker do PB, e funcionou corretamente, agora sem a necessidade de instalar junto o python3.pip que com os comandos anteriormente usados era necessario.

    sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

No passo seguinte, optei por criar o arquivo `Docker-compose.yaml` diretamente dentro da instancia, por ser mais simples e replicavel do que copiar da minha maquina ou baixar do repositorio. E a ultima linha executa o arquivo, iniciando a criação do container com a aplicação wordpress

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
    sudo docker-compose -f /home/ec2-user/docker-compose.yaml up -d

Na primeira versão, o codigo não possuia a linha `WORDPRESS_TABLE_CONFIG: wp_` e o script não estava funcionando corretamente, encontrei uma solução no site https://www.alphabold.com/deploy-dockerized-wordpress-with-aws-rds-aws-efs/, a linha especifica tem como objetivo definir o prefixo das tabelas usadas pela aplicação Wordpress, e como as duas instancias possuem a mesma aplicação, não irá gerar conflito entre as tabelas, já que elas serão as mesmas.

# 6. Criação das Instancias Privadas

Dentro de cada subnet privada existente na VPC, foi criada uma instancia possuindo apenas um IP privado, que só podera ser acessada pelo Load Balancer e, durante a fase de testes por uma instancia Bastion Host localizada na subnet publica dentro da mesma VPC.

Para construir a instancia utilizei o `data_user.sh` como script de inicialização, que automatiza a :

-  Instalação do Docker
-  Instalação do Docker-compose
-  Montagem do EFS na instancia
-  Cria um documento docker-compose.yaml com as configuraçoes da aplicação Wordpress conteinerizada
-  Sobe o container contendo a aplicação Wordpress

Considerando que as EC2s precisam receber tráfego do Load Balancer e, durante os testes, de IPs dentro da mesma VPC para permitir acesso via Bastion Host às instâncias, criei um security group com as seguintes rules:

Nome: instanciasEC2
| TYPE  | PROTOCOL | PORT RANGE | SOURCE |
| ----- | ---- | --- | ---------- |
| HTTP  | TCP  | 80  | LoadBalancer-SG |
| HTTPS | TCP  | 443  | LoadBalancer-SG |		
| SSH | TCP  | 22  | 10.0.0.0/16 |

# 7. Criação do Load Balancer
### De acordo com a documentação disponivel em: https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-getting-started.html

O load balancer tem como objetivo distribuir o trafego de rede entre as duas instancias EC2s com a aplicação Wordpress disponiveis, evitando que uma delas fique sobrecarregada em relação a outra.

Por padrão o Load Balancer distribui o tráfego de forma equitativa entre as Zonas de Disponibilidade, o que significa que se tivessemos 2 instancias privadas na AZ `us-east-1a` e apenas 1 na AZ `us-east-1b` a divisão de carga seria 25% - 25% - 50%. Mas como isso não se enquadra no nosso caso não há a necessidade de preucupar-se com isso.

Para este recurso irei utilizar as seguintes opções em "Create LoadBalancer"

- Load balancer type: Classic Load Balancer
- Load balancer name: Projeto02-LoadBalancer
- Scheme: Internet-facing
- Listener: HTTP:80 (checks for connection requests using the protocol and port you configure,determine how the load balancer routes requests to its registered targets.)

Na seção de mapeamento selecionei a VPC do projeto e as duas AZs disponiveis com suas respectivas subnets publicas, permitindo o acesso da internet a aplicação.

Pensando que este recurso deve receber trafego da internet para poder repassar para as instancias, criei um security group com as seguintes rules:

Nome: LoadBalancer-SG
| TYPE  | PROTOCOL | PORT RANGE | SOURCE |
| ----- | ---- | --- | ---------- |
| HTTP  | TCP  | 80  | 0.0.0.0/0  |
| HTTPS | TCP  | 443  | 0.0.0.0/0  |

Em health check mantive as opçoes default, apenas troquei o Ping Path para '/wp-admin/install.php', para funiconar com o wordpress instalado, já que isso faz com que o load balancer use esse esse arquivo para definir se a instancia está "saudavel".

Selecionei as duas instancias previamente configuradas e com o container da aplicação funcionando e está concluida a configuração do Load Balancer.

### Testes do load balancer 29/03/2024:
1. Apos reiniciar as instancias com o script atual, apos alguns segundos fora do ar, elas voltam a funcionar, ou seja, o container com a app wordpress reinicia automaticamente assim que a maquina reiniciar.

2. Com apenas a instancia1 ligada o load balancer continua funcionando corretamente, e ao reiniar a instancia1 e desligar a instancia2, o load balancer tambem continua funcionando.

# 8. 