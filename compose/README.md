# Docker compose deployment

This folder contains instructions to run all services that ecomm app needs.

## Requirements

* [Docker](https://www.docker.com/)
* [Docker compose](https://docs.docker.com/compose/)

## Services

* Redis: running on port 6379
* [Redis client](http://localhost:5540): running on port 5540
* Postgres: running on port 5432
* [gpadmin4](http://localhost:5050): running on port 5050
* Opensearch: running on ports 9200 and 9600
* [OpenSearch Dashboard](http://localhost:5601): running on port 5601
* Localstack: running on ports 4566 and 4571
* Zookeper: running on ports 32181, 2888 and 3888
* Kafka node1: running on port 9091 
* Kafka node2: running on port 9092
* Kafka node3: running on port 9093
* [Kafka UI](http://localhost:9100): running on port 9100
* [Zipkin](http://localhost:9411): running on port 9411
* [Jaeger](http://localhost:16686): running on port 4318 and 16686
* [Prometheus](http://localhost:10000): running on port 10000
* postgresql-exporter: running on port 9187
* [Grafana](http://localhost:3000): running on port 3000

**Notes**:* Postgres databases (users, products and orders) are filled using flyway scripts which are located on the folders which are defined by the environment variables `ECOMM_USERS_MODEL_SQL`, `ECOMM_PRODUCTS_MODEL_SQL` and `ECOMM_ORDERS_MODEL_SQL`.
In case of those variables are not defined, relative paths from current folder will be used.

**Notes**:** Grafana has prometheus datasource configured by default. If you want to create dashboards you can import `grafana_dashboard_postgres.json` to see postgres metrics (because postgres exporter us running) and you can import `grafana_dashboard_spring_apps.json` to see Spring Boot App metrics.  

## Run

```shell
docker compose up
```

When all services are running, you can start up each Spring Boot app which will connect to those services.

### Postgres external access

If you want that postgres accepts connections from outside localhost (e.g. inside docker), you must edit:
```shell
sudo nano .data/postgres_data/pg_hba.conf
```
and add the line:
```text
host    all             all             172.19.0.1/8            trust
```
where 172.19.0.1 is the network interface where docker or the other app is running. 

postgres pg_hba.conf file will look.
```text
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     trust
# IPv4 local connections:
host    all             all             127.0.0.1/32            trust
host    all             all             172.19.0.1/8            trust
# IPv6 local connections:
host    all             all             ::1/128                 trust
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     trust
host    replication     all             127.0.0.1/32            trust
host    replication     all             ::1/128                 trust
```