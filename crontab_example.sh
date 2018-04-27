MAILTO=""
PATH=/mysql/senhas/basedir/bin:/bin:/sbin:/usr/bin:/usr/sbin

## Daily mysqldump Backup
30 23 * * * gbd_run_script.sh gbd_backup_mysql.sh >> /mysql/senhas/logs/mysql_backup_$(date +'\%Y-\%m').log 2>>/mysql/senhas/logs/mysql_backup_$(date +'\%Y-\%m').err

## MySQL replica monitorization
00,15,30,45 * * * * gbd_run_script.sh gbd_monit_repl.sh >> /mysql/senhas/logs/gbd_monit_senhas_$(date -u +'\%Y-\%m').log 2>&1

## Send storage information
07 08 1 * * gbd_run_script.sh gbd_get_storage.sh >> /mysql/senhas/logs/gbd_get_storage_$(date +'\%Y-\%m').log 2>&1

## Check MySQL 5.7 instances logs for errors
*/5 * * * * gbd_run_script.sh tail_n_mail.pl /mysql/senhas/basedir/etc/senhas.config.txt --verbose >> /mysql/senhas/logs/tail_n_mail_mysql_$(date +'\%Y-\%m').log 2>&1

## Hourly flush binary logs and backup
09 * * * * gbd_run_script.sh gbd_backup_binlogs.sh >> /mysql/senhas/logs/mysql_bin_log_backup_$(date +'\%Y-\%m').log 2 >> /mysql/senhas/logs/mysql_bin_log_backup_$(date +'\%Y-\%m').err

