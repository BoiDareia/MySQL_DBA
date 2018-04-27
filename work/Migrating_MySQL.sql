Export:

---- Efectuar os dumps na maquina

-- Schema sem triggers
$ mysqldump --single-transaction --flush-logs --databases db1 db2 db3 --no-data --add-drop-database --skip-triggers --opt --routines --events -p > backup_databases_dml.sql

-- Triggers apenas
$ mysqldump --single-transaction --flush-logs --databases bdp db1 db2 db3 --no-data --no-create-info --no-create-db --no-tablespaces --triggers -p > backup_triggers_dml.trg

-- Data
$ mysqldump --single-transaction --flush-logs --databases db1 db2 db3 --no-create-info --no-create-db --no-tablespaces --skip-triggers --disable-keys -p | bzip2 > backup_data.dmp.bz2

-- Tirar users
$ mysql -B -N -uroot -e "SELECT CONCAT('\'', user,'\'@\'', host, '\'') FROM user WHERE user != 'debian-sys-maint' AND user != 'root' AND user != ''" mysql > mysql_all_users.txt

-- Criar SQL 
while read line; do mysql -B -N -uroot -e "SHOW GRANTS FOR $line"; done < mysql_all_users.txt > mysql_all_users_sql.sql


-- Alterar DEFINERS, para utilizadores que existam no motor, no dump do schema e passar para maquina nova

$ mysql

$ select user, host from mysql.user;

| 101.18.00.5   | user-ro     |
| 101.18.00.6   | user-admin  |
| 101.18.00.6   | user-ro     |
| 101.18.00.6   | user-rw     |
| 101.18.00.68  | user-ro     |
| 101.18.00.68  | user-rw     |
| 101.18.00.69  | user-ro     |
| 101.18.00.69  | user-rw     |
| 101.18.00.7   | user-admin  |
| 101.18.00.7   | user-ro     |
| 101.18.0.7    | user-rw     |

-- Verificar os processos na maquina destino e pará-los metendo o bind-address=127.0.0.1 no /etc/my.cnf e reeniciando o servidor

$ mysql

$ show processlist;

$ show variables like '%bind%'; -- (para ver se o bind-address está apenas para o que definimos)

$ mysqladmin shutdown -- (existe um script automático que volta a colocar a instância em cima)

$ mysql

$ show processlist; -- (para verificar que apenas existe a ligação presente)

-- Correr import do schema

$ mysql --init-command="SET SESSION sql_log_bin=0;" < backup_databases_dml.sql

--Correr import dos users

$ mysql < mysql_all_users_sql.sql

-- Correr import da data

$ bunzip2 < backup_data.dmp.bz2 | mysql --init-command="SET SESSION sql_log_bin=0;"

-- Correr import dos triggers

$ mysql --init-command="SET SESSION sql_log_bin=0;" < backup_triggers_dml.trg

-- Efectuar upgrade aos dados (foi necessário o --force para que ele corresse mesmo não trazendo as BD's de sistema no dump.)

$ mysql_upgrade --verbose --force 
