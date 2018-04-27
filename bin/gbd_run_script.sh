#!/usr/bin/bash
#############################################################################
# Script para verificar e preparar a execucao dos scripts gbd (crontab).
# Vai testar se a diretoria de scripts existe (por causa de cluster SO,
# provavelmente redundante, visto os scripts nao estarem presentes se
# os FS nao estiverem montados).
# Vai adicionar ao PATH a diretoria de scrips (por causa do crontab)
# (teste simplistico para verificar se eh o no ativo)

# Assuminos que o crontab tem /mysql/senhas_repl_qa/basedir/bin adicionado ao PATH
GBD_MYBIN_DIR="/mysql/senhas/basedir/bin"
# run parameters only if GBD_MYBIN_DIR exists

if [ -d "${GBD_MYBIN_DIR}" ]; then
    ## Execute parameters
    $*
fi