# Achados — Go Auto · Cadastro e Reposição de senha
**Equipa:** Agência de Segurança (Vítor + Nádia/auth + Paulo/código + Gonçalo/dados) · **Data:** 2026-10-11
**Método:** revisão de código (leitura), cópia de trabalho `/root/work/itest`. Nada corrido em produção.

Cada achado: o que é · onde está · o que um atacante faria · risco de negócio · como se corrige · como se confirma.

---

## O que está BEM (para dar contexto)
- **Registo grava a senha em bcrypt** (`AccountService::start`: `password_hash(..., PASSWORD_BCRYPT)`). ✓
- **Login é moderno:** aceita senhas antigas em MD5 mas **re-encripta para bcrypt** no primeiro login (`SystemUsers::authenticate` → `password_verify` + `updatePasswordHash`). ✓
- **Sem injeção de SQL** nestes fluros: as consultas usam o ORM com parâmetros (`Account::where('email','=',...)`). ✓
- **Token de reposição é um JWT assinado** (HS256 com a *seed*) e a *seed* por omissão é recusada. ✓ A validade (3h) e a assinatura são verificadas. ✓

---

## CRÍTICO

### C1 — A reposição de senha grava a nova senha em MD5 (retrocesso)
- **Onde:** `app/control/saas_admin/ResetSenhaForm.php::onResetSenha` → `$user->password = md5($param['password1']);`
- **O que acontece:** quando um utilizador repõe a senha, ela fica guardada em **MD5 sem sal** (algoritmo quebrado para senhas), ao contrário do resto do sistema que já usa bcrypt. Fica assim até ao próximo login (o login depois re-encripta) — ou seja, há uma janela em que a senha reposta está num formato fraco na base de dados.
- **Atacante:** se a base de dados vazar, senhas em MD5 caem a ataques de dicionário/rainbow table quase instantaneamente.
- **Risco de negócio:** credenciais comprometidas, acesso indevido a contas.
- **Correção:** gravar com o mesmo caminho seguro do sistema — `SystemUsers::updatePasswordHash($user, $param['password1'])` (ou `password_hash(..., PASSWORD_DEFAULT)`). Nunca `md5()`.
- **Confirma-se:** após uma reposição, o campo `password` começa por `$2y$` (bcrypt), não um hex de 32 caracteres.

---

## ALTO

### A1 — Link de reposição montado a partir do `HTTP_REFERER` (injeção de host / desvio do token)
- **Onde:** `EsqueciSenhaForm::onAction` → `$referer = $_SERVER['HTTP_REFERER']; $url = substr($referer,0,strpos($referer,'index.php')); $url .= 'index.php?class=ResetSenhaForm&...&token='.$jwt;`
- **O que acontece:** o endereço base do link que vai no email é retirado do cabeçalho `Referer` de **quem faz o pedido** — e o `Referer` é controlável pelo atacante. Um atacante pede a reposição para a vítima com um `Referer` forjado; a vítima recebe um email **legítimo** cujo link aponta para o **servidor do atacante**, já com um **token válido**. A vítima clica → o token chega ao atacante → **tomada de conta**.
- **Também:** se não houver `Referer` (acesso direto), o link sai partido (aviso de PHP + URL inválido) — **falha funcional**.
- **Risco de negócio:** tomada de conta de utilizadores; e o "esqueci a senha" pode simplesmente não funcionar conforme o acesso.
- **Correção:** construir o link a partir de uma **base de URL fixa e configurada** (ex.: `APPLICATION_URL`/config), nunca do `Referer`. Validar o host.
- **Confirma-se:** forçar um `Referer` externo e ver que o link do email continua a apontar para o domínio oficial; com `Referer` vazio, o link sai correto.

### A2 — Token de reposição não é de uso único
- **Onde:** `ResetSenhaForm::onResetSenha` — valida assinatura e expiração, mas não invalida o token após uso nem o liga à senha atual.
- **O que acontece:** o mesmo link funciona **várias vezes** durante 3h, e **continua a funcionar depois** de a senha já ter sido mudada. Quem apanhar o link (histórico, logs, email reencaminhado) repõe a senha outra vez.
- **Risco de negócio:** janela de tomada de conta prolongada.
- **Correção:** tornar o token de uso único — p.ex. incluir no token um resumo da senha atual (`substr(hash,...)`) para deixar de ser válido assim que a senha muda; ou guardar um nonce/served-at por utilizador e invalidar ao usar. Reduzir a validade (ex.: 1h).
- **Confirma-se:** usar o link duas vezes → a segunda é recusada; mudar a senha → o link antigo deixa de servir.

