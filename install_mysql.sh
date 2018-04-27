#!/bin/bash

# Automate MySQL Enterprise 5.7 setup
# v0.1 - Initial release
# v0.2 - Added extra safe guards
# v0.3 - PCI Compliance - 2017/05/05

# Parameters
# $1 : Project name (used to build the installation destination dir paths)
# $2 : Installation package filename
#
# Assumptions:
# 1. Mysql file system mountpoints are subdiretories under /mysql/
# 2. /etc/my.cnf is a symbolic link
# 3. The audit plugin file "audit_log.so" is somewhere under the current dir (when using community edition)
# 4. the script is executed in the dir with the package archive, default my.cnf and audit plugin binary
# 5. The setup of the audit plugin is not included in this script
# 6. The automatic startup of the mysql service is not done by this script 
#
#
# File systems:
# /mysql/basedir                    -> mysql binaries and scripts
# /mysql/<PROJECT_NAME>/backups     -> backup archive
# /mysql/<PROJECT_NAME>/binlogs     -> mysql binary log archive 
# /mysql/<PROJECT_NAME>/datafiles   -> mysql data files
# /mysql/<PROJECT_NAME>/logs        -> mysql audit and log files
# 

# help, execution flags
if [ $# -lt 2 ]; then
    echo "Missing arguments."
    echo "Usage: $0 project_name mysql_tar_package"
    exit 1
fi
# variables
# Project name, usually <NAME_ENVIRONMENT>
PROJECT_NAME=$1
# Remove environment suffix from project name
# ex: newproject_prd
#     --> newproject
PROJC=$(echo ${PROJECT_NAME} | cut -d_ -f 1)
# Installation filename
PKG=$2
# Get the package version from the filename
VERSION=$(echo ${PKG} | cut -d"-" -f 2)
# Define installation destination dir name, from package filename
# ex: /mysql/basedir/packages/mysql-5.5.58-linux-glibc2.12-x86_64.tar.gz 
#     --> mysql-5.5.58-linux-glibc2.12-x86_64
PKG_DIR=$(echo ${PKG} | sed 's/^.*mysql/mysql/;s/\.tar\.gz//')

# generate random root password
NEW_PASSWORD=$(</dev/urandom tr -dc 'A-Za-z0-9!#$%&()*+,-./:=?[\]_{|}~' | head -c 15)

# Base dir for mysql binaries and scripts
MYSQL_BASE="/mysql/basedir"
# Base dir for admin files (pid, socket, etc)
MYSQL_ADMIN="${MYSQL_BASE}/admin"
# Symbolic link name for installation binaries dir
MYSQL_HOME="${MYSQL_BASE}/${VERSION}"
# Base dir for mysql backup archives
MYSQL_BCK="/mysql/${PROJECT_NAME}/backups"
# Base dir for mysql data files
MYSQL_DATAFILES="/mysql/${PROJECT_NAME}/datafiles"
# Base dir for mysql log and trace files
MYSQL_LOG="/mysql/${PROJECT_NAME}/logs"
# Base dir for mysql audit files
MYSQL_AUDIT="${MYSQL_LOG}/audit"
# Base dir for bin log archives
MYSQL_BINLOGS="/mysql/${PROJECT_NAME}/binlogs"

# Other dirs created under the base dirs
# datafile dirs
MYSQL_DATA="${MYSQL_DATAFILES}/data"
MYSQL_INNODATA="${MYSQL_DATAFILES}/innodata"
MYSQL_INNOLOGS="${MYSQL_DATAFILES}/innologs"

# Other files
MYSQL_LOG_ERROR="${MYSQL_LOG}/mysql_error.log"
MYSQL_LOG_SLOW="${MYSQL_LOG}/mysql_slow.log"
MYSQL_LOG_GENERAL="${MYSQL_LOG}/mysql_general.log"
MYSQL_LOG_AUDIT="${MYSQL_AUDIT}/mysql_audit.log"

# SO mysql user
SO_MYSQL_USER="mysql"

# DBA users
MYSQL_DBAS="tm503111 p057991 xdesa04 xoli454 p046797"
MYSQL_DBA_TEMP_PWD="Temporaria123_"

## We assume auxiliary files are under the current dir
# Audit plugin filename
MY_AUDIT_PLUGIN_FILE="audit_log.so"
# Base my.cnf
MY_BASE_CNF="my.cnf.base"

## Validation related message
VALIDATION_ERROR_MSG="Validation ERROR"
VALIDATION_OK_MSG="Validation OK"

echo "Projeto: ${PROJECT_NAME}"
echo "Versao MySQL: ${VERSION}"


# check user
# guarantee that instalation is run by mysql user
if [ "${USER}" != "${SO_MYSQL_USER}" ]; then
    echo "$0 - needs to run as user ${SO_MYSQL_USER}."
    exit 1
else
    echo "${VALIDATION_OK_MSG}: installation user is ${SO_MYSQL_USER} ."
fi

# Validation: audit plugin file
P_AUDIT=$(find . -type f -name "${MY_AUDIT_PLUGIN_FILE}")
if [ -z "${P_AUDIT}" ]; then
    echo "${VALIDATION_ERROR_MSG}: Missing audit plugin library ${MY_AUDIT_PLUGIN_FILE} for instalation."
    exit 1
else
    echo "${VALIDATION_OK_MSG}: Found audit plugin file ${MY_AUDIT_PLUGIN_FILE} ."
fi

# Validation: 
for ITER_FILE in "${MY_BASE_CNF}"; do
    if [ ! -f "${ITER_FILE}" ]; then
        echo "${VALIDATION_ERROR_MSG}: Missing auxiliar file ${ITER_FILE} for instalation."
        exit 1
    else
        #echo "DEBUG: " dos2unix "${ITER_FILE}"
        echo "${VALIDATION_OK_MSG}: Found mysql base config file ${MY_BASE_CNF} ."
        dos2unix "${ITER_FILE}"
        if [ $? -ne 0 ]; then
            echo "ERROR: failed to convert eol for file  ${ITER_FILE} ."
            exit 1
        fi
    fi
done

# Validation for files and directories:
# 1.1 Place  Databases  on  Non System  Partitions  (Scored) Level  1
# guarantee that MySQL is not instaled and created in root FS
# guarantee that all directories have appropriate permissions and ownership
for ITER_FS in "${MYSQL_BCK}" "${MYSQL_DATAFILES}" "${MYSQL_LOG}" "${MYSQL_AUDIT}" "${MYSQL_BINLOGS}"; do
    if [ ! -d "${ITER_FS}" ]; then
        # Directory does not exists/no permissions
        echo "${VALIDATION_ERROR_MSG}: Missing directory ${ITER_FS}."
        exit 1
    else
        D_OWNER=$(stat -c '%U' "${ITER_FS}")
        if [ "${D_OWNER}" != "${SO_MYSQL_USER}" ]; then
            # Directory not owned by SO_MYSQL_USER
            echo "${VALIDATION_ERROR_MSG}: ${ITER_FS} not owned by user ${SO_MYSQL_USER}."
            exit 1
        fi
        D_MOUNT_POINT=$(df -P "${ITER_FS}" | tail -1 | awk '{ print $NF; }')
        if [ -z "${D_MOUNT_POINT}" ]; then
            # Cannot verify mount point of directory (cannot determie of ot is a system file system)
            echo "${VALIDATION_ERROR_MSG}: cannot verify mount point of ${ITER_FS} ."
            exit 1
        fi
        if [ "${D_MOUNT_POINT}" == "/" ] || [ "${D_MOUNT_POINT}" == "/var" ] || [ "${D_MOUNT_POINT}" == "/usr" ]; then
            # Directory is mounted / created in a system file system
            echo "${VALIDATION_ERROR_MSG}: mount point for file system ${ITER_FS} cannot be '/', '/var', '/usr'."
            exit 1
        fi
        # Set more restrictive permissions for directory
        #echo "DEBUG: " chmod 700 "${ITER_FS}"
        chmod 700 "${ITER_FS}"
        if [ $? -ne 0 ]; then
            echo "${VALIDATION_ERROR_MSG}: failed to set chmod 700 for ${ITER_FS} ."
            exit 1
        fi        
        echo "${VALIDATION_OK_MSG}: Diretory ${ITER_FS} verified."
    fi
done

# Check if simlink /etc/my.cnf --> MYSQL_DATAFILES/admin/my.cnf
if [ -L "/etc/my.cnf" ]; then
    # simlink exists, verifiy if points to expected file
    SYMLINK_MYCNF=$(ls -l "/etc/my.cnf" | awk '{ print $NF; }')
    if [ "${SYMLINK_MYCNF}" != "${MYSQL_ADMIN}/my.cnf" ]; then
        echo "ERROR: symlink /etc/my.cnf does not point to ${MYSQL_ADMIN}/my.cnf ."
        exit 1
    else
        echo "${VALIDATION_OK_MSG}: symlink /etc/my.cnf points to ${MYSQL_ADMIN}/my.cnf ."
    fi
else
    echo "ERROR: Missing symlink /etc/my.cnf --> ${MYSQL_ADMIN}/my.cnf ."
    exit 1
fi

## Create dirs under the data base dir
# MYSQL_DATA
if [ ! -d "${MYSQL_DATA}" ]; then
    mkdir -p "${MYSQL_DATA}"
    if [ $? -ne 0 ]; then
        echo "ERROR: failed to create dir ${MYSQL_DATA} ."
        exit 1
    fi
fi
chmod 700 "${MYSQL_DATA}"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: failed to chmod 700 dir ${MYSQL_DATA} ."
    exit 1
else
    echo "${VALIDATION_OK_MSG}: Directory ${MYSQL_DATA} verified."
fi    
# MYSQL_INNODATA
if [ ! -d "${MYSQL_INNODATA}" ]; then
    mkdir -p "${MYSQL_INNODATA}"
    if [ $? -ne 0 ]; then
        echo "ERROR: failed to create dir ${MYSQL_INNODATA} ."
        exit 1
    fi
fi
chmod 700 "${MYSQL_INNODATA}"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: failed to chmod 700 dir ${MYSQL_INNODATA} ."
    exit 1
else
    echo "${VALIDATION_OK_MSG}: Directory ${MYSQL_INNODATA} verified."
fi
# MYSQL_INNOLOGS
if [ ! -d "${MYSQL_INNOLOGS}" ]; then
    mkdir -p "${MYSQL_INNOLOGS}"
    if [ $? -ne 0 ]; then
        echo "${VALIDATION_ERROR_MSG}: failed to create dir ${MYSQL_INNOLOGS} ."
        exit 1
    fi
fi
chmod 700 "${MYSQL_INNOLOGS}"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: failed to chmod 700 dir ${MYSQL_INNOLOGS} ."
    exit 1
else
    echo "${VALIDATION_OK_MSG}: Directory ${MYSQL_INNOLOGS} verified."
fi    

## Create dirs under the mysql basedir
# MYSQL_ADMIN
if [ ! -d "${MYSQL_ADMIN}" ]; then
    mkdir -p "${MYSQL_ADMIN}"
    if [ $? -ne 0 ]; then
        echo "ERROR: failed to create dir ${MYSQL_ADMIN} ."
        exit 1
    fi
fi
chmod 755 "${MYSQL_ADMIN}"
if [ $? -ne 0 ]; then
    echo "ERROR: failed to chmod 755 dir ${MYSQL_ADMIN} ."
    exit 1
else
    echo "${VALIDATION_OK_MSG}: Directory ${MYSQL_ADMIN} verified."
fi

## Create dirs under the mysql log dir
# MYSQL_AUDIT
if [ ! -d "${MYSQL_AUDIT}" ]; then
    mkdir -p "${MYSQL_AUDIT}"
    if [ $? -ne 0 ]; then
        echo "ERROR: failed to create dir ${MYSQL_AUDIT} ."
        exit 1
    fi
fi
chmod 700 "${MYSQL_AUDIT}"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: failed to chmod 755 dir ${MYSQL_AUDIT} ."
    exit 1
else
    echo "${VALIDATION_OK_MSG}: Directory ${MYSQL_AUDIT} verified."
fi

## Touch mysql log files and set permissions
# log_error
touch "${MYSQL_LOG_ERROR}"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: failed to touch file ${MYSQL_LOG_ERROR} ."
    exit 1
fi
chmod 600 "${MYSQL_LOG_ERROR}"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: failed to chmod 700 dir ${MYSQL_LOG_ERROR} ."
    exit 1
else
    echo "${VALIDATION_OK_MSG}: File ${MYSQL_LOG_ERROR} verified."
fi
# mysql_slow
touch "${MYSQL_LOG_SLOW}"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: failed to touch file ${MYSQL_LOG_SLOW} ."
    exit 1
fi
chmod 600 "${MYSQL_LOG_SLOW}"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: failed to chmod 700 dir ${MYSQL_LOG_SLOW} ."
    exit 1
else
    echo "${VALIDATION_OK_MSG}: File ${MYSQL_LOG_SLOW} verified."
fi
# mysql_audit.log
touch "${MYSQL_LOG_AUDIT}"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: failed to touch file ${MYSQL_LOG_AUDIT} ."
    exit 1
fi
chmod 600 "${MYSQL_LOG_AUDIT}"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: failed to chmod 700 dir ${MYSQL_LOG_AUDIT} ."
    exit 1
else
    echo "${VALIDATION_OK_MSG}: File ${MYSQL_LOG_AUDIT} verified."
fi
# mysql_general.log
touch "${MYSQL_LOG_GENERAL}"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: failed to touch file ${MYSQL_LOG_GENERAL} ."
    exit 1
fi
chmod 600 "${MYSQL_LOG_GENERAL}"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: failed to chmod 700 dir ${MYSQL_LOG_GENERAL} ."
    exit 1
else
    echo "${VALIDATION_OK_MSG}: File ${MYSQL_LOG_GENERAL} verified."
fi

# disable mysql history
ln -s /dev/null ~/.mysql_history
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: failed to disable mysql history ."
    exit 1
else
    echo "${VALIDATION_OK_MSG}: mysql history is disabled."
fi

# Copy and manipulate my.cnf.base
cp "${MY_BASE_CNF}" "${MYSQL_ADMIN}/my.cnf"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: Failed copy ${MY_BASE_CNF} to ${MYSQL_ADMIN}/my.cnf ."
    exit 1
fi
sed -i "s/#PROJECT_NAME#/${PROJECT_NAME}/" "${MYSQL_ADMIN}/my.cnf"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: Failed to edit PROJECT_NAME on ${MYSQL_ADMIN}/my.cnf ."
    exit 1
fi
sed -i "s/#VERSION#/${VERSION}/" "${MYSQL_ADMIN}/my.cnf"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: Failed to edit VERSION on ${MYSQL_ADMIN}/my.cnf ."
    exit 1
fi
chmod 644 "${MYSQL_ADMIN}/my.cnf"
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: Failed to chmod 644 on ${MYSQL_ADMIN}/my.cnf ."
    exit 1
fi
echo "${VALIDATION_OK_MSG}: File ${MYSQL_ADMIN}/my.cnf verified."

echo "Starting mysql binaries unpacking."

# setup mysql home, install binaries
if [ ! -d "${MYSQL_BASE}/${PKG_DIR}" ]; then
    echo "Unpacking binaries ."
    tar -zxf "${PKG}" -C "${MYSQL_BASE}"
    if [ $? -ne 0 ]; then
        echo "${VALIDATION_ERROR_MSG}: Failed to unpack binaries ."
        exit 1
    fi    
    ln -s "${MYSQL_BASE}/${PKG_DIR}" "${MYSQL_HOME}"
    if [ $? -ne 0 ]; then
        echo "${VALIDATION_ERROR_MSG}: Failed to create symlink ${MYSQL_HOME} --> {MYSQL_BASE}/${PKG_DIR} ."
        exit 1
    fi
    echo "${VALIDATION_OK_MSG}: mysql binaries unpacked ."
fi

# Initialize mysql
# install and instance setup process
# Before initialization, weaken password validation because of auto-generated password (else it will be rejected)
sed -i 's/^validate_password_length.*/#validate_password_length              = 14/' "${MYSQL_ADMIN}/my.cnf"
sed -i 's/^validate_password_mixed_case_count.*/#validate_password_mixed_case_count    = 1/' "${MYSQL_ADMIN}/my.cnf"
sed -i 's/^validate_password_special_char_count.*/#validate_password_special_char_count  = 1/' "${MYSQL_ADMIN}/my.cnf"
sed -i 's/^validate_password_policy.*/validate_password_policy              = MEDIUM/' "${MYSQL_ADMIN}/my.cnf"

# Do initiliazation
echo "MySQL initialization."
${MYSQL_HOME}/bin/mysqld --initialize
#${MYSQL_HOME}/bin/mysqld --initialize-insecure
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: Failed to initialize MySQL ."
    exit 1
else
    echo "${VALIDATION_OK_MSG}: Initialized MySQL ."
fi

# Get auto generated root password
MYSQL_TEMP_PWD=$(tail -1 "${MYSQL_LOG_ERROR}" | grep 'A temporary password is generated' | awk -F'root@localhost: ' '{print $2}')
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: Failed to recover auto generated-password ."
    exit 1
fi

# Before 1st startup, require stronger password validation because of weak auto-generated password 
sed -i 's/^#validate_password_length.*/validate_password_length              = 14/' "${MYSQL_ADMIN}/my.cnf"
sed -i 's/^#validate_password_mixed_case_count.*/validate_password_mixed_case_count    = 1/' "${MYSQL_ADMIN}/my.cnf"
sed -i 's/^#validate_password_special_char_count.*/validate_password_special_char_count  = 1/' "${MYSQL_ADMIN}/my.cnf"
sed -i 's/^validate_password_policy.*/validate_password_policy              = STRONG/' "${MYSQL_ADMIN}/my.cnf"

# First startup
${MYSQL_HOME}/support-files/mysql.server start
if [ $? -ne 0 ];then
  echo "${VALIDATION_ERROR_MSG}: Error starting MySQL server ."
  echo "Check error file ${MYSQL_LOG_ERROR} ."
  exit 1
fi
echo "MySQL server started ."

# Set new root password (replace auto generated)
${MYSQL_HOME}/bin/mysqladmin --user root --password="${MYSQL_TEMP_PWD}" password "${NEW_PASSWORD}"
if [ $? -ne 0 ];then
    echo "${VALIDATION_ERROR_MSG}: Error setting root password ."
    echo "Check error file ${MYSQL_LOG_ERROR} ."
    ${MYSQL_HOME}/support-files/mysql.server stop
    if [ $? -ne 0 ];then
        echo "${VALIDATION_ERROR_MSG}: Error shutting down mysql ."
        echo "Check error file ${MYSQL_LOG_ERROR} ."
    fi
    exit 1
fi
echo "${VALIDATION_OK_MSG}: Set root password [${NEW_PASSWORD}] ."

# create DBA users with expired password
# zero users file
> users.sql
for ITER_USER in ${MYSQL_DBAS} ; do
    echo "CREATE USER '${ITER_USER}'@'localhost' IDENTIFIED BY '${MYSQL_DBA_TEMP_PWD}' PASSWORD EXPIRE;" >> users.sql
    echo "GRANT ALL ON *.* TO '${ITER_USER}'@'localhost' WITH GRANT OPTION;" >> users.sql
done

${MYSQL_HOME}/bin/mysql --user root --password="${NEW_PASSWORD}" < users.sql 2> users.err
if [ $? -ne 0 ]; then
    echo "${VALIDATION_ERROR_MSG}: Error creating dba users ."
    echo "Check error file users.err ."
    ${MYSQL_HOME}/support-files/mysql.server stop
    if [ $? -ne 0 ];then
        echo "${VALIDATION_ERROR_MSG}: Error shutting down mysql ."
        echo "Check error file ${MYSQL_LOG_ERROR} ."
    fi
    exit 1
else
    rm users.sql
fi
echo "${VALIDATION_OK_MSG}: Created DBA users . Password is : [${MYSQL_DBA_TEMP_PWD}] ."

# Final shutdown of MySQL
${MYSQL_HOME}/support-files/mysql.server stop
if [ $? -ne 0 ];then
    echo "${VALIDATION_ERROR_MSG}: Error shutting down mysql ."
    echo "Check error file ${MYSQL_LOG_ERROR} ."
fi
echo "${VALIDATION_OK_MSG}: Mysql shutdown ."

cat <<EOF!





MySQL install complete!

Mysql was shutdown sucessfully.

Ask sysadmin team to create mysql service. 
File: ${MYSQL_HOME}/support-files/mysql.server"

Please refer to documentation in order to configure the audit plugin.

EOF!
