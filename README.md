# ProjetoCompass2
Repositorio para o segundo projeto do programa de bolsas DevSecOps + AWS da Compass

# Instalação do Oracle Linux

### VirtualBox instalation
Para este projeto usarei a Versão 7.0.12 do Oracle VirtualBox para windows que pode ser baixada no site oficial https://www.virtualbox.org/wiki/Downloads

### Oracle Linux
Tambem usei uma maquina virtual com sistema Oracle Linux versão 9.3, criada a partir da imagem `OracleLinux-R9-U3-x86_64-dvd.iso` que pode ser encontrada no site https://yum.oracle.com/oracle-linux-isos.html , e utilizando uma unica placa de rede em modo bridge.
	
Durante a instalação da VM configurei para a mesma usar o idioma ingles e não possuir interface grafica (selecionando a opção 'Server' no item 'Software Selection' no sumario da instalação), e as informaçoes do usuario root são `password = 123456` e possui um usuario `gabriel` com a mesma senha.

Assim está concluida a instalação da virtual machine que usarei nas etapas seguintes.

# Criação do arquivo `user_data.sh`
Este arquivo é usado para automatizar a configuração das EC2s que irei criar para o projeto, seu objetivo é instalar e configurar todo o sistema Docker assim que a instancia for iniciada, e foi escrito com base na documentação presente no site oficial da AWS.

# Criação do ambiente na AWS
Seguindo a arquitetura da aplicação que deve ser criada, é necessario que se tenha uma VPC com duas subnets privadas em diferentes AZs com acesso a internet por meio de um NAT Gateway.

Segue na imagem a seguir o esquema da vpc usada
<imagem1>

### As NAT Gateways foram apagadas durante a construção do projeto, pensando em reduzir os custos totais, e foram criadas novamente todas as vezes que trabalhava no projeto

## Security Groups

Para o load balancer, pensando que este deve receebr trafego da internet para poder repassar para as instancias, criei um security group que recebe acesso via HTTP E HTTPS

Nome: LoadBalancer-SG
| TYPE  | PROTOCOL | PORT RANGE | SOURCE |
| ----- | ---- | --- | ---------- |
| HTTP  | TCP  | 80  | 0.0.0.0/0  |
| HTTPS | TCP  | 443  | 0.0.0.0/0  |

Para as instancias ec2, que so devem receber trafego vindo do Load Balancer, configurei as seguintes regras no security group:

Nome: instanciasEC2
| TYPE  | PROTOCOL | PORT RANGE | SOURCE |
| ----- | ---- | --- | ---------- |
| HTTP  | TCP  | 80  | LoadBalancer-SG |
| HTTPS | TCP  | 443  | LoadBalancer-SG |		

Para o RDS establecerei um security group que permite o trafego de entrada vindo das instancias ec2 privadas:

Nome: RDS-SG
| TYPE  | PROTOCOL | PORT RANGE | SOURCE |
| ----- | ---- | --- | ---------- |
| MYSQL/AURORA  | TCP  | 3306  | instanciasEC2 |