### A3 — XSS refletido no formulário de registo
- **Onde:** `cadastrar.php` — vários `value="<?php echo $_POST['email'] ?? ''; ?>"` (e `nome_unidade`, etc.) **sem escapar**.
- **O que acontece:** o valor de campos é devolvido para o HTML sem `htmlspecialchars`. Um atacante faz uma página que submete o formulário com `"><script>…` → o script corre no domínio do Go Auto (roubo de sessão, ações no nome do utilizador). A página de registo é pública e **não tem token anti-CSRF**, o que facilita o disparo a partir de fora.
- **Risco de negócio:** execução de código no navegador no domínio do sistema.
- **Correção:** escapar **todas** as saídas: `htmlspecialchars($_POST['x'] ?? '', ENT_QUOTES)`. Idealmente, token CSRF no formulário.
- **Confirma-se:** submeter `"><script>alert(1)</script>` e ver que sai escapado (texto), não executado.

---

## MÉDIO

### M1 — Enumeração de utilizadores no "Esqueci a senha"
- **Onde:** `EsqueciSenhaForm::onAction` — mensagens distintas: "não encontrados" vs "inativo" vs "acesse o seu email".
- **O que acontece:** um atacante descobre que emails existem (e quais estão ativos) pela mensagem.
- **Correção:** resposta **sempre igual** ("Se existir uma conta com esse email, enviámos um link.") independentemente de existir/estar ativo.
- **Confirma-se:** email existente e inexistente devolvem a mesma mensagem.

### M2 — Registo e reposição **sem força mínima de senha**
- **Onde:** `cadastrar.php` (só verifica vazio + confirmação) e `ResetSenhaForm` (idem).
- **O que acontece:** aceita "1" como senha.
- **Correção:** exigir um mínimo (ex.: ≥ 8 caracteres, mistura) nos dois sítios.
- **Confirma-se:** senha fraca é recusada com mensagem clara.

### M3 — Atribuição em massa no registo (mass assignment)
- **Onde:** `cadastrar.php` → `$object->fromArray((array)$_POST)` (Account preenchido com **todos** os campos do POST).
- **O que acontece:** o atacante pode enviar colunas extra da tabela `account` que não constam do formulário, definindo-as a seu gosto.
- **Correção:** copiar só os campos esperados (lista branca), não o POST inteiro.
- **Confirma-se:** campos fora da lista branca são ignorados.

### M4 — Sem limite de tentativas / captcha nos endpoints públicos
- **Onde:** `cadastrar.php` e `EsqueciSenhaForm` (ambos públicos).
- **O que acontece:** criação de contas em massa e spam de emails de reposição; ajuda à enumeração.
- **Correção:** limite por IP + captcha (ex.: hCaptcha/Turnstile) nos dois formulários públicos.

---

## BAIXO

### B1 — Validação fraca do email no registo
- `cadastrar.php` não valida o formato com `filter_var(..., FILTER_VALIDATE_EMAIL)` do lado do servidor (confia no `type=email` do browser).

### B2 — Textos em PT-BR, não PT-PT
- "senha", "usuário", "Resetar", "As senhas informas não conferem" (gralha). O Diego quer **PT-PT**: "palavra-passe", "utilizador", "Repor", "As palavras-passe não coincidem".

### B3 — Token de reposição vai no **URL** (query string)
- Fica em histórico/logs/Referer. Mitiga-se com uso único (A2) e validade curta; idealmente entregue via POST.

## 2026-10-15 — Verificação pós-deploy (produção 157.180.89.223)
Ferramenta: ferramentas/verificacao_goauto.sh. Resumo: CRÍTICO=1, ALTO=49, MÉDIO=2, BAIXO=1, OK=30.

**CRÍTICO**
- Backups/zip de desenvolvimento DESCARREGÁVEIS pela web (confirmado: `/app_api_base_2026-10-11.zip` → HTTP 200). ~45 ficheiros `backup_antes_hotfix*.tgz`, zips do beta/pele/api e `migracao_fatura_botoes_*.sql` + `log.db` na raiz de public_html. Vieram no pacote do servidor de teste. Risco: descarga pública de código-fonte e possivelmente dados reais (RGPD — Veloster). Correção: mover tudo para fora da raiz web (reversível).

**ALTO**
- `/install.html` acessível (HTTP 200) — página de instalação. Mover/bloquear.
- Os ~45 backups/zip/sql acima também contam como exposição ALTA individual.

**MÉDIO**
- `/composer.json` acessível (HTTP 200) — revela dependências/versões.
- `expose_php` LIGADO — revela versão do PHP.

