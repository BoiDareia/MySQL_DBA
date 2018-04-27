#!/usr/bin/bash
#set -x

# Version: 1.2 - by SAG
# Version: 1.3 - Luis Marques - 20170802
# - Deixar de redirecionar STDOUT dentro do script
# - criar funcoes para adicionar timestamp e PID a mensagens
# - adicionados testes ao exit status de varios comandos
# Version: 1.4 - Luis Marques - 20171122
# - Adicionar mais informacao nas mensagens de log
# - Adicionar "lock" para evitar multiplas execucoes ao mesmo tempo
# - Modificado o envio de mail para sendmail
# - Corrigida verificacao do tamanho do ficheiro final, para ser sempre em MiB
# - Adiconada verificacao de tamanho minimo do ficheiro final
# Version: 1.5 - Luis Marques - 20180220
# - Reorganizacao do codigo para lidar melhor com erros
# - Modificacao do que eh escrito para output (log)
#
# Necessário alterar S_BACKUP_DIR, S_MYSQLBASE_DIR, S_INSTANCE_NAME,
# S_MYSQL_AUTH_OPTION
# conforme a máquina/ambiente
#
# Efetua o backup da instancia mysql utilizando o mysqldump.
# O backup eh colocado numa pasta com indicacao do dia.
# O ficheiro resultante eh comprimido com o bzip2.
# Os ficheiros comprimidos com mais de X dias sao eliminados.
# Utiliza um ficheiro de log para registar erros que ocorram e no final
# envia aviso se esse ficheiro tiver alguma mensagem. Este ficheiro
# nao eh eliminado se tiver conteudo.
#
# A entrada no crontab devera redirecionar o STDOUT e STDERR para os
# respetivos ficheiros:
# XX XX * * * /home/mysql/bin/my_backup.sh >> /mysql/basedir/trace/mysql_backup.log 2>>/mysql/basedir/trace/mysql_backup.write_err
#

## Efetuar source das funcoes shell utilitarias
. /mysql/basedir/bin/utilgdb

export LANG=pt_PT

#---------------------------------------------------------------------------
#### MUDAR AS PATHS DE ACORDO COM A MAQUINA/AMBIENTE                    ####
S_MYSQLBASE_DIR="/mysql/basedir/5.7.20"
S_BACKUP_DIR="/mysql/backups"
S_DAYS_TO_KEEP=4
S_BACKUP_MINIMUM_COMPRESSED_SIZE_KIB=1
S_INSTANCE_NAME='INSTANCIA'
S_MYSQL_AUTH_OPTION="--login-path=bck"

S_MYSQL_FROM="DBA MYSQL PTP <dba-mysql-ptp@telecom.pt>"
S_MYSQL_TO="dba-mysql-ptp@telecom.pt"

#---------------------------------------------------------------------------
S_DAY_YYYYMMDD=$(date -u +'%Y%m%d')
S_VAR_DATETIME=$(date -u +'%Y%m%dT%H%M%s')
S_MYSQL_HOST=$(hostname -s)
S_PROGNAME="${0##*/}"
S_BACKUP_DIR_TODAY_NAME="${S_BACKUP_DIR}/${S_DAY_YYYYMMDD}"
S_ERROR_MSG_FILE="${S_BACKUP_DIR}/backup_${S_INSTANCE_NAME}_${S_VAR_DATETIME}.err"


#### Variaveis para verificar se o script ja se encontra a executar
S_LOCK_DIR_NAME="/tmp/mysql_${S_PROGNAME%%.*}_${S_INSTANCE_NAME}_backup_lock"
L_LOCK_SET_THIS_RUN=0

####  Variavel que guarda o exit code que o script vai devolver
L_EXIT_STATUS_CODE=0


