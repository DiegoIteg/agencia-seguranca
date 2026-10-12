# Go Auto — Parecer de Segurança e Plano de Correção

> Auditoria defensiva, autorizada (sistema do Diego / iTEG4Business). Ambiente: cópia de testes `itest`.
> Equipa: Vítor (coordenação), Nádia (web/acessos), Paulo (código), Gonçalo (dados/RGPD), Clara (dependências).
> Data: 2026-10-12. Classificação: **Crítico** (corrigir já) · **Alto** (antes de vender) · **Médio** (próximo ciclo) · **Baixo** (melhoria).

## Veredicto do Vítor (Diretor de Segurança)

**NÃO está pronto para comercialização.** O desenho de base é sólido — o portão central de permissões (`engine.php`) está bem feito, o registo público (`cadastrar.php`) tem CSRF + honeypot + Turnstile, a API móvel valida JWT com âmbito por empresa, as passwords novas usam bcrypt e o webhook do Stripe valida a assinatura. **O problema são portas laterais que contornam esse portão** e ferramentas de desenvolvimento deixadas no sistema. A boa notícia: os dois achados mais graves são de **correção rápida** (apagar/trancar ficheiros), não reescrita.

Resumo: **4 Críticos · 8 Altos · ~13 Médios · ~8 Baixos.**

---

## CRÍTICOS — corrigir antes de tudo (porta aberta agora)

### K1 · Porta das traseiras de administrador sem login — `preview_ecra.php`
- **O que é:** ficheiro que a nossa equipa criou para capturas de ecrã. Sem qualquer login, forja uma sessão de administrador (linha 4) e corre **qualquer** controlador e método vindos do URL (linha 9: `new $classe($_GET)` + `$o->$metodo($_GET)`).
- **O que um atacante faria:** `preview_ecra.php?class=...&method=onDelete&id=...` — ler, alterar ou apagar o que quisesse, como admin, sem conta. Comprometimento total.
- **Correção:** **apagar `preview_ecra.php`** do sistema (nunca deve ir para produção). Verificar que não há outros ficheiros do género na raiz.
- **Confirma que fechou:** `GET /preview_ecra.php?...` devolve 404.

### K2 · Bases de dados descarregáveis pela web
- **O que é:** `test.db` (1,4 MB), `communication.db`, `log.db` na raiz; o `.htaccess` da raiz **não** bloqueia `.db`/`.ini`/`.log`. Em produção, a base real (com hashes de passwords e dados de todas as empresas) fica descarregável por URL.
- **Correção:** regra no `.htaccess` da raiz a negar o acesso web a `.db`, `.ini`, `.log`, `.lock` (e, idealmente, mover as bases para fora da raiz web); apagar a `test.db` do pacote.
- **Confirma:** `GET /test.db` devolve 403/404.

### K3 · Instalador público reabre a base — `install.php` + `DatabaseInstall`
- **O que é:** `install.php` sem login e `DatabaseInstall` em `public_classes`, com a salvaguarda "já instalado" desligada e token comparado com `==` a um literal no código.
- **O que um atacante faria:** reconfigurar/reapontar a base de dados do sistema.
- **Correção:** remover `install.php` e `DatabaseInstall` das classes públicas em produção (ou exigir login admin + bloquear quando já instalado).
- **Confirma:** `install.php` sem sessão → recusado.

### K4 · Injeção de Objeto PHP via `unserialize` com dados do browser
- **O que é:** vários ecrãs fazem `unserialize(base64_decode($param['__row__data']))` **sem** `allowed_classes=>false` — e o `base64` vem do browser. Ficheiros: `TabelaPrecoForm`, `AtribuirLocalizacaoForm`, `LocalizarRecepcaoMercadoriaForm`, `RecepcaoMercadoriaForm`, `SaasPlanoHeaderList`, `SaasServicoList`, `BuilderMasterDetailTrait`. (Contraste seguro já existente: `LoginForm.php:339`.)
- **O que um atacante faria:** com uma cadeia de "gadgets" nas bibliotecas, pode escalar até execução de código. Mesmo sem gadget, é manipulação de estado.
- **Correção:** acrescentar `['allowed_classes' => false]` a todos esses `unserialize` (como no LoginForm), ou substituir por JSON assinado. Correção pequena e repetida.
- **Confirma:** reteste de cada ecrã + grep a garantir que não resta `unserialize(` sem `allowed_classes` em `app/`.

---

## ALTOS — corrigir antes de vender

