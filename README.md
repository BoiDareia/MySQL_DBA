# MySQL_DBA
Some random scripts that I use as a DBA admin
Here is the general description of each one.


## install_mysql.sh
This does a general preparation and installation of a MySQL enviroment from the generic Linux binaries already using the latest Oracle CIS standards (as shown in the table below).

1  	Operating  System  Level  Configuration	 
1.1	  Place  Databases  on  Non-¬System  Partitions  (Scored)   	                                      SCRIPT
1.2	  Use  Dedicated  Least  Privileged  Account  for  MySQL Daemon/Service  (Scored) 	                SCRIPT
1.3	  Disable  MySQL  Command  History  (Scored)   	                                                    SCRIPT
1.4	  Verify  that  'MYSQL_PWD'  Is  Not  Set  (Scored)   	                                            POST_INSTALL
1.5	  Disable  Interactive  Login  (Scored)   	                                                        SYSADMIN
 	 	 
2  	Installation  and  Planning	 
2.1	  Dedicate  Machine  Running  MySQL  (Not  Scored)   	                                              SYSADMIN
2.2	  Do  Not  Specify  Passwords  in  Command  Line  (Not  Scored)   	                                POST_INSTALL
2.3	  Do  Not  Reuse  User  Accounts  (Not  Scored)   	                                                POST_INSTALL
2.4	  Do  Not  Use  Default  or  Shared  Cryptographic  Material  (Not Scored) 	                        POST_INSTALL
 	 	 
3  	File  Permissions  and  Ownership	 
3.1	  Ensure  'datadir'  Has  Appropriate  Permissions  and  Ownership (Scored) 	                      SCRIPT
3.2	  Ensure  'log_bin_basename'  Files  Have  Appropriate Permissions  and  Ownership  (Scored) 	      POST_INSTALL
3.3	  Ensure  'log_error'  Has  Appropriate  Permissions  and Ownership  (Scored) 	                    SCRIPT
3.4	  Ensure  'slow_query_log'  Has  Appropriate  Permissions  and Ownership  (Scored) 	                SCRIPT
3.5	  Ensure  'relay_log_basename'  Files  Have  Appropriate Permissions  and  Ownership  (Scored) 	    POST_INSTALL
3.6	  Ensure  'general_log_file'  Has  Appropriate  Permissions  and Ownership  (Scored) 	              SCRIPT
3.7	  Ensure  SSL  Key  Files  Have  Appropriate  Permissions  and Ownership  (Scored) 	                POST_INSTALL
3.8	  Ensure  Plugin  Directory  Has  Appropriate  Permissions  and Ownership  (Scored) 	              POST_INSTALL
3.9	  Ensure  'audit_log_file'  has  Appropriate  Permissions  and Ownership  (Scored) 	                SCRIPT
 	 	 
4  	General	 
4.1	  Ensure  Latest  Security  Patches  Are  Applied  (Not  Scored)   	                                POST_INSTALL
4.2	  Ensure  the  'test'  Database  Is  Not  Installed  (Scored)   	                                  POST_INSTALL
4.3	  Ensure  'allow-¬suspicious-¬udfs'  Is  Set  to  'FALSE'  (Scored)   	                            MY.CNF
4.4	  Ensure  'local_infile'  Is  Disabled  (Scored)   	                                                MY.CNF
4.5	  Ensure  'mysqld'  Is  Not  Started  with  '-¬ -¬skip-¬grant-¬tables' (Scored) 	                  MY.CNF
4.6	  Ensure  '-¬ -¬skip-¬symbolic-¬links'  Is  Enabled  (Scored)   	                                  MY.CNF
4.7	  Ensure  the  'daemon_memcached'  Plugin  Is  Disabled  (Scored)   	                              MY.CNF
4.8	  Ensure  'secure_file_priv'  Is  Not  Empty  (Scored)   	                                          MY.CNF
4.9	  Ensure  'sql_mode'  Contains  'STRICT_ALL_TABLES'  (Scored)   	                                  MY.CNF
 	 	 
5  	MySQL  Permissions	 
5.1	  Ensure  Only  Administrative  Users  Have  Full  Database  Access (Scored) 	                      POST_INSTALL
5.2	  Ensure  'file_priv'  Is  Not  Set  to  'Y'  for  Non-¬Administrative Users  (Scored) 	            POST_INSTALL
5.3	  Ensure  'process_priv'  Is  Not  Set  to  'Y'  for  Non-¬Administrative Users  (Scored) 	        POST_INSTALL
5.4	  Ensure  'super_priv'  Is  Not  Set  to  'Y'  for  Non-¬Administrative Users  (Scored) 	          POST_INSTALL
5.5	  Ensure  'shutdown_priv'  Is  Not  Set  to  'Y'  for  Non-¬Administrative  Users  (Scored) 	      POST_INSTALL
5.6	  Ensure  'create_user_priv'  Is  Not  Set  to  'Y'  for  Non-¬Administrative  Users  (Scored) 	    POST_INSTALL
5.7	  Ensure  'grant_priv'  Is  Not  Set  to  'Y'  for  Non-¬Administrative Users  (Scored) 	          POST_INSTALL
5.8	  Ensure  'repl_slave_priv'  Is  Not  Set  to  'Y'  for  Non-¬Slave  Users (Scored) 	              POST_INSTALL
5.9	  Ensure  DML/DDL  Grants  Are  Limited  to  Specific  Databases and  Users  (Scored) 	            POST_INSTALL
 	 	 
