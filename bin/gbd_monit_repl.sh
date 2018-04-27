#!/usr/bin/bash
#
#set -x
#############################################################################
# Envia email de alerta formatado
#
# Recebe como parametro uma mensagem que eh colocado no titulo e corpo
# do email.
#
# Assume a existencia das seguintes variaveis no script
# EMAIL_TO
# HOST
# DATE_VAR
#
send_email ()
{

    sendmail -t <<EOF!
FROM: mysql
TO: $EMAIL_TO
CC:
SUBJECT: $1: Host: ${HOST}

This is an automatic generated mail created by the ${S_PROGNAME}
 script at host ${HOST}
--------------------------------------------------------------------

Date: ${DATE_VAR}

Specific msg: ${1}

--------------------------------------------------------------------

EOF!

    F_EXIT_STATUS=$?
    return ${F_EXIT_STATUS}
}

#############################################################################
# Envia alerta para o OVO (HPOM) utilizando o comando opcmon e a politica
# SCM_PROC_MYSQL. A criticidade dos alarmes desta politica eh a seguinte:
# 0 -> Critical
# 1 -> Major
# 2 -> Minor
# 3 -> Warning
# 4 -> Normal
#
#
send_OVO ()
{
    #sending event to HP Openview
    OPC_CMD="/opt/OV/bin/opcmon SCM_PROC_MYSQL=${OPEN_SEV} -object \"INVOCA:::::REPLICACAO\" -option INST0=\"${INST_MSG}\" -option MSG=\"${MSG}\" -option APP=\"MySQL\" -option INSTNAME=\"chpblo09_senhas\""
    echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') $$ : INFO : ${OPC_CMD}"

    /opt/OV/bin/opcmon SCM_PROC_MYSQL=${OPEN_SEV} -object "INVOCA:::::REPLICACAO" -option INST0="${INST_MSG}" -option MSG="${MSG}" -option APP="MySQL" -option INSTNAME="chpblo09_senhas"

#    true
    F_EXIT_STATUS=$?
    return ${F_EXIT_STATUS}
}

#############################################################################
# Verificar e atualizar os ficheiros de flags que contabilizam o numero de
# envio de alertas.
#
# Eh criado um ficheiro de flag para cada codigo de erro. Por cada
# vez que o codigo de erro eh repetido, acrescenta uma linha ao
# respetivo ficheiro de flag. O numero de alertas eh o numero de linhas.
# Enquanto numero de alertas for inferior ao limite, gerar ALERTA OVO
# como Minor. Se numero de alertas
#
# Recebe como parametro o codigo de erro da verificacao da replicacao.
# Codigos de erro:
# 100 -> Slave esta sincronizado com o Master (dentro do limite)
# 101 -> Binario do cliente mysql nao foi encontrado
# 102 -> Master nao responde
# 103 -> Slave nao responde
# 104 -> Slave nao esta a replicar
# 105 -> A tentar ligar ao Master
# 106 -> Slave esta acima do limite de atraso para com o Master
#
#
validate_flags ()
{
    # Colocar flag para enviar alerta
    FLAG_ALARM=1
    # Conforme codigo de erro dado como parametro
    case $1 in
    101|102|103|104|105|106)
        if [ -f ${DIR}/work/FLAGS/${SLAVE_HOST}.flag_$1 ]; then
            # Ficheiro de flag existe, contar numero de linhas
            COUNT=$(cat "${DIR}/work/FLAGS/${SLAVE_HOST}.flag_$1" | wc -l)
            if [ ${COUNT} -lt ${NUM_ALRM} ]; then
                OPEN_SEV=2
                INST_MSG="A GBD recebe este alarme. Nao efectuar nenhuma accao."
            elif [ ${COUNT} -eq ${NUM_ALRM} ]; then
                # Atingido o limite alertas, aumentar criticidade do alerta.
                OPEN_SEV=0
                INST_MSG="Contactar prevencao GBD telef. 962435252"
            else
                # Contagem de alertas acima no limite, nao enviar mais alertas
                FLAG_ALARM=0
            fi
        else
            OPEN_SEV=2
            INST_MSG="A GBD recebe este alarme. Nao efectuar nenhuma accao."
        fi
        # Em caso de alerta, incrementar sempre o ficheiro de flag
        echo 1 >> "${DIR}/work/FLAGS/${SLAVE_HOST}.flag_$1"
        ;;
    0)
        if [ -f ${DIR}/work/FLAGS/${SLAVE_HOST}.flag_* ]; then
            ## Existem ficheiros de flag, mas situacao ja esta normalizada, remover todos
            ## e enviar alerta de OK
            rm ${DIR}/work/FLAGS/${SLAVE_HOST}.flag_*
            echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') $$ : INFO : A replicacao entre ${MASTER_HOST} -> ${SLAVE_HOST} esta sincronizada"
            MSG="A replicacao entre ${MASTER_HOST} -> ${SLAVE_HOST} esta sincronizada"
            INST_MSG="A replicacao entre ${MASTER_HOST} -> ${SLAVE_HOST} esta sincronizada"
            OPEN_SEV=4
        else
            # Situacao normalizada, nao enviar alertas
            FLAG_ALARM=0
        fi
        ;;
    esac
}

