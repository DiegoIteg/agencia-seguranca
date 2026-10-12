# Auditoria Web — Controlo de Acessos e Entrada (Go Auto / ERP Adianti-MadBuilder)

**Auditora:** Nádia (Auditoria Web e APIs) · **Projeto:** Go Auto · **Data:** 2026-10-12
**Âmbito:** código em `/root/work/itest` (PHP 8.3, framework Adianti/MadBuilder). Auditoria **defensiva, só leitura**.
**Nota de segredos:** nenhum valor de palavra-passe, chave, token ou segredo é transcrito; referem-se sempre pelo **ficheiro e linha**.

---

## Resumo executivo (contagem por gravidade)

| Gravidade | N.º |
| :--- | :---: |
| **Crítico** | 2 |
| **Alto** | 4 |
| **Médio** | 6 |
| **Baixo** | 3 |

**Veredicto:** **NÃO pronto para comercialização** sem corrigir os achados Críticos e Altos. O "portão" central de permissões (`engine.php`) está, na sua essência, bem feito — mas existem **portas laterais que o contornam por completo** (sobretudo `preview_ecra.php`) e **bases de dados/ferramentas de programador expostas**. A API móvel e o registo público (`cadastrar.php`) estão, no geral, bem protegidos.

---

## CRÍTICO

### C1 — `preview_ecra.php`: execução de qualquer ecrã **sem login** e com sessão de administrador forjada
- **O que é:** o ficheiro `preview_ecra.php` não verifica login nenhum. Pelo contrário, **cria uma sessão autenticada e privilegiada** (define `login='diego'`, `userid=7`, `account_id=1`, `tenant_id=1`) e a seguir faz `new $classe($_GET)` e invoca `$_GET['method']` sobre o objeto. Ou seja, qualquer visitante da Internet escolhe a classe e o método a executar.
- **Onde:** `preview_ecra.php`, linhas 282–287 (`TSession::setValue(...)` com dados de sessão + `new $classe($_GET); $o->$metodo($_GET); $o->show();`).
- **O que um atacante faria:** chamar, sem credenciais, `preview_ecra.php?class=SystemUserList` (listar utilizadores), `class=SystemSQLPanel&method=onGenerate&...` (ler a base de dados), ou qualquer controlador de negócio com `method=onDelete&id=...` — tudo **contornando o portão de permissões do `engine.php`** e agindo como a empresa/tenant 1.
- **Risco de negócio:** fuga total de dados de clientes e **ações destrutivas** sem autenticação. Incidente RGPD grave; incompatível com comercialização.
- **Como se corrige:** **remover `preview_ecra.php` do servidor** (é um utilitário local de capturas de ecrã). Se tiver mesmo de existir, trancar a CLI/`127.0.0.1` e exigir login real — nunca forjar sessão.
- **Como se confirma que fechou:** `GET preview_ecra.php?class=SystemUserList` devolve 403/404 (ficheiro inexistente) e não renderiza nada.

### C2 — Bases de dados SQLite dentro da raiz web, **sem bloqueio HTTP**
- **O que é:** a configuração aponta a base principal e a de permissões para ficheiros **SQLite dentro da raiz pública**: `test.db` (≈1,4 MB), `log.db`, `communication.db`. O `.htaccess` da raiz **não bloqueia** o acesso a estes ficheiros (o `.htaccess` de `app/config/` protege a pasta de configuração, mas não a raiz).
- **Onde:** `app/config/iteg.php` e `app/config/permission.php` (`'name'=>'/root/work/itest/test.db','type'=>'sqlite'`); `app/config/log.php`; `app/config/communication.php`; `.htaccess` da raiz (sem regra `Deny`/`FilesMatch` para `*.db`).
- **O que um atacante faria:** `GET https://<servidor>/test.db` e descarregar **toda a base de dados** — utilizadores, hashes de palavra-passe, dados de todos os tenants.
- **Risco de negócio:** comprometimento total e silencioso. Catástrofe RGPD.
- **Como se corrige:** (1) **mover as bases para fora da raiz web**; (2) adicionar ao `.htaccess` da raiz um bloqueio a `*.db`, `*.sql`, `*.ini`, `*.log`; (3) confirmar qual a base de **produção** — se for MySQL, continuar a remover os `.db` de teste do diretório publicado.
- **Como se confirma que fechou:** `GET /test.db`, `/log.db`, `/communication.db` devolvem 403/404; os ficheiros já não existem no diretório servido.