**BOM (OK)**
- Cabeçalhos de segurança TODOS presentes (HSTS, X-Frame-Options, X-Content-Type-Options, CSP, Referrer-Policy, Permissions-Policy) → caminho A+.
- app/config/application.ini (403), log.php (401), app/database/log.db (403), install.php (403) — protegidos.
- debug OFF, display_errors OFF, sem ficheiros graváveis por todos, .htaccess presente.
- Saúde: HTTP 200, PHP 8.3.31 + extensões todas, tabelas de log SQLite OK, pastas graváveis OK, disco 13% usado.
- Login admin (Matriz) + Veloster OK (log SQLite corrigido: log.sqlite3 com as 5 tabelas).

**Pendente de correção (com "sim" do Diego, reversível):** mover cruft para fora da web; tratar install.html, composer.json, expose_php.

### Correções aplicadas (2026-10-15) — RESOLVIDO
- CRÍTICO + ALTOS fechados: 49 ficheiros de dev (backups .tgz, zips, .sql, log.db, LEIA-ME, COLAR, install.html) MOVIDOS para fora da web (/home/goauto/_fora_da_web_20261015_085758, reversível). Re-teste: .zip e install.html → 404.
- MÉDIO composer.json + expose_php: .htaccess reforçada (backup antes; auto-reversão testada) — bloqueia .sql/.tgz/.zip/.db/composer.json/etc. e remove cabeçalho X-Powered-By. Site 200, composer.json 403.
- Re-verificação final: CRÍTICO=0, ALTO=0, MÉDIO=1 (expose_php a nível CLI; cabeçalho HTTP já removido), BAIXO=1 (sobras do deploy). VEREDICTO: SEGURO E SAUDÁVEL.
- Pendências menores: (a) apagar pacote exposto no servidor de TESTE (deploy_*.tgz na raiz do deploygoauto); (b) manter public_html_PREV_* alguns dias como rollback, depois apagar + novo_*.tgz; (c) expose_php=Off a nível php.ini (opcional, requer root/Webmin).
- Lapso registado: usar variável HOME no 1º bloco de hardening sobrepôs o atalho ~ da sessão (inofensivo). Aprendizagem: não usar nomes reservados (HOME/PATH/...) em variáveis de scripts colados no terminal.

---

# Ronda 2026-10-17 — isolamento entre empresas, segredos em repouso e palavras-passe
**Equipa:** Vítor (coord.) + Nádia (web/isolamento) + Paulo (código) + Gonçalo (dados/segredos). **Ambiente:** réplica local `/root/work/demo/site2` + SQLite `exp.db`/`work.db`, servidor 127.0.0.1:8771. Prova de isolamento com 2.ª empresa **fictícia** criada e removida no fim (dados fictícios; tabelas universais nunca apagadas por tenant/unit). Nenhum valor de segredo/palavra-passe foi escrito.

## CRÍTICO

### R1 — Fuga de dados entre empresas nas tabelas "globais" com dados de empresa
- **O que é:** o `TRecord`/`TRepository` filtra automaticamente por `tenant_id`+`create_unit` as tabelas de empresa, MAS a lista `TRecord::$globalTables` (que salta o filtro) incluía tabelas que, afinal, têm linhas de **cada** empresa: `grupo_produto`, `conta_grupo`, `system_users`, `system_unit`, `account`, `saas_contrato`, e `viatura` (sem `tenant_id`, pertence ao dono via `pessoa`).
- **Onde:** `lib/adianti/database/TRecord.php` ($globalTables) + todos os combos `TDBCombo/TDBUniqueSearch` desses modelos (ex.: `app/control/stock/StockInventarioNovoForm.php:14-18`, 28 combos de `ContaGrupo`, 89 de `SystemUnit`, dezenas de `Viatura`).
- **Atacante / impacto:** um utilizador da empresa A via (e podia escolher/abrir por n.º) grupos de produto, grupos de conta, utilizadores, filiais, contas, contratos e **viaturas/matrículas** da empresa B (ex.: Veloster). Confirmado: no «Novo inventário» da empresa 1 apareciam grupos da empresa 2.
- **Correção (central):** novo `app/service/seguranca/TenantScope.php` + ganchos em `TRepository::applyGlobalScopes` (listar) e `TRecord` (ler por n.º / gravar / apagar): estas tabelas passam a mostrar/alterar só o que é da empresa ativa (+ linhas partilhadas com `tenant_id`/`create_unit` nulos, quando existem); o administrador da plataforma mantém acesso só nos ecrãs de administração. `SystemUsers::newFromLogin/newFromEmail` e a criação de contas correm em `TenantScope::semAmbito()` (login/registo ainda não têm empresa na sessão).
- **Verificado:** `/root/work/probe/sec_isolamento_cli.php` (antes: fugas em 7 tabelas + viatura abre por n.º; depois: 0 fugas, viatura recusada) e no servidor com as 2 empresas (combos do «Novo inventário» e de ContaGrupo só com dados próprios). Provas: `sec_inventario_isolamento.png`, `sec_isolamento_antes_depois.png`.