#############################################################################
# Efetua o envio dos alertas.
#
# Assume a existencia das seguintes variaveis no script
# FLAG_ALARM -> Se deve ser enviado alerta (1 = envia)
# ALARM      -> Tipo de alertas a serem enviados

alarm ()
{
    if [ ${FLAG_ALARM} -eq 1 ]; then
        # Flag de alarme esta a 1 , enviar alertas de acordo com ALARM
        case ${ALARM} in
        1)
            send_email "$MSG"
            send_OVO "$MSG"
            ;;
        2)
#            send_sms "$MSG"
            send_OVO "$MSG"
            ;;
        3)
            send_email "$MSG"
#            send_sms "$MSG"
            send_OVO "$MSG"
            ;;
        esac
    fi
}

### Definicoes globais do script. Editar em conformidade
# Home do user mysql
DIR=/mysql/senhas/basedir
### Output log via crontab  ### LOG=${DIR}/LOG/repl_mysql_$(date +'%Y-%m-%d').log
# Limite de alertas a enviar
NUM_ALRM=3
# Efetua reset do envio de alarmes ao fim de X RESET_ALARM dias
RESET_ALARM=7
# Nome da maquina
HOST=$(hostname -s)
# Nome do script
S_PROGNAME="${0##*/}"
# endereco de email para envio de alertas
EMAIL_TO="dba-mysql-ptp@telecom.pt"
#EMAIL_TO="eduardo-santana@telecom.pt"
SMS_TO="927820521 962435252 963135033 932200218 962435252"

# Criticidade para alerta OVO eh normal
OPEN_SEV=4

# Variaveis de ambiente para controlar o comportamento do cliente mysql
export MYCONNECT_TIMEOUT=10
export MYAPPNAME="gbd_monitor"

SLAVE_CRIT="No"         # what is the answer of MySQL Slave_SQL_Running for a Critical status?
SLAVE_OK="Yes"          # what is the answer of MySQL Slave_SQL_Running for an OK status?
warn_delay=60                   # Delay in seconds for Warning status
crit_delay=90                   # Delay in seconds for Critical status

# Num diff logs entre master e slave
MAX_DIFF=1

### MAIN ###
# Remover ficheiros de flag com mais de RESET_ALARM dias. Efetua o reset da contagem de
# envio de alertas.
find ${DIR}/work/FLAGS/${SLAVE_HOST}.flag* -type f -mtime +${RESET_ALARM} -exec rm -r '{}' ';'