---

## ALTO

### A1 — Instalador acessível e protegido por **token fixo no código**
- **O que é:** as classes de instalação (`DatabaseInstall`, `ExtensionsInstall`, `PathInstall`, `SummaryDatabaseInstall`, `SystemModulesCheckView`) estão em `public_classes` (acesso **sem login**) e `install.php` está acessível. A "senha" do instalador é um **token escrito diretamente no código-fonte**, comparado com `==` (não `hash_equals`). Além disso, a salvaguarda de "já instalado" está **desligada** (o `install.ini` não tem `installed = 1`).
- **Onde:** `app/config/application.ini` secção `[permission]` (linhas 62–68, `public_classes[]`); `install.php`; `app/control/install/DatabaseInstall.class.php` linha 1397 (`verifyToken`, comparação com literal) e linha 1408 (`verifyLogged`); `app/config/install.ini` (sem chave `installed`).
- **O que um atacante faria:** quem conheça/adivinhe esse token (está no código e é um prefixo do token do projeto, também embebido no HTML servido por `db-mad-manager.php`) autentica-se no instalador e **reaponta a aplicação para outra base de dados** ou recria utilizadores administradores.
- **Risco de negócio:** tomada de controlo da instalação; indisponibilidade e fraude.
- **Como se corrige:** remover `install.php` e as classes de instalação do servidor de produção (ou tirá-las de `public_classes`); colocar `installed = 1` no `install.ini`; nunca usar segredos fixos no código — usar valor forte em configuração protegida e `hash_equals`.
- **Como se confirma que fechou:** `GET install.php` e `index.php?class=DatabaseInstall` devolvem "Permission denied"/404.

### A2 — Injeção de SQL nas ferramentas de dados (`SystemDataBrowser`, `SystemTableList`)
- **O que é:** o nome da tabela e da base vêm do pedido (`$param['table']`, `$param['database']`) e são **concatenados diretamente** na instrução SQL, sem validação nem escape.
- **Onde:** `app/control/admin/SystemDataBrowser.php` linha 109 (`"... FROM {$table} ".$where_string`) e linhas 103/117; `app/control/admin/SystemTableList.php` linhas 109/119 e 192/210 (exportações CSV/SQL).
- **O que um atacante faria:** manipular o parâmetro `table` para injetar SQL e ler/alterar dados fora do previsto. Isolado, exige a permissão desta ferramenta; **combinado com o C1 (`preview_ecra.php`), torna-se injeção de SQL sem autenticação**.
- **Risco de negócio:** leitura/alteração de dados de qualquer tenant.
- **Como se corrige:** validar o nome da tabela contra a lista real de tabelas da ligação (lista branca) e usar sempre os construtores de query do framework; nunca concatenar identificadores vindos do pedido.
- **Como se confirma que fechou:** um `table` com caracteres de injeção é rejeitado; teste de regressão com payload conhecido não devolve dados extra.

### A3 — Token da app móvel (JWT) **nunca expira**
- **O que é:** o token da app guarda a validade no campo `expires`, mas a biblioteca JWT só valida o campo-padrão `exp` — e o código **nunca verifica `expires` manualmente**. Logo, a "validade de 3 horas" é apenas decorativa: o token é eterno. O token também é aceite via **query string** (`?token=`).
- **Onde:** `app/controller/AppApiController.php` linha 44 (`'expires' => strtotime('+ 3 hours')`) e método `tokenPayload` linhas 16–33 (decode sem verificar `expires`; aceitação por `?token=` na linha 28).
- **O que um atacante faria:** reutilizar indefinidamente um token capturado (p. ex. apanhado num log de servidor/proxy por vir no endereço), mantendo acesso aos dados da empresa muito depois de o colaborador sair.
- **Risco de negócio:** acesso persistente não revogável; fuga de dados de negócio.
- **Como se corrige:** usar o campo-padrão `exp` (validado automaticamente) **ou** verificar `expires` à mão e recusar tokens vencidos; deixar de aceitar o token por query string (só cabeçalho); permitir revogação (mudança de `seed`/versão de chave).
- **Como se confirma que fechou:** um token com mais de 3 horas devolve 401 nos endpoints `/api/app/*`.

