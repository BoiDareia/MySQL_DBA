#!/usr/bin/bash
#set -x

# Version: 1.0 - Luis Marques
#
# Necessário alterar S_LOG_DIR, S_MYSQLBASE_DIR, S_INSTANCE_NAME,
#

## Efetuar source das funcoes shell utilitarias
. /mysql/basedir/bin/utilgdb

#############################################################################
S_PROGNAME="${0##*/}"
S_HOSTNAME=$(hostname -s)

#---------------------------------------------------------------------------
#### MUDAR AS PATHS DE ACORDO COM A MAQUINA/AMBIENTE                    ####
S_MYSQLBASE_DIR="/mysql/basedir/5.7.20"
S_LOG_DIR="/mysql/basedir/trace"
S_INSTANCE_NAME='INSTANCIA'

S_MYSQL_AUTH_OPTION="--login-path=bck"
S_MYSQL_FLUSH_BIN_LOGS="FLUSH BINARY LOGS"
S_NETBACKUP_POLITICA="${S_HOSTNAME}_APPLICATION_UserBck"
S_NETBACKUP_HOSTNAME="${S_HOSTNAME}.com"
S_BIN_LOG_DIR="/mysql/backups/binlogs"

S_MYSQL_FROM="DBA MYSQL PTP <dba-mysql-ptp@telecom.com>"
S_MYSQL_TO="dba-mysql-ptp@telecom.com"

#---------------------------------------------------------------------------
S_VAR_DATETIME=$(date -u +'%Y%m%dT%H%M%s')
S_MYSQL_HOST=$(hostname -s)
S_ERROR_MSG_FILE="${S_LOG_DIR}/${S_PROGNAME%%.*}_${S_INSTANCE_NAME}_${S_VAR_DATETIME}.err"

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
SUBJECT: ERRO - Backup dos bin logs MySQL falhou ${S_MYSQL_HOST}

This is an automatic generated mail created by the
$0 script at host ${S_MYSQL_HOST}
------------------------------------------------------------------

Erro no backup dos bin logs MySQL.
Ficheiro de erro em:
${S_ERROR_MSG_FILE}

DATE: ${S_VAR_DATETIME}

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

    ## Efetuar a mudanca de bin logs
    ${S_MYSQLBASE_DIR}/bin/mysql ${S_MYSQL_AUTH_OPTION} --verbose -e "${S_MYSQL_FLUSH_BIN_LOGS}"
    L_MYSQL_EXIT_CODE=$?
    if [ ${L_MYSQL_EXIT_CODE} -ne 0 ]; then
        write_out "ERROR" "Erro ao efetuar a mudanca de bin logs, exit code: [${L_MYSQL_EXIT_CODE}]." | tee -a "${S_ERROR_MSG_FILE}"
        L_EXIT_STATUS_CODE=102
        break
    else
        write_out "INFO" "Efetuado o [${S_MYSQL_FLUSH_BIN_LOGS}]."
        sleep 30
    fi
    L_BACKUP_DATETIME_LABEL=$(date -u +'%Y%m%dT%H%M')
    ## Efetuar o backup da diretoria de bin logs
    L_CMD_STR="/usr/openv/netbackup/bin/bpbackup -w"
    L_CMD_STR="${L_CMD_STR} -k \"${S_INSTANCE_NAME}_bin_log_${L_BACKUP_DATETIME_LABEL}\""
    L_CMD_STR="${L_CMD_STR} -L \"/usr/openv/netbackup/logs/user_ops/${S_INSTANCE_NAME}_bin_log_backup_$(date -u +'%Y%m%d').log\" -en"
    L_CMD_STR="${L_CMD_STR} -p \"${S_NETBACKUP_POLITICA}\""
    L_CMD_STR="${L_CMD_STR} -h \"${S_NETBACKUP_HOSTNAME}\""
    L_CMD_STR="${L_CMD_STR} \"${S_BIN_LOG_DIR}\""
    
    write_out "INFO" "Comando netbackup: [${L_CMD_STR}]."

    ## Parametros para o netbackup
    # -w : Esperar pelo codigo de status do netbackup
    # -k : titulo para o backup
    # -L : localizacao para o log gerado pelo netbackup
    # -p : politica netbackup
    # -h : hostname do servidor do cliente do netbackup
    /usr/openv/netbackup/bin/bpbackup -w \
    -k "${S_INSTANCE_NAME}_bin_log_${L_BACKUP_DATETIME_LABEL}" \
    -L "/usr/openv/netbackup/logs/user_ops/${S_INSTANCE_NAME}_bin_log_backup_$(date -u +'%Y%m%d').log" -en \
    -p "${S_NETBACKUP_POLITICA}" \
    -h "${S_NETBACKUP_HOSTNAME}" \
    "${S_BIN_LOG_DIR}/"
    
    L_NETBACKUP_EXIT_CODE=$?
    if [ ${L_NETBACKUP_EXIT_CODE} -ne 0 ]; then
        write_out "ERROR" "Erro ao efetuar backup dos bin logs [${S_BIN_LOG_DIR}] , exit code: [${L_NETBACKUP_EXIT_CODE}]." | tee -a "${S_ERROR_MSG_FILE}"
        L_EXIT_STATUS_CODE=103
        break
    else
        write_out "INFO" "Efetuado backup dos bin logs [${S_BIN_LOG_DIR}]."
        
        L_CMD_STR="/usr/openv/netbackup/bin/bplist"
        L_CMD_STR="${L_CMD_STR} -C \"${S_NETBACKUP_HOSTNAME}\""
        L_CMD_STR="${L_CMD_STR} -F -keyword \"${S_INSTANCE_NAME}_bin_log_${L_BACKUP_DATETIME_LABEL}\"" 
        L_CMD_STR="${L_CMD_STR} -k \"${S_NETBACKUP_POLITICA}\"" 
        L_CMD_STR="${L_CMD_STR} -l -b \"${S_BIN_LOG_DIR}/*\""
        
        write_out "INFO" "Comando para listar ficheiros deste backup: [${L_CMD_STR}]"
        
        L_CMD_STR="/usr/openv/netbackup/bin/bprestore -w -t 0 -print_jobid"
        L_CMD_STR="${L_CMD_STR} -C \"${S_NETBACKUP_HOSTNAME}\""
        L_CMD_STR="${L_CMD_STR} -L \"/usr/openv/netbackup/logs/user_ops/${S_INSTANCE_NAME}_bin_log_restore_$(date -u +'%Y%m%d').log\" -en"
        L_CMD_STR="${L_CMD_STR} -k \"${S_INSTANCE_NAME}_bin_log_${L_BACKUP_DATETIME_LABEL}\""
        L_CMD_STR="${L_CMD_STR} \"${S_BIN_LOG_DIR}\""
        
        write_out "INFO" "Comando para efetuar o restore: [${L_CMD_STR}]"

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