6  	Auditing  and  Logging	 
6.1	  Ensure  'log_error'  Is  Not  Empty  (Scored)   	                                                MY.CNF
6.2	  Ensure  Log  Files  Are  Stored  on  a  Non-¬System  Partition (Scored) 	                        SCRIPT
6.3	  Ensure  'log_warnings'  Is  Set  to  '2'  (Scored)   	                                            MY.CNF
6.4	  Ensure  'log-raw'  Is  Set  to  'OFF'  (Scored)   	                                              MY.CNF
6.5	  Ensure  audit_log_connection_policy  is  not  set  to  'NONE' (Scored) 	                          POST_INSTALL
6.6	  Ensure  audit_log_exclude_accounts  is  set  to  NULL  (Scored)   	                              POST_INSTALL
6.7	  Ensure  audit_log_include_accounts  is  set  to  NULL  (Scored)   	                              POST_INSTALL
6.8	  Ensure  audit_log_policy  is  set  to  log  logins  (Scored)   	                                  POST_INSTALL
6.9	  Ensure  audit_log_policy  is  set  to  log  logins  and  connections (Scored) 	                  POST_INSTALL
6.10	  Ensure  audit_log_statement_policy  is  set  to  ALL  (Scored)   	                              POST_INSTALL
6.11	  Set  audit_log_strategy  to  SYNCHRONOUS  or SEMISYNCRONOUS  (Scored) 	                        POST_INSTALL
6.12	  Make  sure  the  audit  plugin  can't  be  unloaded  (Scored)   	                              POST_INSTALL
 	 	 
7  	Authentication	 
7.1	  Ensure  'old_passwords'  Is  Not  Set  to  '1'  (Scored)   	                                      MY.CNF
7.2	  Ensure  'secure_auth'  is  set  to  'ON'  (Scored)   	                                            MY.CNF
7.3	  Ensure  Passwords  Are  Not  Stored  in  the  Global  Configuration (Scored) 	                    MY.CNF
7.4	  Ensure  'sql_mode'  Contains  'NO_AUTO_CREATE_USER' (Scored) 	                                    MY.CNF
7.5	  Ensure  Passwords  Are  Set  for  All  MySQL  Accounts  (Scored)   	                              POST_INSTALL
7.6	  Ensure  Password  Policy  Is  in  Place  (Scored)   	                                            MY.CNF
7.7	  Ensure  No  Users  Have  Wildcard  Hostnames  (Scored)   	                                        POST_INSTALL
7.8	  Ensure  No  Anonymous  Accounts  Exist  (Scored)   	                                              POST_INSTALL
 	 	 
8  	Network	 
8.1	  Ensure  'have_ssl'  Is  Set  to  'YES'  (Scored)   	                                                   POST_INSTALL
8.2	  Ensure  'ssl_type'  Is  Set  to  'ANY',  'X509',  or  'SPECIFIED'  for  All Remote  Users  (Scored) 	 POST_INSTALL
 	 	 
9  	Replication	 
9.1	  Ensure  Replication  Traffic  Is  Secured  (Not  Scored)   	                                      POST_INSTALL
9.2	  Ensure  'MASTER_SSL_VERIFY_SERVER_CERT'  Is  Set  to  'YES' or  '1'  (Scored) 	                  POST_INSTALL
9.3	  Ensure  'master_info_repository'  Is  Set  to  'TABLE'  (Scored)   	                              MY.CNF
9.4	  Ensure  'super_priv'  Is  Not  Set  to  'Y'  for  Replication  Users (Scored) 	                  POST_INSTALL
9.5	  Ensure  No  Replication  Users  Have  Wildcard  Hostnames (Scored) 	                              POST_INSTALL


## my.cnf.base
This is an example of a my.cnf configuration file with all of the necessary options included (that I use right now), it's used in the above install_mysql.sh as a file to copy to /etc/my.cnf .


## crontab_example.sh
It's just an example of what you need to have in crontab to keep the server "well oiled".


## etc/server_list_mysql.lst
This is a file that has all the major informations from the MySQL instances installed in your server, this one specifically has several examples and is from a server with many instances configured.


## bin/envmysql
It's a centralized place to get all the variables defined so that the other scripts don't have redundant information.


## bin/gbd_monit_repl.sh
A script that monitors replication environment between (for example) a cluster Master and its Slave.


## bin/gbd_run_script.sh
I just use this to validate, within a cluster, whether the FileSystem is mounted or not since our FS changes nodes has an High Availability standard. Used in crontab to check if it should run the jobs or not, depending on if it's the active or passive node.


## bin/my_backup.sh
Basically prepares and does the mysqldump of the instance to a specific fyle system, cleaning up older backups to save space - remenber to backup the backups, always...in this case it is made with another tool (netbackup, rsync, etc)

## bin/my_binlog_backup.sh
As the name suggests, it rotates binary logs and does a generic backup using Netbackup client. But it can be adapted to several other types of backups.

## bin/setmysql
A script that lets you automatically set environment variables according to the instance you choose whithin the same server.

## bin/utilgbd
It adds logging parameters to messages generate by the other scripts.

## work/Migrating_MySQL.sql
An example of a Logical Upgrade (from 5.5.x to 5.7x)