### A4 — Webhooks de pagamento **sem verificação de assinatura**
- **O que é:** `stripe_webhook.php` valida corretamente a assinatura HMAC do Stripe. Mas `hook_inter.php` (Banco Inter) e `retorno_mercado_pago.php` (Mercado Pago) aceitam POST **não autenticado** e agem sobre o estado de pagamentos/assinaturas.
- **Onde:** `hook_inter.php` (sem validação de origem; além disso usa `$service` indefinido — linha 408 — e está funcionalmente partido); `retorno_mercado_pago.php` (sem assinatura; reconfirma via API do Mercado Pago, o que **atenua** mas não dispensa a validação; regista `$request` indefinido na linha 559).
- **O que um atacante faria:** forjar notificações de "pagamento recebido"/"assinatura ativa" para obter o serviço SaaS sem pagar, ou poluir os registos de webhook.
- **Risco de negócio:** perda de receita e registos financeiros não fiáveis.
- **Como se corrige:** validar a autenticidade de cada webhook (assinatura/segredo do gateway) como já é feito no Stripe; confirmar sempre o estado do lado do gateway antes de ativar; corrigir os bugs (`$service`, `$request`).
- **Como se confirma que fechou:** um POST forjado para `hook_inter.php`/`retorno_mercado_pago.php` é rejeitado e não altera o estado de nenhuma assinatura.

---

## MÉDIO

### M1 — Ferramentas de programador presentes em produção
- **O que é:** o sistema inclui ferramentas poderosas: `SystemSQLPanel` (SELECT arbitrário sobre qualquer ligação/tenant), `SystemDatabaseExplorer`, `SystemDataBrowser`, `SystemTableList`, `SystemDataImportForm`, `SystemPHPInfoView`, e o `db-mad-manager.php` (SQL arbitrário, criar/apagar tabelas via API). O `.htaccess` até cria rotas amigáveis para elas.
- **Onde:** `app/control/admin/System*.php`; `db-mad-manager.php`; `app/routes/api.php` linhas 6–27; `.htaccess` linhas 51–61.
- **Nota de controlo de acessos:** o portão de `engine.php` (`programs[$class]`) protege estas classes para quem **não** as tenha no perfil, e a API `db-mad-manager` está bem restringida a `login === 'admin'` (middleware `BuilderAdminAuth`). O risco é **existirem** em produção: bastam um perfil mal atribuído, o phishing do administrador, ou o desvio do C1 para se tornarem catastróficas.
- **O que um atacante faria:** com a conta `admin` comprometida (ou via C1), ler/alterar toda a base de dados e ver o `phpinfo` (caminhos, versões, segredos de ambiente).
- **Risco de negócio:** amplifica qualquer outra falha até compromisso total.
- **Como se corrige:** remover estas ferramentas e rotas do pacote de produção (ou protegê-las por IP/VPN de gestão e confirmar que não constam de nenhum perfil de cliente); nunca expor `phpinfo`.
- **Como se confirma que fechou:** as rotas `system-sqlpanel`, `system-phpinfo`, `system-database-explorer` devolvem 404/Permission denied para qualquer perfil de cliente.

### M2 — CORS totalmente aberto na API REST
- **O que é:** o servidor REST responde com `Access-Control-Allow-Origin: *` e `Access-Control-Allow-Headers: *`.
- **Onde:** `MadRestServer.php` linhas 3–4.
- **O que um atacante faria:** fazer qualquer site chamar a API a partir do navegador da vítima (exfiltração/abuso facilitado, sobretudo combinado com tokens que não expiram — A3).
- **Risco de negócio:** exposição da API a páginas de terceiros.
- **Como se corrige:** restringir a origem a domínios conhecidos (como já faz `mobile.php`, que limita a um domínio concreto) e listar só os cabeçalhos necessários.
- **Como se confirma que fechou:** a resposta de pré-verificação (OPTIONS) só devolve `Allow-Origin` para os domínios permitidos.