### R2 — Serviços de pesquisa liam qualquer coluna de qualquer tabela, sem sessão
- **O que é:** `AdiantiAutocompleteService` assinava o pedido com uma **chave fixa pública** (`...s8dkld83kf73kf094`) e estava em `public_classes` → qualquer pessoa, **sem login**, montava o pedido e lia qualquer coluna (incl. `password`/`two_factor_secret`). O `AdiantiMultiSearchService`/`TStandardSeek` não assinavam máscara, operador, ordem nem critério (e o seek fazia `unserialize` livre).
- **Onde:** `lib/adianti/service/AdiantiAutocompleteService.php`, `AdiantiMultiSearchService.php`, `lib/adianti/base/TStandardSeek.php` e os geradores de assinatura em `lib/adianti/widget/wrapper/{TDBEntry,TDBMultiSearch,TDBSeekButton}.php` + `app/lib/util/AdiantiUIBuilder.php`.
- **Correção:** novo `app/service/seguranca/PesquisaSegura.php` — assinatura **HMAC-SHA256 com a seed da instalação** sobre TODOS os parâmetros que decidem o que se lê; sem seed configurada recusa; nunca lê colunas sensíveis (pass/secret/token/2FA); operador e ordenação só de listas seguras; critério só com classes de critério; os serviços passam a exigir sessão iniciada; mensagens de erro técnicas deixam de ir para o navegador.
- **Verificado:** `/root/work/probe/sec_pesquisa_cli.php` (antes: 9 resultados sem sessão; depois: recusa sem sessão, recusa com máscara trocada, recusa em campo sensível, pesquisa legítima continua a funcionar). Prova: `sec_pesquisa_fuga_fechada.png`.

## ALTO

### R3 — Segredos (SMTP, Moloni, gateways, tokens) em texto simples na base de dados
- **Onde:** `saas_configuracao.email_password` + `token_integra_notas*`; `faturacao.client_secret/password/access_token/refresh_token` (Moloni); `saas_gateway_pagamento.access_token/client_secret/oauth_token`; `loja_virtual.token_api`; `email_de_contato.password`.
- **Correção:** novo `app/service/seguranca/Segredo.php` (AES-256-GCM / XChaCha20, chave num ficheiro **fora da raiz web e fora da BD**, 0600, criada na 1.ª utilização). Cifra/decifra transparente por ganchos `onBeforeStore`/`onAfterLoad(+Collection)` nos 5 modelos; `MoloniService` (SQL direto) decifra ao usar e cifra o token ao gravar. Os formulários mostram «•••• definida» e só gravam quando se escreve um valor novo (SaasConfiguracao, SaasGatewayPagamento, Moloni, e-mail por departamento). Marcador `enc:v1:`; valores antigos continuam legíveis até à migração.
- **Migração:** `seguranca_v37.php --cifrar` (cópia de segurança + `--repor`). Verificado: em repouso fica `enc:v1:…`, decifra devolve o valor, e o re-gravar mantém cifrado. Prova: `sec_segredos_repouso.png`.

### R4 — Palavra-passe / 2FA mostrados numa lista de utilizadores
- **Onde:** `app/control/recursos_humanos/SystemUsersFormList.php` — colunas `password` e `two_factor_secret` na grelha.
- **Correção:** colunas removidas (nunca aparecem no ecrã). `email_de_contato` já mascara a palavra-passe («••••••••»).

## O que está BEM (confirmado)
- **Palavras-passe:** todos os caminhos que definem palavra-passe usam `password_hash` (bcrypt): registo/`AccountService`, signup da app (via AccountService), `SystemUserForm`/`SystemProfileForm`/`SaasUsuarioForm`/`FuncionarioUsuarioService`, reposição (`ResetSenhaForm`, já corrigido na ronda anterior). O login converte MD5→bcrypt no 1.º acesso. **Nenhum md5/plain a gravar.** Relatório CLI (conta, nunca mostra) incluído no `seguranca_v37.php`.
- **API da app (`AppApiController`):** já usa `condEmpresa()` (empresa+filial) nas consultas de clientes/viaturas/orçamentos; corrigidas 2 consultas que faltavam (`comercialEtapas` e a ligação cliente↔e-mail em `clienteMensagem`).
- **Demo-data:** `popular_demo.php` e `demo_extra_v37.php` recusam a Veloster (por nome e `account_id=3`) e só inserem dados fictícios (@exemplo.pt); nunca copiam dados reais.
- **Tabelas universais** (legitimamente partilhadas): `grupo_pessoa`, `tipo_pessoa`, `tipo_id_fiscal`, países/concelhos/distritos, `marca_viatura`, `forma_pagamento`, `conta_grupo` global (tenant nulo) — mantidas sem filtro; `SystemGroup` continua partilhado com o controlo próprio de `SystemGroupTenantService`.