#---------------------------------------------------------------------------
# Function: envia_mail
# Envia email em caso de erro/erros durante a execucao do script
#---------------------------------------------------------------------------
envia_mail()
{
    sendmail -t << EOF!
FROM: ${S_MYSQL_FROM}
TO: ${S_MYSQL_TO}
SUBJECT: ERRO - Backup MySQL falhou ${S_MYSQL_HOST}

This is an automatic generated mail created by the
$0 script at host ${S_MYSQL_HOST}
------------------------------------------------------------------

Erro no backup.

DATE: ${S_DAY_YYYYMMDD}

$(cat ${S_ERROR_MSG_FILE})

------------------------------------------------------------------
.
EOF!

}

#---------------------------------------------------------------------------
# Function: write_out
# Adiciona campos de logging ah mensagem: 
# timestamp hostname PID aplicacao tarefa nome_instancia : mensagem 
# 
# Argumentos:
# $1 - tipo de mensagem (ERROR|WARNING|INFO|FATAL|CRITICAL|DEBUG)
# $2 - mensagem
# 
#---------------------------------------------------------------------------
write_out()
{
    gbd_write_out "${S_HOSTNAME}" \
        "${S_INSTANCE_NAME}" \
        "mysql" \
        "${S_PROGNAME}" \
        "$1" \
        "$2"
}

#-------------------------------------------------------------------------
# Function: script_cleanup
# Efetua a remocao da diretoria de lock
#
#-------------------------------------------------------------------------
function script_cleanup
{
    ## Limpar diretoria de lock
    gbd_cleanup_lock "${S_LOCK_DIR_NAME}" ${L_LOCK_SET_THIS_RUN} 
    write_out "INFO" "Fim da execucao do script [${S_PROGNAME}]."
    exit ${L_EXIT_STATUS_CODE}
}

#-------------------------------------------------------------------------
# Corpo principal do script
#-------------------------------------------------------------------------


## Indicar inicio da execucao
write_out "INFO" "Inicio da execucao do script [${S_PROGNAME}]."
trap script_cleanup EXIT

## Usar um ciclo for que executa apenas 1 vez para no final verificar
## se eh necessario enviar alerta. O ciclo permite o uso de "break" 
## para parar execucao e enviar alerta.
for thisexecution in runonetime; do
    
    ## Mudar mascara dos ficheiros para novos ficheiros nao terem permissoes
    ## para group e others
    umask 0027
    if [ $? -ne 0 ]; then
        write_out "ERROR" "Nao foi possivel mudar a mascara para 0027." | tee -a "${S_ERROR_MSG_FILE}"
        L_EXIT_STATUS_CODE=101
        break
    fi

    # Usar mkdir para testar se existe alguma execucao anterior do script.
    # mkdir eh uma operacao "atomica", 2 scripts a executar ao "mesmo" tempo,
    # apenas 1 deles vai conseguir criar a diretoria.
    if ! mkdir "${S_LOCK_DIR_NAME}" 2>/dev/null; then
        # Diretoria de lock ja existe. Escrever mensagem e sair.
        write_out "WARNING" "Diretoria de lock [${S_LOCK_DIR_NAME}] ja existe." | tee -a "${S_ERROR_MSG_FILE}"
        L_EXIT_STATUS_CODE=101
        break
    else
        # Foi criada a diretoria de lock, colocar a variavel de controlo a 1
        # para que a funcao de cleanup remova a diretoria no fim.
        L_LOCK_SET_THIS_RUN=1
    fi
    
    #########################################################################
    ## ACTIONS BLOCK START
    #########################################################################

    # Verificar e criar pasta de destino para os ficheiros de backup
    if [ ! -d "${S_BACKUP_DIR_TODAY_NAME}" ]; then
        write_out "INFO" "A criar pasta [${S_BACKUP_DIR_TODAY_NAME}]."
        mkdir ${S_BACKUP_DIR_TODAY_NAME} 2>> "${S_ERROR_MSG_FILE}"
        ## Testar exit status
        if [ $? -ne 0 ]; then
            write_out "ERROR" "Erro ao tentar criar diretoria [${S_BACKUP_DIR_TODAY_NAME}]." | tee -a "${S_ERROR_MSG_FILE}"
            L_EXIT_STATUS_CODE=101
            break
        fi
    else
        write_out "WARNING" "Diretoria [${S_BACKUP_DIR_TODAY_NAME}] ja existe."
    fi

    # Ir buscar o tamanho em MB ocupado na instancia mysql.
    # Usar um HERE DOCUMENT para tornar a query mais percetivel
    L_DB_MYSQL_SIZE=$(${S_MYSQLBASE_DIR}/bin/mysql ${S_MYSQL_AUTH_OPTION} -s -s << EOF!
SELECT
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 1)
FROM
    information_schema.tables;