### M3 — Login sem bloqueio por tentativas (força-bruta)
- **O que é:** o login não tem contador de tentativas nem bloqueio temporário de conta; a defesa resume-se a um `sleep(2)` por falha e a um reCAPTCHA **opcional** (depende de uma preferência estar ligada).
- **Onde:** `app/control/admin/LoginForm.php` (`onLogin`, `sleep(2)` na linha 361; reCAPTCHA condicional nas linhas 106/380); `app/service/auth/ApplicationAuthenticationService.php` (`authenticate`, sem throttle).
- **O que um atacante faria:** tentar milhares de palavras-passe contra contas conhecidas (ex.: `admin`), sobretudo se o reCAPTCHA estiver desligado.
- **Risco de negócio:** tomada de contas por adivinhação de palavra-passe.
- **Como se corrige:** bloqueio progressivo por conta/IP após N falhas; tornar o CAPTCHA obrigatório; alertar o utilizador por e-mail em acessos suspeitos.
- **Como se confirma que fechou:** após N tentativas falhadas a conta/IP fica temporariamente bloqueada.

### M4 — `download.php`: leitura de ficheiros sem âmbito de tenant e com caminho controlado
- **O que é:** entrega o ficheiro indicado em `$_GET['file']` a qualquer utilizador autenticado, sem restringir a pasta nem o tenant; o caminho é escolhido pelo cliente (há travessia de diretórios, embora limitada às extensões permitidas).
- **Onde:** `download.php` linhas 5–53 (`$file = $_GET['file']; ... echo file_get_contents($file);`).
- **O que um atacante faria:** ler documentos de **outras empresas/tenants** (IDOR) e quaisquer ficheiros do servidor com extensão permitida (csv, xml, zip, pdf, txt…), ex.: cópias de segurança.
- **Risco de negócio:** fuga de documentos entre clientes; incidente RGPD.
- **Como se corrige:** servir apenas por um identificador de documento validado contra o tenant do utilizador; resolver o caminho dentro de uma pasta base e rejeitar `..`/caminhos absolutos.
- **Como se confirma que fechou:** pedir o ficheiro de outro tenant devolve 403; um caminho com `..` é recusado.

### M5 — RPC genérico via `rest.php` / `mobile.php` com chave estática
- **O que é:** estes pontos permitem executar **qualquer classe::método** da aplicação desde que o pedido traga a `rest_key` (Basic) ou um token válido. A `rest_key` é um segredo estático e de longa duração guardado em configuração.
- **Onde:** `rest.php` linhas 29–53; `mobile.php` linhas 330–353; chave em `app/config/application.ini` secção `[general]` (`rest_key`, linha 21 — valor não transcrito).
- **O que um atacante faria:** com a chave, aceder a uma superfície enorme (não só os endpoints da app). Se a chave vazar (ex.: por C2/M4), compromete a API inteira.
- **Risco de negócio:** exposição ampla caso o segredo vaze.
- **Como se corrige:** limitar por rota as classes/métodos invocáveis; rodar a `rest_key` periodicamente e guardá-la fora da raiz; preferir tokens por utilizador com expiração.
- **Como se confirma que fechou:** chamar uma classe fora da lista permitida pela API devolve erro de autorização.

### M6 — Grupo `/api/*` sem middleware no router (confiança na verificação interna)
- **O que é:** o grupo de rotas `/api` (todos os `/app/*`) **não declara middleware** no router; a autenticação depende de cada método chamar `tokenPayload()`. Hoje os métodos verificam o token e aplicam o âmbito por empresa/filial (bom), mas basta um método novo esquecer essa verificação para ficar aberto.
- **Onde:** `app/routes/api.php` linhas 29–74 (grupo sem `middleware`); verificação feita caso a caso em `app/controller/AppApiController.php`.
- **O que um atacante faria:** explorar um futuro endpoint que se esqueça do `tokenPayload()`.
- **Risco de negócio:** falha latente à medida que a API cresce.
- **Como se corrige:** aplicar um middleware de autenticação ao grupo `/api` (exceto `login`/`signup`), deixando a verificação central e obrigatória.
- **Como se confirma que fechou:** qualquer rota `/app/*` (menos login/signup) sem token válido devolve 401 por omissão.