## Precisa de decisão / ação do Diego (produção)
1. **Correr a migração** `php seguranca_v37.php --cifrar` **uma vez** depois de instalar o pack (gera chave + cópia de segurança). Guardar a cópia fora da web e **fazer backup da chave** `/home/goauto/.goauto_chave_segredos` (sem ela os segredos não se decifram). **Sem chave** a migração não arranca; o `email_password` etc. ficam ilegíveis se a chave se perder → teria de voltar a introduzir os segredos.
2. Confirmar o `account_id` real da **Veloster** (o guard dos scripts de demo assume `=3` + nome); se for outro, ajustar.
3. (Opcional) `seguranca_v37.php --forcar-reset` obriga utilizadores ainda em MD5/texto a redefinir a palavra-passe — **não correr sem avisar os utilizadores**.
4. SQL em produção: **só** o `--cifrar` altera dados (converte os segredos em claro para `enc:v1:…`, com `--repor` para desfazer). O isolamento, pesquisas e colunas são **só código** (sem alterações de esquema).

### Ronda 2026-10-17 — correções pedidas pelo revisor independente (reteste)
- **B1** SaasConfiguracaoForm: a correção «em branco = mantém» não tinha ficado gravada → gravar apagava `email_password` e os 3 `token_integra_notas*`. Corrigido (onSave, também via onTestarEnvioEmail) + segredos nunca devolvidos ao navegador (depois de gravar e no erro); idem SaasGatewayPagamentoForm. EmailDepartamento/EmailDeContato/Moloni já mantinham. Reteste: SIM.
- **B2** Segredo: caminho ÚNICO da chave (GOAUTO_KEY_FILE → application.ini `chave_segredos` → dirname(PATH)/.goauto_chave_segredos); chave existente ilegível/tamanho errado → ERRO, nunca se gera outra; criação só se não existir (fopen 'x', 0600). Decifra falhada → o modelo fica com o CIFRADO (nunca vazio). Reteste: SIM.
- **B4** Contexto de administração nos serviços de pesquisa: o ecrã de ORIGEM vai assinado (HMAC) no pedido; pedidos a serviços sem origem verificada nunca contam como administração. Reteste: admin+origem admin vê todas as empresas; admin+origem normal / utilizador normal / origem trocada → só a própria ou recusado.
- **SF1** Botão de procura: assinatura com os parâmetros FINAIS no TSeekButton::show() (inclui critério, máscara, campos, ecrã de origem). Critério/campo trocado → recusado.
- **SF2/SF3** seguranca_v37.php: `--criar-chave`, `--decifrar-tudo`, `--verificar`, `--copia-dir`; cópia escrita e CONFIRMADA antes de qualquer UPDATE, nunca dentro do site; `--cifrar` recusa sem chave válida; tudo em transação; códigos de saída 0/1/2.
- **SF5** Viatura sem dono/de outra empresa: getters de Orcamento/Tercerizacao degradam para objeto vazio; `--verificar` conta casos (sai 2).
- **SF6** LoginForm: limpa account_id/tenant_id/userunitid(s) e o estado do TenantScope no início do login.
- **SF7** ContaGrupo*/GrupoProduto* = ecrãs do administrador da plataforma; grupos novos criados aí ficam PARTILHADOS (tenant_id e create_unit nulos); empresas veem-nos mas não os alteram. Filtros manuais errados (`tenant_id = userunitid`) substituídos pela regra central.
- **SF12** API: cliente pelo e-mail dentro da EMPRESA (não só da filial).
- PT-PT: «Salvar»→«Gravar», «Registro salvo»→«Registo gravado» (SaasConfiguracaoForm, EmailDeContatoForm, SystemUsersForm, SystemUsersFormList).

---

## Ronda 2026-10-17 (tarde) — Tabelas partilhadas apagadas ao eliminar uma conta (Paulo · revisão de código)

