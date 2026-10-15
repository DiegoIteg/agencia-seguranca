#!/bin/bash
# =====================================================================
# GO AUTO - Verificacao de Seguranca e Saude (producao)   [READ-ONLY]
# Agencia de Seguranca iTEG4Business - equipa defensiva (Vitor/Nadia/Iris)
# ---------------------------------------------------------------------
# NAO altera nada: so le e reporta. Correr no servidor, como utilizador
# do site (ex.: goauto@prod), a partir de qualquer pasta.
# Uso:   bash verificacao_goauto.sh
# Opcional: definir o dominio/raiz por variavel de ambiente:
#   DOM=goauto.iteg4business.com ROOT=/home/goauto/public_html bash verificacao_goauto.sh
# =====================================================================
DOM="${DOM:-goauto.iteg4business.com}"
ROOT="${ROOT:-/home/goauto/public_html}"
cd "$ROOT" 2>/dev/null || { echo "ERRO: raiz do site nao encontrada: $ROOT"; exit 1; }

C=0; A=0; M=0; B=0; OKc=0
crit(){ echo "  [CRITICO] $1"; C=$((C+1)); }
alto(){ echo "  [ALTO]    $1"; A=$((A+1)); }
med(){  echo "  [MEDIO]   $1"; M=$((M+1)); }
baixo(){ echo "  [BAIXO]   $1"; B=$((B+1)); }
ok(){   echo "  [OK]      $1"; OKc=$((OKc+1)); }
info(){ echo "  [INFO]    $1"; }

# testa o que o servidor web devolve para um caminho (como um visitante veria)
httpcode(){ curl -k -s -o /dev/null -w '%{http_code}' --resolve "$DOM:443:127.0.0.1" "https://$DOM/$1" 2>/dev/null; }
chk(){ # $1=caminho  $2=nivel se abrir (crit/alto/med)
  local code; code=$(httpcode "$1")
  if [ "$code" = "200" ]; then
    case "$2" in crit) crit "ACESSIVEL pela web (HTTP 200): /$1";; alto) alto "acessivel pela web (HTTP 200): /$1";; *) med "acessivel pela web (HTTP 200): /$1";; esac
  else ok "protegido: /$1 -> HTTP $code"; fi
}

echo "==========================================================="
echo " GO AUTO - VERIFICACAO DE SEGURANCA E SAUDE"
echo " Site: $ROOT"
echo " Dominio: $DOM     Data: $(date '+%d/%m/%Y %H:%M')"
echo " (Leitura apenas - nao altera nada)"
echo "==========================================================="

echo; echo ">>> 1) FICHEIROS SENSIVEIS NA RAIZ DA WEB"
SENS=$(ls -1 2>/dev/null | grep -iE '\.(sql|tgz|tar\.gz|tar|zip|bak|old|sqlite|db|env)$|^LEIA-ME|^COLAR|\.md$|^deploy_|^novo_')
if [ -n "$SENS" ]; then
  while IFS= read -r f; do alto "ficheiro exposto na raiz da web: $f"; done <<< "$SENS"
else ok "sem backups/zip/ficheiros de dev obvios na raiz"; fi
[ -d .git ] && crit "pasta .git exposta (codigo-fonte + historico)" || ok "sem .git exposto"