---

## BAIXO

### B1 — Sem Content-Security-Policy
- **O que é:** o `init.php` define bons cabeçalhos de segurança (X-Content-Type-Options, X-Frame-Options, Referrer-Policy, HSTS), mas **não há CSP**, o que reduziria o impacto de um eventual XSS.
- **Onde:** `init.php` linhas 13–22.
- **Como se corrige:** adicionar uma CSP adequada ao tema do ERP. **Como se confirma:** a resposta inclui `Content-Security-Policy`.

### B2 — Token JWT aceite na query string
- **O que é:** `tokenPayload` aceita o token por `?token=` (fica em logs/histórico/proxies).
- **Onde:** `app/controller/AppApiController.php` linha 28. (Relacionado com A3.)
- **Como se corrige:** aceitar o token só por cabeçalho. **Como se confirma:** `?token=` deixa de autenticar.

### B3 — Bugs de fiabilidade nos webhooks
- **O que é:** `hook_inter.php` usa `$service` indefinido (linha 408) e `retorno_mercado_pago.php` regista `$request` indefinido (linha 559) — o registo do webhook fica vazio e o fluxo do Inter está partido.
- **Onde:** `hook_inter.php` linha 408; `retorno_mercado_pago.php` linha 559.
- **Como se corrige:** corrigir as variáveis e cobrir com testes. **Como se confirma:** o payload do webhook é registado corretamente e o fluxo do Inter funciona. (Ver também A4.)

---

## O que está BEM (para não mexer)
- **Portão central de permissões** em `engine.php` (`TApplication::run`): exige login + `programs[$class]` + verifica `programs_actions` e `PerfilAcessoService::bloqueioGravar`. Sólido.
- **`index.php` não executa controladores** server-side: o `loadPage` apenas emite um redireccionamento JS que volta a passar pelo `engine.php` (o portão aplica-se). Não é, por si só, um desvio.
- **Registo público `cadastrar.php`**: bem protegido — token anti-CSRF, honeypot, CAPTCHA Turnstile, limite de ritmo, força de palavra-passe, atribuição por lista branca e saída escapada.
- **API móvel (`AppApiController`)**: autenticação por JWT em cada endpoint e **âmbito por empresa/filial** nas ações e detalhes de orçamento (ex.: `comercialOrcamentoDetalhe`, `comercialFoto`, `comercialMudarEtapa` filtram por `create_unit`/`tenant_id`) — sem IDOR aparente. Login da app recusa quem não é "utilizador da app"; desserialização com `allowed_classes=false`; sessão regenerada no login (anti-fixation); 2FA (e-mail/Google) suportado. Resta corrigir A3/B2.
- **`db-mad-manager.php`** e as rotas `database-manager` restritas a `login === 'admin'` (middleware `BuilderAdminAuth`).
- **`cmd.php`, `Cron.php`, `repair_tenant_units.php`**: só por linha de comandos (bloqueiam acesso web).
- **`stripe_webhook.php`**: valida a assinatura HMAC.

---

## Prioridade de correção (para o plano do Vítor validar com o Diego)
1. **Hoje:** remover `preview_ecra.php` (C1); tirar os `.db` da raiz e bloquear no `.htaccess` (C2).
2. **Esta semana:** fechar o instalador e o token fixo (A1); corrigir a injeção de SQL (A2); pôr os tokens da app a expirar (A3); validar assinatura dos webhooks Inter/Mercado Pago (A4).
3. **Próximo ciclo:** retirar/trancar as ferramentas de programador (M1); apertar CORS (M2); bloqueio de força-bruta no login (M3); corrigir `download.php` (M4); limitar o RPC e rodar a `rest_key` (M5); middleware no grupo `/api` (M6).
