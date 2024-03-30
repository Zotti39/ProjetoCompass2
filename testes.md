### 3. OBS: Tentei criar o EFS como One Zone para poupar custos mas aparentemente eçe so fica acessivel a instancias que estejam na mesma AZ do file system, assim tive que manter a configuração regional.


### Testes do load balancer 29/03/2024:
1. Apos reiniciar as instancias com o script atual, apos alguns segundos fora do ar, elas voltam a funcionar, ou seja, o container com a app wordpress reinicia automaticamente assim que a maquina reiniciar.

2. Com apenas a instancia1 ligada o load balancer continua funcionando corretamente, e ao reiniar a instancia1 e desligar a instancia2, o load balancer tambem continua funcionando.

3. Usando o Oracle Linux VM, conectando-se ao bastion host e em seguida a instancia privada-1, ao executar o comando `docker logs CONTAINER_NAME | tail -n 10` temos acesso aos logs do container que, se tudo estiver correto, irão mostrar as requisiçoes health check vindas do load balancer. E ao acessarmos a url do Load balancer, e observar nos logs que teve acesso de um ip diferente do do load balancer, que seria da maquina que está acessando a url, utilizando o load balancer como mediador.



### Testes ASG 30/03/2024:
1. Estando com as duas instancias desligadas ele automaticamente cria uma em cada subnet e ambas funcionam corretamente entregando a app Wordpress

2. Ao desligar uma das instancias durante o funcionamento, o ASG logo cria uma nova na mesma AZ da anterior. Funcionou corretamente 



# APAGAR
Por padrão o Load Balancer distribui o tráfego de forma equitativa entre as Zonas de Disponibilidade, o que significa que se tivessemos 2 instancias privadas na AZ `us-east-1a` e apenas 1 na AZ `us-east-1b` a divisão de carga seria 25% - 25% - 50%. Mas como isso não se enquadra no nosso caso não há a necessidade de preucupar-se com isso.
# APAGAR