## para cada linha do ficheiro de configuracao verificar sincronizacao master-slave
for LIST in $(cat "${DIR}/etc/repl_servers.lst" | grep -v -E '^#'); do
    ## extrair os campos da linha de configuracao
    MASTER_HOST=$(echo ${LIST} | cut -f 1 -d "|")
    MASTER_PORT=$(echo ${LIST} | cut -f 2 -d "|")
    BIN_DIR=$(echo ${LIST} | cut -f 3 -d "|")
    SLAVE_HOST=$(echo ${LIST} | cut -f 4 -d "|")
    SLAVE_ADDRESS=$(echo ${LIST} | cut -f 5 -d "|")
    SLAVE_CLUSTER=$(echo ${LIST} | cut -f 6 -d "|")
    SLAVE_PORT=$(echo ${LIST} | cut -f 7 -d "|")
    USER_NAME=$(echo ${LIST} | cut -f 8 -d "|")
    ALARM=$(echo ${LIST} | cut -f 9 -d "|")

    FLAG_ALARM=0
    DATE_VAR=$(date '+%Y-%m-%d %H:%M:%S')

    if [ ! -f "${BIN_DIR}/mysql" ]; then
        MSG="ERROR : mysql Not Found!"
        echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') $$ : ${MSG}"
        ERROR_CODE=101
        validate_flags ${ERROR_CODE}
        alarm "${MSG}"
        continue
    fi

        REPL_INFO=$(${BIN_DIR}/mysql --login-path=monitor -h ${MASTER_HOST} -P ${MASTER_PORT} -e "show master status\G")
        if [ $? -ne 0 ]; then
            ## Cliente mysql devolveu exit status != 0 (Assumir que nao consegue contatar o master)
           MSG="ERROR : O Master nao responde em ${MASTER_HOST}:${MASTER_PORT}"
          echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') $$ : ${MSG}"
          ERROR_CODE=102
          validate_flags ${ERROR_CODE}
          alarm "${MSG}"
          continue
         else
                # Tenta ligacao ao Slave
                ConnectionResult=`${BIN_DIR}/mysql --login-path=monitor -h ${SLAVE_HOST} -P ${SLAVE_PORT} -e "show slave status\G" 2>&1`
                if [ -z "`echo "${ConnectionResult}" |grep Slave_IO_State`" ]; then
                 MSG="ERROR : O Slave nao responde em ${SLAVE_HOST}:${SLAVE_PORT} com o erro: ${ConnectionResult}"
                 echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') $$ : ${MSG}"
                 ERROR_CODE=103
                 validate_flags ${ERROR_CODE}
                 alarm "${MSG}"
                 continue
                else
                        check=`echo "${ConnectionResult}" |grep Slave_SQL_Running: | awk '{print $2}'`
                        checkio=`echo "${ConnectionResult}" |grep Slave_IO_Running: | awk '{print $2}'`
                        masterinfo=`echo "${ConnectionResult}" |grep  Master_Host: | awk '{print $2}'`
                        delayinfo=`echo "${ConnectionResult}" |grep Seconds_Behind_Master: | awk '{print $2}'`

                        # Output of different exit states
                        #########################################################################
                        #if [ ${check} = "NULL" ]; then
                        #MSG="WARNING : O Slave ${SLAVE_HOST}:${SLAVE_PORT} nao esta a replicar"
                        #echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') $$ : ${MSG}"
                        #ERROR_CODE=104
                        #validate_flags ${ERROR_CODE}
                        #alarm "${MSG}"
                        #continue
                        #fi

                        if [ ${check} = ${SLAVE_CRIT} ]; then
                          MSG="WARNING : O Slave ${SLAVE_HOST}:${SLAVE_PORT} nao esta a replicar"
                          echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') $$ : ${MSG}"
                          ERROR_CODE=104
                          validate_flags ${ERROR_CODE}
                          alarm "${MSG}"
                          continue
                        else

                                if [ ${checkio} = ${SLAVE_CRIT} ]; then
                                 MSG="ERROR : O Master nao responde em ${MASTER_HOST}:${MASTER_PORT} - Slave_IO_Running: ${checkio}"
                                 echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') $$ : ${MSG}"
                                 ERROR_CODE=102
                                 validate_flags ${ERROR_CODE}
                                 alarm "${MSG}"
                                 continue
                                else

                                        if [ ${checkio} = "Connecting" ]; then
                                         echo "CRITICAL: ${host} Slave_IO_Running: ${checkio}"
                                         MSG="WARNING : A tentar ligar ao Master ${MASTER_HOST}:${MASTER_PORT}"
                                         echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') $$ : ${MSG}"
                                         ERROR_CODE=105
                                         validate_flags ${ERROR_CODE}
                                         alarm "${MSG}"
                                         continue
                                        else

                                                if [[ ${delayinfo} -ge ${crit_delay} ]]; then
                                                MSG="ERROR: O Slave ${SLAVE_HOST} esta atrasado em ${crit_delay} segundos"
                                                echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') $$ : ${MSG}"
                                                ERROR_CODE=106
                                                validate_flags ${ERROR_CODE}
                                                alarm "${MSG}"
                                                continue
                                                  elif [[ ${delayinfo} -ge ${warn_delay} ]]; then
                                                  MSG="WARNING: O Slave ${SLAVE_HOST} esta atrasado em ${warn_delay} segundos"
                                                  echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') $$ : ${MSG}"
                                                  ERROR_CODE=106
                                                  validate_flags ${ERROR_CODE}
                                                  alarm "${MSG}"
                                                  continue
                                                else
                                                        ## Nao existe atraso na replicacao (mesmo WAL)
                                                        ERROR_CODE=0
                                                         validate_flags ${ERROR_CODE}
                                                         MSG="INFO : Replicacao entre ${MASTER_HOST} e ${SLAVE_HOST} esta sincronizada."
                                                         echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') $$ : ${MSG}"
                                                        alarm "${MSG}"
                                                        continue

                                                fi
                                        fi
                                fi
                        fi
                fi
        fi

done