echo; echo ">>> 2) ACESSO PELA WEB A COISAS QUE NAO DEVEM ABRIR"
chk "app/config/application.ini" crit
chk "app/config/log.php" crit
chk "app/database/log.db" crit
chk "app/config/" alto
chk "install.php" alto
chk "install.html" alto
chk "composer.json" med
BK=$(ls -1 ./*.tgz ./*.tar.gz ./*.zip ./*.sql 2>/dev/null | head -1 | sed 's|^\./||')
[ -n "$BK" ] && chk "$BK" crit

echo; echo ">>> 3) CABECALHOS DE SEGURANCA (HTTPS)  [objetivo: A+]"
H=$(curl -k -sI --resolve "$DOM:443:127.0.0.1" "https://$DOM/" 2>/dev/null)
for hdr in Strict-Transport-Security X-Frame-Options X-Content-Type-Options Content-Security-Policy Referrer-Policy Permissions-Policy; do
  if echo "$H" | grep -qi "^$hdr:"; then ok "cabecalho presente: $hdr"; else med "cabecalho em falta: $hdr"; fi
done

echo; echo ">>> 4) CONFIGURACAO / HARDENING"
if grep -iqE '^\s*debug\s*=\s*"?1' app/config/application.ini 2>/dev/null; then alto "debug LIGADO no application.ini (expoe erros ao utilizador)"; else ok "debug desligado no application.ini"; fi
DE=$(php -r 'echo ini_get("display_errors");' 2>/dev/null)
echo "$DE" | grep -qiE '^(1|on)$' && med "PHP display_errors LIGADO (CLI; confirmar no php-fpm)" || ok "PHP display_errors desligado (CLI)"
php -r 'exit(ini_get("expose_php")?0:1);' 2>/dev/null && med "expose_php LIGADO (revela versao do PHP)" || ok "expose_php desligado"
WW=$(find . -maxdepth 3 -type f -perm -o+w 2>/dev/null | head -5)
[ -n "$WW" ] && { med "ficheiros gravaveis por TODOS (amostra):"; echo "$WW" | sed 's/^/           /'; } || ok "sem ficheiros gravaveis por todos (amostra 3 niveis)"
[ -f .htaccess ] && ok ".htaccess presente na raiz" || alto ".htaccess em falta na raiz (sem regras de protecao)"

echo; echo ">>> 5) SAUDE / FUNCIONAMENTO"
code=$(httpcode "")
[ "$code" = "200" ] && ok "site responde (HTTP 200)" || alto "site NAO devolve 200 (HTTP $code)"
if php -v >/dev/null 2>&1; then ok "PHP $(php -r 'echo PHP_VERSION;' 2>/dev/null)"; else crit "PHP nao encontrado"; fi
for ext in pdo_mysql pdo_sqlite gd mbstring curl zip openssl json; do
  php -m 2>/dev/null | grep -qi "^$ext$" && ok "extensao PHP: $ext" || med "extensao PHP em falta: $ext"
done
LOGCHK=$(php -r '$c=include "app/config/log.php";$p=new PDO("sqlite:".$c["name"]);$t=$p->query("select name from sqlite_master where type=\"table\"")->fetchAll(PDO::FETCH_COLUMN);$need=["system_access_log","system_sql_log","system_change_log"];$m=array_diff($need,$t);echo $m?("FALTA:".implode(",",$m)):"OK";' 2>/dev/null)
[ "$LOGCHK" = "OK" ] && ok "tabelas de log SQLite presentes" || alto "tabelas de log SQLite: $LOGCHK"
for d in tmp files app/database; do if [ -w "$d" ]; then ok "pasta gravavel: $d"; else med "pasta nao gravavel pelo utilizador atual: $d"; fi; done
info "espaco em disco: $(df -h . | tail -1 | awk '{print $4" livres de "$2" ("$5" usado)"}')"
LO=$(ls -d /home/goauto/public_html_PREV_* /home/goauto/public_html_OLD_* /home/goauto/novo_*.tgz 2>/dev/null)
[ -n "$LO" ] && { baixo "sobras do deploy (apagar/mover depois de validar):"; echo "$LO" | sed 's/^/           /'; } || ok "sem sobras do deploy a limpar"

echo; echo "==========================================================="
echo " RESUMO:  CRITICO=$C   ALTO=$A   MEDIO=$M   BAIXO=$B   OK=$OKc"
if   [ $C -gt 0 ]; then echo " VEREDICTO: NAO EXPOR ao publico ate corrigir os CRITICOS."
elif [ $A -gt 0 ]; then echo " VEREDICTO: Funciona, mas corrigir os ALTOS antes de divulgar."
else                    echo " VEREDICTO: Seguro e saudavel. Rever MEDIOS/BAIXOS quando puder."; fi
echo " (Correcao de qualquer achado so com o 'sim' do Diego e com rollback.)"
echo "==========================================================="