### R5 — ALTO — `grupo_pessoa` e `tipo_id_fiscal` vazias em produção (44 entidades sem grupo)
- **O que é:** as tabelas de referência partilhadas (grupos de entidades, tipos de documento, …) guardam no `tenant_id` a conta que **criou** a linha, mas todas as empresas as usam. As linhas de `grupo_pessoa` (11) e `tipo_id_fiscal` (18) tinham `tenant_id = 4`; quando a conta 4 foi removida, as linhas foram removidas com ela e as fichas das outras empresas (incluindo a conta 3, cliente real) ficaram a apontar para grupos/tipos inexistentes.
- **Causa exata (quem apagou):** **não foi o ecrã de contas**, foi o script de limpeza da base de produção preparado a 14/10/2026: `/home/claude/dbwork/limpeza_producao.sql` (cópias em `dbwork/handoff/` e `dbwork/pacote/`; gerado por `dbwork/gerar_limpeza.py`, que trata TODAS as tabelas com `tenant_id` como «da empresa»):
  - linha 7 `SET FOREIGN_KEY_CHECKS=0;` (desliga a proteção que teria impedido o apagamento);
  - linha 69 `DELETE FROM grupo_pessoa WHERE tenant_id … NOT IN (1,3)`; linha 140 idem `tipo_id_fiscal`; linha 145 idem `tipo_pessoa`;
  - linha 151 `DELETE FROM account WHERE id NOT IN (1,3)` (remove a conta 4).
  - Confirmado com a cópia de produção de 14/10 (`dbwork/base_producao.sql`): `grupo_pessoa` 11/11 linhas com tenant 4, `tipo_id_fiscal` 18/18 com tenant 4, `tipo_pessoa` 2/2 com tenant 3; 41 fichas `pessoa` da conta 3 e 16 `id_fiscal` usavam essas linhas. Nas outras tabelas partilhadas não havia linhas de contas removidas (só tenant 1 ou vazio); `grupo_produto` tinha 3 linhas de tenant 4 usadas só pela própria conta 4 (dados dela → corretamente removidas).
- **Caminho do ecrã (testado):** `app/control/saas_admin/AccountList.php:227` `$object->delete()` → `lib/adianti/database/TRecord.php:1657` `delete()` apaga **só** a linha `account` (não há cascata no código nem `ON DELETE CASCADE` no esquema). Em produção (MariaDB) a FK `fk_grupo_pessoa_tenant_id` (RESTRICT) **recusaria** a eliminação; na réplica SQLite (sem FKs) a conta é apagada e as linhas partilhadas ficam **órfãs** com `tenant_id` de uma conta inexistente — uma mina para a próxima limpeza «por empresa». Outros caminhos revistos sem apagamento de partilhadas: `DatabaseTenantUnitRepairService`, `SystemUserTenantService::removeFromCurrentAccount`, `popular_demo.php` (apaga por id registado; `demoOrfaos` exclui FKs para account/system_unit/system_users), `purgar_veloster.py` (já exclui as 3 universais; só cópias locais).
- **Risco de negócio:** fichas de clientes/fornecedores/parceiros sem grupo; listas, filtros e relatórios por grupo errados; documentos fiscais sem tipo. Qualquer nova limpeza ou eliminação de conta repetiria o problema (`tipo_pessoa` está com tenant 3 = conta de cliente real).
- **Correção (réplica, commit `0aa811c` em `/root/work/demo/site2`):**
  - `app/service/seguranca/TenantScope.php` — `PARTILHADAS` (19 classes: GrupoPessoa, TipoIdFiscal, TipoPessoa, ContaClassificacao, ContaTipo, TipoMov, MotivoMov, StatusFopa, StatusFrequencia, StatusLogistica, StatusFollowTercerizacao, TipoInventario, TipoIntervencao, FormaPagamento, Banco, TipoMorada, TipoContato, DocumentosVeiculares, ImpostosCompras). Critério: estão em `TRecord::$globalTables` (sem filtro de empresa → todas as empresas as usam) e têm `tenant_id`. **Fora, de propósito:** GrupoProduto e ContaGrupo (`PARTILHADO_OU_PROPRIO`: com tenant_id a linha É da empresa), SystemUsers/SystemUnit/SaasContrato/Account (`POR_CONTA`), StatusEntrega (tabela não existe na réplica nem em produção; tem `orcamento_id` → seria dado de empresa).
  - `TenantScope::libertarPartilhadas($conta, $destino)` — **decisão: libertar, não bloquear.** As linhas passam a partilhadas (`tenant_id`, `create_unit`, `create_user`, `update_user` a NULL, conforme a coluna aceite vazio). Se `tenant_id` não aceitar vazio (produção: `banco`, `tipo_intervencao`, `documentos_veiculares`), passa para a conta da plataforma que está a eliminar; sem destino válido, **bloqueia** com mensagem clara. Mesma transação → se a eliminação falhar, tudo volta atrás. Bloquear sempre levaria a «resolver por SQL» — exatamente o que causou o incidente.
  - `app/model/Account.php` — `onBeforeDelete()` chama a libertação só quando a eliminação vai mesmo acontecer (mesma regra do TenantScope para `Account`).
  - Dados da própria empresa: comportamento **inalterado**.
