# Achados — Dados Pessoais, Segredos e RGPD (Go Auto)

**Auditor:** Gonçalo (`dados_e_rgpd`) · **Tipo:** auditoria defensiva autorizada · **Alvo:** ERP Go Auto (PHP 8.3 + Adianti 7.5), código em `/root/work/itest` · **Data:** 2026-10-12 · **Modo:** só leitura, nada alterado.

> **Nota de método:** nenhum valor de segredo (passwords, chaves, tokens) é escrito neste documento. Os segredos referem-se sempre por `ficheiro:linha`. Confirmou-se que a base de dados auditada (`test.db`) é uma **cópia de testes sem registos pessoais reais** (0 linhas em `pessoa`, `funcionario`, `contatos`, `api_matriculas`); os riscos abaixo descrevem o **padrão de implementação** que, em produção, exporia dados reais.

**Resumo por gravidade:** Crítico: 2 · Alto: 3 · Médio: 4 · Baixo: 2

---

## CRÍTICO

### C1 — Bases de dados SQLite servidas diretamente pela Web (raiz do site)
- **O que é:** `test.db` (1,4 MB), `communication.db` e `log.db` estão na raiz do site (que é também a raiz web, com `index.php`). O `.htaccess` da raiz (`/root/work/itest/.htaccess`) só tem regras de *rewrite* com `RewriteCond %{REQUEST_FILENAME} !-f` — ou seja, **quando o ficheiro existe, o Apache serve-o diretamente**. Não existe nenhum bloco `<FilesMatch>`/`<Files>` a negar o acesso web a `.db`, `.ini`, `.sqlite`, `.log`.
- **Onde:** `.htaccess` (raiz, linhas 1-134, sem qualquer `FilesMatch`); ficheiros `test.db`, `communication.db`, `log.db` na raiz; configs em `app/config/iteg.php:2`, `app/config/communication.php:2`, `app/config/log.php:2`, `app/config/permission.php:2` (todos apontam para `.db` na raiz web).
- **O que um atacante faria:** pedir `https://<site>/test.db` e descarregar a base de dados inteira — em produção, toda a tabela `pessoa` (nome, NIF, morada), `funcionario` (NIF, NISS, IBAN, data de nascimento), `contatos` (telefones, e-mail), `faturacao` (incl. segredos Moloni) e as **passwords** dos utilizadores.
- **Risco de negócio / RGPD:** violação de dados pessoais em larga escala (Art. 32.º — segurança do tratamento; Art. 33.º/34.º — notificação de violação à CNPD e aos titulares). Perda total de confidencialidade de clientes, funcionários e credenciais.
- **Correção:** negar por servidor o acesso web a estes ficheiros **e** tirá-los da raiz web. No `.htaccess` da raiz acrescentar `<FilesMatch "\.(db|sqlite|sqlite3|ini|log)$">` com `Require all denied` (Apache 2.4). Melhor ainda: mover `test.db`/`communication.db`/`log.db` para uma pasta **fora** do *document root* e atualizar `app/config/*.php`. Garantir `Options -Indexes`.
- **Verificação:** `curl -I https://<site>/test.db` deve devolver 403/404; repetir para `communication.db`, `log.db` e `app/config/application.ini`.

### C2 — Pasta `tmp/` com PDFs gerados (faturas/documentos) acessível pela Web
- **O que é:** `tmp/` (na raiz web) contém PDFs gerados pela aplicação (faturas, notas, documentos — p.ex. `6ac8b8d4...pdf`, 7 ficheiros observados) e é também para onde o `error_log` escreve (`init.php:25` → `tmp/php_errors.log`). A pasta **não tem `.htaccess`** (só existem `.htaccess` em `/` e em `files/`), pelo que os ficheiros são servidos diretamente.
- **Onde:** `tmp/` (sem `.htaccess`); `init.php:25` (`ini_set('error_log', 'tmp/php_errors.log')`).
- **O que um atacante faria:** aceder a `https://<site>/tmp/php_errors.log` (stack traces, caminhos, possíveis dados em mensagens de erro) e a PDFs se adivinhar/obtiver o nome; se o *directory listing* estiver ligado, listar e descarregar todos os documentos.
- **Risco de negócio / RGPD:** exposição de documentos com dados pessoais (nome, NIF, morada, valores) e fuga de informação técnica via log de erros. Art. 32.º RGPD.
- **Correção:** criar `tmp/.htaccess` com `Require all denied` (como em `files/`); mover o `error_log` para fora do *document root* (caminho absoluto, p.ex. `/var/log/goauto/php_errors.log`); garantir `Options -Indexes` global.
- **Verificação:** `curl -I https://<site>/tmp/php_errors.log` → 403; tentar `https://<site>/tmp/` → sem listagem.

