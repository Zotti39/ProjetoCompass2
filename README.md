# ProjetoCompass2
Repositorio usado para o segundo projeto do programa de bolsas DevSecOps + AWS da Compass. As especificações da atividade estão no arquivo `Projeto02.pdf` disponivel neste repositorio.

1. [Instalação do Oracle Linux](#linux)
2. [Criação da VPC](#VPC)
3. [EFS do sistema](#EFS)
4. [Criação do RDS](#RDS)
5. [Script data_user.sh](#script)
    -  [Docker](#s1)
    -  [EFS](#s2)
    -  [Docker-Compose](#s3)
    -  [Container WordPress](#s4)
    -  [Observações](#s5)
6. [Criação das Instancias Privadas](#EC2)
7. [Load Balancer](#LB)
8. [Auto Scaling Group](#ASG)
    -  [Launch Template](#ASG1)
    -  [Auto Scaling](#ASG2)
    -  [Stressing ASG](#ASG3)
9. [App Wordpress](#WP)

<div id='linux'/> 

# 1. Instalação do Oracle Linux

### VirtualBox installation
Para este projeto usarei a Versão 7.0.12 do Oracle VirtualBox para windows que pode ser baixada no site oficial https://www.virtualbox.org/wiki/Downloads

### Oracle Linux
Tambem usei uma maquina virtual com sistema Oracle Linux versão 9.3, criada a partir da imagem `OracleLinux-R9-U3-x86_64-dvd.iso` que pode ser encontrada no site https://yum.oracle.com/oracle-linux-isos.html , e utilizando uma unica placa de rede em modo bridge.
	
Durante a instalação da VM configurei para a mesma usar o idioma ingles e não possuir interface grafica (selecionando a opção `Server` no item `Software Selection` no sumario de instalação), e adicionei os seguintes usuarios:

    User: root
    Password: 123456

    User: gabriel
    Password: 123456

Assim está concluida a instalação da maquina virtual que usarei em algumas etapas deste projeto.

<div id='VPC'/> 

# 2. Criação da VPC
Seguindo a arquitetura da aplicação que deve ser criada, é necessario que se tenha uma VPC com duas subnets privadas em diferentes AZs com acesso a internet por meio de um NAT Gateway. 10.0.0.0/16 foi selecionado como IPv4 CIDR (IPv4 address range as a Classless Inter-Domain Routing) block da VPC.

Eu utilizei NAT Gateways pois elas fornecem um caminho para as instâncias presentes na subnet acessarem a internet de forma segura e buscar por atualizações, sem expô-las diretamente à internet, ajudando a reforçar a segurança e o controle sobre o tráfego de rede na aplicação.

Segue na imagem a seguir o esquema da VPC usada:

<img src="https://github.com/Zotti39/ProjetoCompass2/blob/main/Imagens/imagem1.png">

<div id='EFS'/> 

# 3. EFS do sistema

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

<div id='RDS'/> 

# 4. Criação do RDS

Na aba "Create Database", selecionaremos as seguintes opçoes para criar o RDS desejado:

- Standard create
- Engine type:  MySQL
- Engine Version:  8.0.35
- Templates:  Free tier 
- Instance configuration:  db.t3.micro (2vCPUs 1GiB RAM)
- Storage:  gp2 com 20GiB alocados
- Database port: 3306 (Default para MySQL)

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

<div id='script'/> 

# 5. Criação do script data_user.sh

Separei esta seção para explicar com mais detalhes a escrita do script de inicialização das EC2s

<div id='s1'/> 

### 5.1 Docker
A primeira parte, mostra como instalar o plugin docker na instancia e permitir que ele inicie automaticamente quando a mesma é reiniciada. Usei como base a propria documentação da AWS.

    sudo yum update -y
    sudo yum install -y docker
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    sudo systemctl enable docker 

<div id='s2'/> 

### 5.2 EFS
As seguintes linhas tem como objetivo configurar o ambiente para a conexão com o EFS, montar o sistema de arquivos na máquina e, ao passar a ultima linha para o arquivo `/etc/fstab`, fazer com que o EFS se mantenha persistente mesmo após um possivel reboot da instancia.

    sudo yum install amazon-efs-utils -y
    sudo mkdir /efs 
    sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev fs-0e491dfe79b5218d0.efs.us-east-1.amazonaws.com:/ efs
    echo "fs-0e491dfe79b5218d0.efs.us-east-1.amazonaws.com:/     /efs      nfs4      nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev      0      0" >> /etc/fstab

<div id='s3'/> 

### 5.3 Docker-Compose
Para instalar o Docker-compose fiz o download do plugin do repositorio oficial do Docker, nesta versão não há a necessidade de instalar junto o python3.pip que com os comandos anteriormente usados era necessario.

    sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

<div id='s4'/> 

### 5.4 Container WordPress
No passo seguinte, optei por criar o arquivo `Docker-compose.yaml` diretamente dentro da instancia, por ser mais simples e replicavel do que copiar da minha maquina ou baixar do repositorio. A ultima linha executa o arquivo, iniciando a criação do container com a aplicação wordpress

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
          WORDPRESS_DB_HOST: projeto02-rds.cj8e4qgw0xn6.us-east-1.rds.amazonaws.com         ### Endpoint do RDS
          WORDPRESS_DB_USER: admin
          WORDPRESS_DB_PASSWORD: admin123
          WORDPRESS_DB_NAME: Projeto02_DataBase
          WORDPRESS_TABLE_CONFIG: wp_" | sudo tee /home/ec2-user/docker-compose.yaml     
    sudo docker-compose -f /home/ec2-user/docker-compose.yaml up -d

<div id='s5'/> 

### 5.5 Observações
Na primeira versão, o codigo não possuia a linha `WORDPRESS_TABLE_CONFIG: wp_` e o script não estava funcionando corretamente, essa linha específica tem como objetivo definir o prefixo das tabelas usadas pela aplicação Wordpress.

<div id='EC2'/> 

# 6. Criação das Instancias Privadas

Dentro de cada subnet privada existente na VPC, foi criada uma instancia possuindo apenas um IP privado, que só pode ser acessada pelo Load Balancer e, durante a fase de testes, por uma instancia Bastion Host localizada em uma das subnets publicas dentro da mesma VPC.

As instancias foram criadas com as seguintes configurações:

- Nome: Projeto02-Instance1 / Projeto02-Instance2
- AMI: Amazon Linux 2023 AMI (64-bit / x86)
- Instance type: t3.small (2vCPU 2GiB)
- KeyPair: MinhaChaveSSH

Vale tambem ressaltar que foram usadas tags e resource types especificos do programa de bolsas essenciais para a criação destas instancias.

Para construir a instancia utilizei o `data_user.sh` como script de inicialização, que automatiza a:

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

<div id='LB'/> 

# 7. Criação do Load Balancer

O load balancer tem como objetivo distribuir o trafego de rede entre as duas instancias EC2s com a aplicação Wordpress disponiveis, evitando que uma delas fique sobrecarregada em relação a outra.

Para este recurso irei utilizar as seguintes opções em "EC2 > Load balancers > Create LoadBalancer"

- Load balancer type: Classic Load Balancer
- Load balancer name: Projeto02-LoadBalancer
- Scheme: Internet-facing
- Listener: HTTP:80 (checks for connection requests using the protocol and port you configure, determine how the load balancer routes requests to its registered targets.)

Na seção de mapeamento selecionei a VPC do projeto e as duas AZs disponiveis com suas respectivas subnets publicas, permitindo o acesso da internet a aplicação.

Pensando que este recurso deve receber trafego da internet para poder repassar para as instancias, criei um security group com as seguintes rules:

Nome: LoadBalancer-SG
| TYPE  | PROTOCOL | PORT RANGE | SOURCE |
| ----- | ---- | --- | ---------- |
| HTTP  | TCP  | 80  | 0.0.0.0/0  |
| HTTPS | TCP  | 443  | 0.0.0.0/0  |

Em health check mantive as opçoes default, apenas troquei o Ping Path para '/wp-admin/install.php', para funcionar com o wordpress instalado, já que isso faz com que o load balancer use esse esse arquivo para definir se a instancia está "saudavel".
`The health check ping is sent using the protocol and port you specify. If using HTTP/HTTPS protocol, you must also provide the destination path.`

Selecionei as duas instancias previamente configuradas e com o container da aplicação funcionando e está concluida a configuração do Load Balancer.

<div id='ASG'/> 

# 8. Auto Scaling Group

Optei por usar um Launch Template para ASG, devido a recomendação da propria Amazon, que descontinuou o serviço de Launch Configurations em 31 de dezembro de 2023.

<div id='ASG1'/>

### 8.1 Launch Template
Antes de criar o Auto Scaling group, é necessario ter um template das instancias que serão criadas (mesmas do item 6 desta documentação), e pode ser criado em `EC2 > Instances > Launch templates > Create lauch template`. O Launch template criado para este projeto tem as seguintes configurações:

- Name: Projeto02-EC2template
- Auto Scaling guidance: Ativo
- AMI: Amazon Linux 2023 AMI
- Instance type: t3.small (2vCPU 2GiB)
- KeyPair: MinhaChaveSSH
- Subnet: Don't include in launch template
- Security group: instanciasEC2
- Storage: Volume1 (8Gib, EBS, gp3)
- Resource tags: Adicionadas as 2 tags do PB necessarias para criação da EC2
- Advanced details -> User data:  Select `user_data.sh`

<div id='ASG2'/>

### 8.2 Auto Scaling

O Auto Scaling Group nesse projeto tem o objetivo de escalar as EC2s automaticamente para cima ou para baixo, quando há necessidade de mais recursos computacionais, e iniciar novas instâncias substitutas automaticamente quando alguma delas falhar ou for interrompida.

Segue as configurações do ASG:

- Name: Projeto02-ASG
- Launch template: Projeto02-EC2template
- VPC: Projeto02-vpc
- Availability Zones and Subnets: SubnetPrivada1 / SubnetPrivada2
- Load balancing: 
  - Attach to an existing load balancer -> Choose from Classic Load Balancers -> Projeto02-LoadBalancer
- VPC Lattice integration options: No VPC Lattice service
- Health checks: Default
- Additional settings: Default

Para a parte `Configure group size and scaling` que é onde configuramos as capacidades de criar e derrubar instancias do Auto Scaling, teremos as seguintes definições:

- Desired capacity: 2
- Min desired capacity: 2 (O Auto Scaling nunca reduzirá o número de instâncias abaixo desse valor)
- Max desired capacity: 4 (O Auto Scaling não iniciará mais instâncias do que este número, mesmo que a demanda aumente significativamente)
- Automatic scaling: 
  - Target tracking scaling policy
  - Metric type: Average CPU utilization
  - Target value: 80 (Assim que a utilização da cpu alcançar 80%, uma nova instancia será criada)
  - Instance warmup: 300 seconds
- Instance maintenance policy: Mixed behavior / No policy

O Auto Scaling Group pode ser desativado temporariamente selecionando o mesmo na dashbord dos auto scaling groups, clicando em `Actions -> Edit` e mudando, na aba `Group Size`, os tres valores de `Desired capacity` para zero. Quando se deseja "despausar" o ASG basta fazer o mesmo processo e colocar os valores originais.

<div id='ASG3'/>

### 8.3 Stressing ASG

Para testar se o auto scaling group irá criar novas instancias em caso de necessidade, podemos usar o comando `stress` para aumentar artificialmente a utilização de CPU da instancia. Para isso, é necessario acessar uma das instancias privadas disponiveis via SSH, por meio do Bastion Host criado. Após logar na instancia é necessario instalar o pacote stress, utilizando o seguinte comando na CLI:

    sudo yum install stress -y

E em seguida já podemos passar o comando que irá stressar a CPU da EC2:

    stress --cpu 30

Em que a flag `--cpu` define o número de trabalhadores(processos) de CPU que serão criados.

Podemos encerrar esse comando usando `Ctrl + C` ou definir uma tag `--timeout Ns` em que o comando irá rodar por N segundos e encerrará automaticamente.

Apos isso na tela de monitoramento da instancia, no console da AWS, podemos ver que a instancia chegou a mais de 90% de CPU Utilization.

<img src="https://github.com/Zotti39/ProjetoCompass2/blob/main/Imagens/stress1.png">

E em seguida uma nova instancia já começa a ser criada pelo ASG

<img src="https://github.com/Zotti39/ProjetoCompass2/blob/main/Imagens/stress2.png">

E tambem já é automaticamente incluida no Load Balancer

<img src="https://github.com/Zotti39/ProjetoCompass2/blob/main/Imagens/stress3.png">

<div id='WP'/>

# 9. App Wordpress

Ao entrar no endereço do Load Balancer, `Projeto02-LoadBalancer-1250452977.us-east-1.elb.amazonaws.com`, será apresentado a pagina inicial do Wordpress, para escolha do idioma, e a proxima pagina será a de configurações de login, onde inseri os seguintes dados: 

<img src="https://github.com/Zotti39/ProjetoCompass2/blob/main/Imagens/WP1.png">

Apos instalado, podemos acessar novamente o endereço do LoadBalancer e veremos a seguinte pagina, mostrando que a aplicação está funcionando corretamente.

<img src="https://github.com/Zotti39/ProjetoCompass2/blob/main/Imagens/WP2.png">