- **Confirma-se (feito, cópia SQLite no scratchpad, dados fictícios, mesmo caminho do ecrã `AccountList::onDelete`):**
  - ANTES: conta apagada; `grupo_pessoa`/`tipo_id_fiscal`/`tipo_pessoa`/`banco` ficam com `tenant_id` da conta apagada (órfãs).
  - DEPOIS (admin da plataforma): conta apagada; as 3 partilhadas com `tenant_id/create_unit/create_user` NULL; `banco` (tenant_id obrigatório) passa para a conta 1; `grupo_produto` e `pessoa` da empresa iguais a antes; ficha de outra empresa continua a apontar para o grupo, que existe.
  - Utilizador comum de outra conta: nada é libertado e a conta não é apagada.
  - Sem destino válido: bloqueia e a transação reverte (grupo_pessoa mantém-se).
  - Verificação: todas as classes globais com `tenant_id` estão classificadas. `php -l` OK nos 2 ficheiros.
  - Não testado: o ramo MariaDB de `colunasAnulaveis` (information_schema) — sem MariaDB no ambiente; confirmar no teste de fumo de produção.
- **Recomendações (decisão do Diego / Vítor):**
  1. Marcar `dbwork/limpeza_producao.sql` (e cópias em `handoff/`, `pacote/`) como **OBSOLETO / NÃO REUTILIZAR**; qualquer limpeza futura exclui as 19 tabelas partilhadas (ou corre antes `UPDATE <tabela> SET tenant_id = NULL WHERE tenant_id NOT IN (<contas a manter>)`) e **nunca** usa `FOREIGN_KEY_CHECKS=0`.
  2. Em produção, passar as linhas partilhadas que ainda têm dono para partilhadas (ex.: `tipo_pessoa` com tenant 3) — `UPDATE` reversível, só com «sim».
  3. Verificar se `grupo_produto` não tem referências órfãs em produção (as 3 linhas da conta 4 eram só usadas por ela na cópia de 14/10).

## Ronda 2026-10-20 — Planos de cliente com grupos de administração da plataforma (Nádia · auditoria web)