- **A1 · Travessia de caminho em `download.php`** — `$_GET['file']` usado direto em `file_get_contents`, só com sessão e lista de extensões; sem pasta-base nem âmbito por empresa. Lê `application.ini` (segredos) e ficheiros de outras empresas. → restringir a uma pasta base + validar `realpath` + scoping por tenant.
- **A2 · Webhook Mercado Pago sem assinatura** — `retorno_mercado_pago.php` confia em `$param['status']` de um POST não autenticado → **forjar faturas como pagas**. → validar a notificação reconsultando a API do Mercado Pago (como o Stripe já faz por HMAC).
- **A3 · Webhook Banco Inter sem assinatura** — `hook_inter.php` aceita POST não verificado (e tem variáveis indefinidas). → assinar/validar ou desligar até validar.
- **A4 · Injeção SQL nas ferramentas admin** — `SystemDataBrowser`, `SystemTableList`, `SystemDatabaseExplorer`, `SystemSQLPanel` interpolam `table`/`filter` do pedido em SQL. Hoje exigem admin, mas com K1 tornavam-se exploráveis sem login. → remover/trancar estas ferramentas de programador em produção.
- **A5 · Segredos em claro no `application.ini`** (linhas 19-21), provavelmente versionados. → **rodar** esses segredos e movê-los para fora do repositório (variáveis de ambiente). *(Login é sempre do Diego; a rotação é feita por ele.)*
- **A6 · JWT da app nunca expira** — campo `expires` em vez de `exp`, não verificado; aceite também por `?token=`. Token roubado vale para sempre. → usar `exp` padrão + validar expiração; não passar tokens no URL.
- **A7 · Credenciais/tokens no URL e nos logs** — rota REST `auth/<login>/<password>` e JWT de reposição no URL; `SystemRequestLogService` regista URI/query → passwords/tokens acabam em logs. → mover para POST/cabeçalho; não registar query com segredos.
- **A8 · XSS por bibliotecas antigas** — DataTables 1.10.7 (CVE-2021-23445) e Summernote 0.8.18 (CVE-2024-37629) em sistema multiempresa. → atualizar DataTables; sanitizar no servidor o HTML do Summernote.

---

## MÉDIOS — próximo ciclo

- Cookie de sessão sem `Secure`/`HttpOnly`/`SameSite` (`TSession.php`).
- Ferramentas de diagnóstico expostas por rota: `phpinfo()`, `SystemPHPInfoView`, painel SQL, `linfo` (abandonado) no ecrã admin.
- `CORS: *` em `MadRestServer.php`; grupo de rotas `/api` sem middleware; RPC genérico com `rest_key` estática.
- Login sem bloqueio por tentativas (força bruta).
- 2FA com código gerado por `rand()` (`TwoFactorEmailService`) → usar `random_int`.
- Upload: lista-negra incompleta e `$file['name']` sem `basename()` (`SystemDocumentUploaderService`).
- `unserialize` do builder com MAC `md5` caseiro e `==` (`BuilderSeekWindowTrait`).
- Injeção SQL em filtros SaaS (`SaasPagamentoList`, `SaasContratoSeekWindow`).
- `dompdf 2.0.4` com `setIsRemoteEnabled(true)` → superfície de SSRF na geração de PDFs.
- Pasta `tmp/` sem `.htaccess` (PDFs de faturas e `php_errors.log` acessíveis).
- Aceitação de passwords legadas MD5 (migração para bcrypt já existe) — encerrar a janela quando possível.
- RGPD: sem consentimento/retenção/minimização; `funcionario` guarda NISS/IBAN/data de nascimento; `require_terms=0`.

## BAIXOS — melhoria

- Sem redirect HTTP→HTTPS e sem CSP (restantes cabeçalhos já ativos).
- Dependências `dev-master` não fixadas (`adianti/*`, `pablodalloglio/*`) → fixar versões (supply chain).
- Front-end antigo (Bootstrap 4.3.1, jQuery 3.6.1, Select2, datepicker) → plano de atualização.
- `firebase/php-jwt 6.10.0` (CVE disputado) → acompanhar.

---

## O que JÁ está bem (não mexer)
Portão `engine.php`; `cadastrar.php` (CSRF+honeypot+Turnstile+lista branca); API móvel JWT com âmbito por empresa (sem IDOR aparente); `db-mad-manager` restrito a admin; `cmd.php`/`Cron.php` só por linha de comandos; webhook Stripe com HMAC (modelo a replicar nos outros); `debug=0`; bcrypt nas passwords novas; TLS verify no Moloni; `.htaccess` de negação já em `app/config/` e `files/`.

---

## Plano de execução proposto (ordem)
**Fase 1 — Críticos (rápida, poucas horas):** apagar `preview_ecra.php`; `.htaccess` a negar `.db/.ini/.log`; remover `install.php`/`DatabaseInstall` públicos; `allowed_classes=>false` em todos os `unserialize`. → reteste → pacote.
**Fase 2 — Altos:** `download.php` seguro; validar webhooks MP/Inter; trancar ferramentas admin; JWT com `exp`; tirar credenciais do URL/logs; atualizar DataTables + sanitizar Summernote. (Rotação de segredos: pelo Diego.)
**Fase 3 — Médios/Baixos + endurecimento:** cookies seguros, cabeçalhos/CSP, bloqueio de força bruta, `random_int` no 2FA, uploads, dompdf, RGPD.
**Fase 4 — QA completo** (Equipa de Testes): funcional ecrã-a-ecrã, compatibilidade, desempenho, acessibilidade → veredicto "pode publicar".

> **Nada será alterado sem o "sim" do Diego.** Cada correção terá forma de reverter e reteste de quem achou.
