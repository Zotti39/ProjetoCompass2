### Testes do load balancer 29/03/2024:
1. Após reiniciar as instancias com o script atual, após alguns segundos fora do ar, elas voltam a funcionar, ou seja, o container com a app wordpress reinicia automaticamente assim que a maquina reiniciar.

2. Com apenas a instancia 1 ligada o load balancer continua funcionando corretamente, e ao reiniar a instancia 1 e desligar a instancia 2, o load balancer tambem continua funcionando.

3. Usando o Oracle Linux VM, conectando-se ao bastion host e em seguida a instancia privada-1, ao executar o comando `docker logs CONTAINER_NAME | tail -n 10` temos acesso aos logs do container que, se tudo estiver correto, irão mostrar as requisições health check vindas do load balancer. Ao acessarmos a url do Load balancer, e observar nos logs que teve acesso de um ip diferente do load balancer, que seria da maquina que está acessando a url, utilizando o load balancer como mediador.


### Testes ASG 30/03/2024:
1. Estando com as duas instancias desligadas ele automaticamente cria uma em cada subnet e ambas funcionam corretamente entregando a app Wordpress.

2. Ao desligar uma das instancias durante o funcionamento, o ASG logo cria uma nova na mesma AZ da anterior. Funcionou corretamente.

### Testei recriar todos os recursos do zero, dia 02/04/2024, tudo funcionou corretamente, com exceção do ASG, onde foi negado o uso do template criado, acredito que seja pelas permissoes da conta.