### R6 — CRÍTICO (condicional) — Empresas cliente podem ficar com os ecrãs de administração da PLATAFORMA
- **O que é:** `saas_plano_grupo` liga os planos de cliente a grupos de permissões. STANDARD e TRIAL incluem «Cadastros SAAS»; ENTERPRISE inclui «SaaS Admin»; PREMIUM inclui os dois. Na réplica, **todos os grupos antigos** (Standard, CRM, FINANCEIRO, Minha Conta, «SaaS Admin», «Cadastros SAAS»…, 436 ecrãs cada) incluem os ecrãs da plataforma: contas (`AccountList/Form`), contratos, planos (`SaasPlanoForm`), **gateways de pagamento** (`SaasGatewayPagamentoForm`), **configuração da plataforma** (`SaasConfiguracaoForm`), pagamentos, utilizadores/grupos do sistema, logs. Só os perfis novos (ADM/Direção/Supervisor) estão limpos.
- **Onde:** `app/service/AccountService.php` (`startInterno`, cópia dos grupos do plano para o responsável) e `app/service/SaasContratoService.php` (`ativarContrato`, chamado por `SaasPagamentoService` na compra/renovação) copiam os grupos do plano para o utilizador **quando o perfil Direção não existe** (caminho antigo, anterior ao RH passo 2 de 09/10). `PerfilAcessoService::carregar` (login) aceita qualquer grupo global ≠ 1 que o utilizador tenha e usa os grupos do plano como **teto** — teto que, com estes grupos, é «tudo» (437 ecrãs).
- **Hoje, com o perfil Direção instalado:** conta nova → responsável só com Direção → **sem** ecrãs da plataforma (testado). O risco real está nos utilizadores de clientes que **herdaram** grupos antigos (contas criadas/ativadas antes de 09/10, ou instalação sem Direção): esses entram com os ecrãs da plataforma.
- **O que um atacante (cliente nesses planos, com grupo herdado) faria — testado na cópia:** abre e **grava** planos (preços e grupos dos planos de todos os clientes), gateways de pagamento da plataforma (pode trocar a conta que recebe os pagamentos) e a configuração da plataforma (SMTP, plano de experiência, etc.); abre a lista de contas/contratos/utilizadores (o TenantScope da R1 limita estas três à própria empresa). Painel SQL / explorador de BD / phpinfo já estão bloqueados (403, «ferramenta desligada»).
- **Risco de negócio:** um cliente pagante pode mexer na faturação e nos preços da plataforma inteira, desviar pagamentos e alterar o que os outros clientes recebem — perda de receita, fraude e quebra de confiança.
- **Dono da plataforma:** o utilizador n.º 1 / login admin tira os acessos **dos seus próprios grupos** (`system_user_group`: Admin, ADMIN - ACESSO TOTAL, SaaS Admin, Cadastros SAAS, …) pelo ramo de administrador de `carregar`, **sem teto do plano**. Retirar os grupos dos planos **não** lhe tira nada (confirmado: 717 ecrãs antes e depois). Os outros utilizadores da conta 1 também ficam iguais (teto da conta 1 preservado no contrato).
- **Correção (código, commit `96c6458` em `/root/work/demo/site2`, `php -l` OK):**
  - `SystemGroupTenantService`: `contaDaPlataforma()` (conta do utilizador n.º 1/admin), `ecraDaPlataforma()` (lista `ADMIN_PROGRAM_CONTROLLERS` + prefixos Saas/System/Account/Permission, menos `ECRAS_CLIENTE_PERMITIDOS`: assinatura própria, filiais, utilizadores da empresa, mensagens, perfil), `gruposProibidosParaConta()`, `filtrarGruposParaConta()`.
  - `PerfilAcessoService::carregar`: utilizador de conta ≠ plataforma perde no login **qualquer** ecrã da plataforma, venha de que grupo vier (fecha também os grupos antigos herdados).
  - `AccountService::start` e `SaasContratoService::ativarContrato`: grupos de administração nunca são copiados do plano para conta de cliente.
  - `SearchInputBox`: a pesquisa só sugere ecrãs que a sessão pode abrir.
- **Correção (dados):** `/root/work/pack/v39/src/planos_sem_admin_v39.php` `--ver | --aplicar | --desfazer=<json>` (`--site=`, `--copia-dir=` fora do site, cópia JSON 0600 confirmada ANTES de alterar; uma transação; só contagens). Retira «SaaS Admin»/«Cadastros SAAS» de todos os planos, dos contratos de clientes e dos utilizadores de clientes (incl. ligações órfãs); passa-os para o **contrato** da conta da plataforma (o dono não perde nada); nunca toca no utilizador n.º 1/admin nem na conta da plataforma; confirma no fim e reverte se algo não bater certo.
- **Confirma-se (feito, cópia SQLite no scratchpad, empresas fictícias, servidor privado 127.0.0.1:8796, login local):**
  - ANTES: empresa A (caminho atual) → só Direção, 0 ecrãs da plataforma. Empresa B (caminho antigo, PREMIUM via `ativarContrato`) → herdou «SaaS Admin» + «Cadastros SAAS» + grupos antigos → 447 ecrãs, 53 da plataforma; HTTP 200 em AccountList, SaasContratoList, SaasPlanoHeaderList, SaasGatewayPagamentoHeaderList, SaasConfiguracaoForm, SystemUsersFormList, SaasPagamentoList; `onSave` permitido em gateways, planos e configuração.
  - Só dados corrigidos (código antigo): B **continua** com 53 ecrãs da plataforma (os outros grupos antigos também os têm) → o script sozinho não fecha; o código é obrigatório.
  - DEPOIS (código + dados): B → 0 ecrãs da plataforma, HTTP 401 em todos; A igual (128); dono igual (717, 65 da plataforma, HTTP 200); utilizadores da conta 1 iguais (112/128). Conta nova pelo caminho antigo com o código novo → não recebe grupos de administração.
  - Script: `--ver` não altera; `--copia-dir` dentro do site → recusa (exit 1, base intacta); `--aplicar` → `--desfazer` → tabelas `saas_plano_grupo`, `saas_contrato_grupo`, `system_user_group`, `system_group(_program)`, `saas_plano` **iguais** ao original; 2.ª aplicação → «Nada a alterar».
- **Nota lateral (Pendente):** `engine.php:60-61` tem um desvio de permissões ativado pelo ficheiro `app/config/.allow_rec` («gravação local»). Existe e está no git da réplica; o pack exclui `app/config/*` (não segue para produção). Confirmar que **não existe** em produção e retirar o ramo do `engine.php` quando as gravações acabarem.