---

## ALTO

### A1 — Segredos em claro no ficheiro de configuração versionado (`application.ini`)
- **O que é:** `application.ini` contém três segredos de aplicação em texto simples (chave de aplicação, *seed* de assinatura e chave da API REST). Apesar de `app/config/.htaccess` negar o acesso web a esta pasta (padrão `AuthUserFile /dev/null` + `require valid-user`), os segredos estão **em claro e, muito provavelmente, no repositório de código** (não há `.gitignore` visível a excluí-los).
- **Onde:** `app/config/application.ini:19`, `:20`, `:21` (valores **não transcritos**).
- **O que um atacante faria:** com a *seed*/token consegue forjar/assinar pedidos e usar a API REST; se o repositório ou um *backup* vazar, os segredos vazam com ele.
- **Risco de negócio / RGPD:** comprometimento da integridade da aplicação e da API; acesso não autorizado a dados pessoais via REST.
- **Correção:** **rodar** os três segredos; movê-los para variáveis de ambiente / ficheiro fora do repositório; garantir que `application.ini` está no `.gitignore` e remover do histórico de Git se lá estiver; manter a negação web da pasta `app/config/`.
- **Verificação:** confirmar novos valores ativos; `git log -- app/config/application.ini` vazio ou ficheiro removido do histórico; `curl -I https://<site>/app/config/application.ini` → 403.

### A2 — `download.php` com *path traversal* (leitura de ficheiros arbitrários)
- **O que é:** `download.php` usa `$_GET['file']` diretamente em `file_get_contents($file)` só com verificação de sessão (`logged`) e *whitelist* de extensões. **Não há restrição a uma pasta base nem bloqueio de `../`**, nem *scoping* por tenant.
- **Onde:** `download.php:5-7`, `:37`, `:52`.
- **O que um atacante faria:** autenticado, pedir `download.php?file=../../../caminho/ficheiro.csv` (ou `.xml`, `.zip`, `.txt`…) para ler ficheiros de outros *tenants* ou do sistema com extensão permitida — incluindo documentos pessoais de outros clientes.
- **Risco de negócio / RGPD:** acesso indevido a dados pessoais de outros clientes/tenants (quebra de minimização e de controlo de acessos, Art. 5.º e 32.º). *Nota: sobrepõe-se à área da Nádia (controlo de acessos/IDOR).*
- **Correção:** validar que o caminho resolvido (`realpath`) fica dentro da pasta de documentos permitida ao *tenant*; recusar `..`; servir apenas por ID de documento com verificação de posse, não por caminho livre.
- **Verificação:** pedido com `../` fora da pasta permitida → negado; utilizador do tenant A não descarrega documento do tenant B.

### A3 — Credenciais e tokens de reposição de senha transmitidos no URL
- **O que é:** a rota de autenticação REST coloca **login e password no caminho do URL** (`^auth/login/password`), e a reposição de senha envia o **JWT no URL**. URLs ficam gravados nos logs de acesso do Apache, no histórico do navegador e em *proxies*. Existe serviço que regista `REQUEST_URI`/`QUERY_STRING` (de momento desligado, mas pronto a ligar).
- **Onde:** `.htaccess:119` (rota `auth/<login>/<password>`); `app/control/saas_admin/EsqueciSenhaForm.php:125` (token no URL); `app/service/log/SystemRequestLogService.class.php:43,45` (regista URI e *query string*); `application.ini:39-41` (`request_log` comentado — desligado por agora).
- **O que um atacante faria:** ler passwords/tokens nos logs do servidor ou no histórico/proxy e reutilizá-los; se o `request_log` for ligado, as credenciais ficam na própria base de dados de logs.
- **Risco de negócio / RGPD:** segredos de autenticação em claro em registos (Art. 32.º); tokens de reposição reutilizáveis.
- **Correção:** autenticação REST por **POST** no corpo (nunca no URL); token de reposição por POST ou de uso único e curta validade; nunca registar `password`/`token` — filtrar a *query string* no `SystemRequestLogService` antes de gravar.
- **Verificação:** login REST deixa de aceitar credenciais no URL; logs sem password/token; reposição falha ao reutilizar token.