EOF!
    )
    # Verificar exit status
    if [ $? -ne 0 ]; then
        # Houve um erro na execucao da query, escrever mensagem
        write_out "WARNING" "Erro a ir buscar o volume de dados de origem." | tee -a "${S_ERROR_MSG_FILE}"
    else
        write_out "INFO" "Volume de dados de origem do MySQL: [${L_DB_MYSQL_SIZE} MiB]."
    fi

    write_out "INFO" "A efectuar limpeza de backups antigos."
    if [ -z "${S_BACKUP_DIR}" ]; then
        # Path dado esta vazio, abortar
        write_out "ERROR" "O path dado esta vazio." | tee -a "${S_ERROR_MSG_FILE}"
        L_EXIT_STATUS_CODE=101
        break
    fi
    
    if [ ! -d "${S_BACKUP_DIR}" ]; then
        # Path dado nao eh uma diretoria
        write_out "ERROR" "O path dado nao eh uma diretoria [${S_BACKUP_DIR}]" | tee -a "${S_ERROR_MSG_FILE}"
        L_EXIT_STATUS_CODE=101
        break
    fi
    
    # Guardar diretoria currente
    L_PREVIOUS_PWD="$(pwd)"

    # Mudar para a diretoria base
    cd "${S_BACKUP_DIR}"
    if [ $? -ne 0 ]; then
        write_out "ERROR" "Falhou a mudanca para a diretoria [${S_BACKUP_DIR}]." | tee -a "${S_ERROR_MSG_FILE}"
        L_EXIT_STATUS_CODE=102
        break
    else
        write_out "INFO" "Pasta base para remover ficheiros [${S_BACKUP_DIR}]."
    fi
    # Limpar backups com mais de S_DAYS_TO_KEEP dias
    # Criar lista de backups a apagar para escrever nas mensagens do log
    # Procura por pastas com o nome YYYYMMDD ('20[0-9][0-9][0-1][0-9][0-3][0-9]')
    find . -depth -maxdepth 1 -mindepth 1 -name '20[0-9][0-9][0-1][0-9][0-3][0-9]' -type d -mtime +${S_DAYS_TO_KEEP} -ls > "${S_LOCK_DIR_NAME}/lista_backups_apagar.lst"
    while read VAR_LINE; do
        write_out "INFO" "Backup antigo encontrado: [${VAR_LINE}]."
    done <"${S_LOCK_DIR_NAME}/lista_backups_apagar.lst"

    # Remover os backups encontrados .
    find . -depth -maxdepth 1 -mindepth 1 -name '20[0-9][0-9][0-1][0-9][0-3][0-9]' -type d -mtime +${S_DAYS_TO_KEEP} -exec rm -r '{}' \;
    write_out "INFO" "Removidas pastas de backups antigas (se existirem)."

    # Efetuar o backup usando o mysqldump e o bzip2 para comprimir
    # --single-transaction : This option sets the transaction isolation mode to REPEATABLE READ and sends a START TRANSACTION SQL statement to the server before dumping data.
    # --flush-logs         : Flush the MySQL server log files before starting the dump. This option requires the RELOAD privilege.
    # --all-databases      : dump all databases (except information_schema and performance_schema)
    # --add-drop-database  : Write a DROP DATABASE statement before each CREATE DATABASE statement.
    # --opt                : equivalente a "--add-drop-table --add-locks --create-options --disable-keys --extended-insert --lock-tables --quick --set-charset"
    # --routines           : Include stored routines (procedures and functions) for the dumped databases in the output. This option requires the SELECT privilege for the mysql.proc table.
    # --events             : Include Event Scheduler events for the dumped databases in the output. This option requires the EVENT privileges for those databases.
    write_out "INFO" "Inicio do mysqldump."
    S_VAR_DATETIME=$(date +'%Y%m%dT%H%M%s')
    L_DUMP_FILENAME="${S_BACKUP_DIR_TODAY_NAME}/${S_MYSQL_HOST}_${S_INSTANCE_NAME}_all-dbs_${S_VAR_DATETIME}.sql.bz2"
    ${S_MYSQLBASE_DIR}/bin/mysqldump ${S_MYSQL_AUTH_OPTION} \
        --single-transaction \
        --flush-logs \
        --all-databases \
        --add-drop-database \
        --opt \
        --routines \
        --events \
        2>>"${S_ERROR_MSG_FILE}" | bzip2 > "${L_DUMP_FILENAME}" 2>>"${S_ERROR_MSG_FILE}"

    # Verificar exit status. eh um pipe com 2 comandos, verificar exit status de cada um
    # Copiar o array de status codes para uma variavel local
    L_RETURN_CODES=(${PIPESTATUS[@]})
    if [ ${L_RETURN_CODES[0]} -ne 0 ] || [ ${L_RETURN_CODES[1]} -ne 0 ]; then
        write_out "ERROR" "Erro ao efetuar o mysqldump: [${L_DUMP_FILENAME}]." | tee -a "${S_ERROR_MSG_FILE}"
        L_EXIT_STATUS_CODE=102
        break
    else
        write_out "INFO" "Conclusao do mysqldump [${L_DUMP_FILENAME}]."
    fi

    # Ir buscar o tamanho em MiB do ficheiro de backup apos compressao
    L_HUMAN_FILE_SIZE=$(du -BM "${L_DUMP_FILENAME}" | tr '[:space:]' '#' | sed 's/,/./g'  | sed 's/M//g' | cut -d# -f1)
    if [ $? -ne 0 ]; then
        write_out "ERROR" "Erro ao tentar verificar o volume de dados do ficheiro de backup comprimido: [${L_DUMP_FILENAME}]." | tee -a "${S_ERROR_MSG_FILE}"
        L_EXIT_STATUS_CODE=102
        break
    else
        write_out "INFO" "Volume de dados de saida do ficheiro de backup comprimido: [${L_HUMAN_FILE_SIZE} MiB]."
    fi

    # Verificar que o ficheiro de backup comprimido tem tamanho superior a S_BACKUP_MINIMUM_COMPRESSED_SIZE_KIB
    (( L_HUMAN_FILE_SIZE_KIB = L_HUMAN_FILE_SIZE * 1024 ))
    if [ ${L_HUMAN_FILE_SIZE_KIB} -le ${S_BACKUP_MINIMUM_COMPRESSED_SIZE_KIB} ]; then
        write_out "ERROR" "Tamanho do ficheiro de backup [${L_DUMP_FILENAME}] inferior a [${S_BACKUP_MINIMUM_COMPRESSED_SIZE_KIB}] KiB." | tee -a "${S_ERROR_MSG_FILE}"
        L_EXIT_STATUS_CODE=102
        break
    fi
    
    #########################################################################
    ## ACTIONS BLOCK END
    #########################################################################

done

## Verificar se deve enviar alerta
if [ ${L_EXIT_STATUS_CODE} -ne 0 ]; then
    envia_mail
else
    ## Nao houve erros, eliminar o ficheiro S_ERROR_MSG_FILE
    if [ -f "${S_ERROR_MSG_FILE}" ]; then
        rm "${S_ERROR_MSG_FILE}"
    fi
fi
