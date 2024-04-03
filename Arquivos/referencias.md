### Arquivo utilizado para salvar os links que encontrei informaçoes uteis para o desenvolvimento do projeto

## 3. EFS do sistema
### Usei como guia o tutorial disponivel em: https://www.alphabold.com/deploy-dockerized-wordpress-with-aws-rds-aws-efs/

## 4. Criação do RDS
### De acordo com a documentação disponivel em: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_CreateDBInstance.html

## 5. Criação do script data_user.sh
### 5.1 usa como base a propria documentação da AWS, disponivel em: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-docker.html#install-docker-instructions

### 5.2 Usei como base a documentação disponivel em: https://docs.aws.amazon.com/efs/latest/ug/nfs-automount-efs.html

### 5.3 Para instalar o Docker-compose, como não encontrei nenhuma documentação oficial da amazon sobre a instalação em sistemas Amazon Linux 2023, utilizei como base um guia disponivel em https://medium.com/@fredmanre/how-to-configure-docker-docker-compose-in-aws-ec2-amazon-linux-2023-ami-ab4d10b2bcdc, metodo tambem utilizado pelo professor Leandro no primeiro curso de docker do PB, e funcionou corretamente, agora sem a necessidade de instalar junto o python3.pip que com os comandos anteriormente usados era necessario.

### 5.5 Na primeira versão, o codigo não possuia a linha `WORDPRESS_TABLE_CONFIG: wp_` e o script não estava funcionando corretamente, encontrei uma solução no site https://www.alphabold.com/deploy-dockerized-wordpress-with-aws-rds-aws-efs/, a linha especifica tem como objetivo definir o prefixo das tabelas usadas pela aplicação Wordpress, e como as duas instancias possuem a mesma aplicação, não irá gerar conflito entre as tabelas, já que elas serão as mesmas.

## 7. Criação do Load Balancer
### De acordo com a documentação disponivel em: https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-getting-started.html

## 8. Auto Scaling
### `Recomendamos que você use Launch Template para garantir que esteja acessando os recursos e melhorias mais recentes. Nem todos os recursos do Amazon EC2 Auto Scaling estão disponíveis quando você usa Launch Configurations.`
### Fonte: https://docs.aws.amazon.com/pt_br/autoscaling/ec2/userguide/launch-templates.html

### 8.3 Stressing ASG
### Usei como guia o tutorial disponivel em: https://towardsaws.com/stress-testing-an-auto-scaling-group-policy-in-aws-23e450211894