---

## MÉDIO

### M1 — Cookie de sessão sem `Secure` / `HttpOnly` / `SameSite`
- **O que é:** `session_start()` é chamado sem `session_set_cookie_params()`; não há configuração de `HttpOnly`, `Secure` nem `SameSite` para o cookie de sessão (`PHPSESSID_erp_auto`).
- **Onde:** `lib/adianti/registry/TSession.php:42,55`; `init.php:55` (define só o nome da sessão).
- **Risco:** roubo do cookie por XSS (sem `HttpOnly`) ou em rede não cifrada (sem `Secure`); CSRF facilitado (sem `SameSite`). Permite sequestro de sessão e acesso a dados pessoais.
- **Correção:** antes do `session_start()`, definir `session_set_cookie_params(['secure'=>true,'httponly'=>true,'samesite'=>'Lax'])` (ou via `php.ini`: `session.cookie_httponly=1`, `session.cookie_secure=1`, `session.cookie_samesite=Lax`).
- **Verificação:** no navegador, o cookie de sessão mostra `HttpOnly`, `Secure`, `SameSite`.

### M2 — Suporte a passwords legadas em MD5 na autenticação
- **O que é:** a autenticação aceita passwords em **MD5** (comparação legada) além de `bcrypt`. As passwords novas são `bcrypt`/`PASSWORD_DEFAULT` (bom) e há *rehash* no login bem-sucedido, mas contas antigas podem continuar em MD5 (rápido de quebrar). Na `test.db` o único utilizador já está em bcrypt.
- **Onde:** `app/model/admin/SystemUsers.php:17077` (MD5), `:17081-17083` (verify + rehash), `:17103` (hash forte). Escrita forte também em `SystemUserForm.php:227`, `SystemProfileForm.php:173`, `AccountService.php:49`, `ResetSenhaForm.php:133`, `SaasUsuarioForm.php:214`.
- **Risco:** credenciais antigas em MD5 facilmente quebráveis se a BD vazar (ver C1) → acesso a dados pessoais. Art. 32.º (ausência de *state of the art* no armazenamento).
- **Correção:** forçar reposição de senha para todas as contas ainda em MD5 e remover o ramo de comparação MD5 após a migração.
- **Verificação:** nenhuma password com 32 hex na BD; login com conta antiga obriga a repor.

### M3 — Fuga de informação técnica: `phpinfo()` e painel SQL acessíveis
- **O que é:** classes de diagnóstico expostas por rota: `SystemPHPInfoView` (chama `phpinfo()`), `SystemSQLPanel`, `SystemDatabaseExplorer`, `SystemPHPErrorLogView`. Não estão nas `public_classes` (exigem login/permissão), mas qualquer sessão com permissão vê ambiente completo e consegue correr SQL.
- **Onde:** `.htaccess:51-58,102-106`; `app/control/admin/SystemPHPInfoView.php:25` (`phpinfo()`).
- **Risco:** divulgação de versões, caminhos, extensões e variáveis de ambiente (facilita ataques); painel SQL permite leitura/escrita direta de dados pessoais.
- **Correção:** restringir estas rotas a administradores de sistema; desativar `SystemPHPInfoView` em produção; registar/limitar o uso do painel SQL.
- **Verificação:** utilizador não-admin recebe 403 nestas rotas; `system-phpinfo` indisponível em produção.

### M4 — Falta de consentimento, retenção e minimização (RGPD organizacional)
- **O que é:** `require_terms = 0` (não há aceitação de termos/consentimento no registo). Não se encontrou mecanismo de **retenção/eliminação** nem de **anonimização** de dados pessoais; existe uma tabela `pessoa_clone_1066726a12e57b614bd` (clone de dados pessoais) sem política visível. O sistema guarda dados sensíveis de RH (NISS, IBAN, data de nascimento, estado civil, dependentes, contacto de emergência).
- **Onde:** `application.ini:12` (`require_terms = 0`); esquema `funcionario` (campos `nif, niss, iban, data_nascimento, estado_civil, dependentes, contacto_emergencia, telefone_emergencia`), `pessoa` (`nif, morada_id, nome`), `contatos`; tabela `pessoa_clone_1066726a12e57b614bd`.
- **Risco:** incumprimento dos princípios do Art. 5.º (limitação da conservação, minimização) e da base legal/consentimento (Art. 6.º/7.º); direito ao apagamento (Art. 17.º) sem meio técnico.
- **Correção:** registar base legal e consentimento quando aplicável; definir prazos de retenção e rotina de eliminação/anonimização; justificar ou remover tabelas-clone; documentar no registo de atividades de tratamento (Art. 30.º).
- **Verificação:** existe política e rotina de retenção; pedido de apagamento executável; clones removidos ou justificados.

---

## BAIXO

### B1 — Sem redirecionamento forçado HTTP→HTTPS; sem `Content-Security-Policy`
- **O que é:** o `init.php` já define bons cabeçalhos (`X-Content-Type-Options`, `X-Frame-Options: SAMEORIGIN`, `Referrer-Policy`, `Permissions-Policy`, e `HSTS` **quando já em HTTPS**), mas **não há redirecionamento de HTTP para HTTPS** no `.htaccess` nem `Content-Security-Policy`. Além disso, estes cabeçalhos só se aplicam a pedidos que passam pelo PHP — ficheiros estáticos servidos diretamente (ver C1/C2) não os recebem.
- **Onde:** `init.php:12-23`; `.htaccess` (sem `RewriteCond %{HTTPS} off` → redirect).
- **Risco:** primeira ligação em claro pode ser intercetada; ausência de CSP enfraquece defesa contra XSS.
- **Correção:** forçar HTTPS no `.htaccess` (`RewriteCond %{HTTPS} off` → `https://...`); adicionar `Content-Security-Policy` adequado; servir os cabeçalhos também por Apache (`mod_headers`) para cobrir estáticos.
- **Verificação:** pedido em `http://` redireciona para `https://`; cabeçalho CSP presente.

### B2 — Captcha Turnstile a usar chaves de teste (deixa passar sempre)
- **O que é:** o Turnstile está `enabled => true` mas com as **chaves públicas de TESTE** da Cloudflare, que deixam o captcha passar sempre; `soft_fail => true` (se a Cloudflare falhar, deixa passar). Não é um segredo real exposto (são chaves públicas de teste), mas a proteção está inativa na prática.
- **Onde:** `app/config/turnstile.php:17-18` (chaves de teste), `:21` (`soft_fail`).
- **Risco:** proteção anti-bot/força-bruta no login e formulários públicos efetivamente desligada.
- **Correção:** substituir pelas chaves reais da Cloudflare (fora do repositório, como A1) e ponderar `soft_fail => false` em produção.
- **Verificação:** captcha real a bloquear submissões automáticas.

---

## Tabelas com dados pessoais identificadas no esquema (produção)
`pessoa` (nome, apelido, NIF, morada), `funcionario` (NIF, **NISS**, **IBAN**, data de nascimento, estado civil, dependentes, contacto/telefone de emergência, fotografia), `contatos` (fixo, móvel, e-mail), `api_matriculas` (matrículas de veículos), `reserva_cliente`, `faturacao` (credenciais de integração), `email_de_contato`, `empresa`, e módulo `rh_*` (recibos, contratos, pagamentos). Total: 290 tabelas; dados sensíveis de RH e financeiros merecem tratamento reforçado (Art. 9.º/32.º).

---
*Classificação: impacto × probabilidade, em linguagem de negócio. Reteste a cargo de quem achou, após o "sim" do Diego ao plano de correção. Nada foi alterado nesta auditoria.*
