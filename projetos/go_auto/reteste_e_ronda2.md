# Go Auto — Reteste da Ronda 1 + Novos Achados (Ronda 2)

> 2026-10-12, após o Diego instalar o pacote de correções. Ambiente de testes.
> Reteste pela equipa + verificação em fonte dos achados graves.

## 1. Reteste da Ronda 1 — TUDO FECHADO ✅
Confirmado no código instalado:
- K1 backdoor `preview_ecra.php` → neutralizado (403). ✅
- K2 `.htaccess` nega `.db/.ini/.log/.sql/...` (linhas 136-144). ✅
- K3 instalador trancado (`install.php` + classes no portão). ✅
- K4 `unserialize` dos ecrãs do browser com `allowed_classes=>false` (0 em falta). ✅
- A1 `download.php` contido (sem travessia). ✅
- A2/A3 webhooks Mercado Pago e Inter desativados (só Stripe). ✅
- A4 ferramentas de programador trancadas. ✅
- A6 JWT com `exp`. ✅  · A7 logs mascarados. ✅
- Fase 3: cookies seguros, 2FA `random_int`, `tmp/.htaccess`, CSP frame-ancestors, filtros SaaS. ✅

## 2. Novos achados (a passagem mais funda encontrou)

### CRÍTICOS
- **N1 · Credenciais por omissão `admin` / `admin`.** O seed (`app/database/iteg-inserts.sql:717`) cria o utilizador `admin` com `password = md5('admin')`; como o login ainda aceita MD5 legado (`SystemUsers.php:17077`), **`admin`/`admin` entra como administrador**. → **Ação do Diego (urgente): entrar e mudar JÁ a palavra-passe do admin**; depois removemos a conta-semente e fechamos o MD5. Verificação: `admin`/`admin` deixa de entrar.
- **N2 · Injeção de objeto + leitura sem filtro no MultiSearch/Autocomplete.** `AdiantiMultiSearchService.php:73/90` (e `AdiantiAutocompleteService`): o hash de validação **não cobre** o `criteria`, que é `unserialize`-ado sem `allowed_classes`. Um utilizador autenticado reutiliza um hash legítimo e controla o payload (injeção de objeto PHP) e o filtro (lê registos de outra empresa). → Correção segura e rápida: `allowed_classes=>false` na linha 90 + `hash_equals` em vez de `==` na 77. (A parte de "ler de outra empresa" liga-se ao N3.)

### ALTOS
- **N3 · IDOR entre empresas.** `onEdit`/`onDelete`/listas carregam o registo pela chave **sem confirmar que pertence à empresa (tenant) do utilizador**; o portão (`engine.php`) só valida permissão de ECRÃ, não de REGISTO (`OrcamentoForm.php:1894`, `CadastroDeClientesForm.php:446`, `ViaturaForm.php:153`, `OrcamentoList.php:461`). Hoje o teste só tem 1 empresa → **torna-se Crítico assim que houver uma 2.ª empresa** no mesmo sistema (é o modelo SaaS!). → É o item **arquitetural** mais importante para vender multiempresa: precisa de scoping por `account_id` nas queries/consultas de registo, com teste cuidado.
- **N4 · Upload anónimo** via `AdiantiUploaderService` (público): sem login grava ficheiros em `tmp/` (abuso/DoS). Mitigado (o `tmp/.htaccess` impede servir), mas deve exigir sessão. 

### MÉDIOS
- **N5 · dompdf SSRF** — `AdiantiHTMLDocumentParser.php:447` tem `setIsRemoteEnabled(true)`. Correção segura: pôr `false` (os serviços irmãos já o fazem; logótipos locais continuam a funcionar).
- **N6 · CSRF** em ações de escrita por GET sem token (SameSite=Lax não trava GET de topo).
- **N7 · Reposição de senha confia em `HTTP_HOST`** (`EsqueciSenhaForm.php:123`) → envenenamento do link.
- **N8 · `SystemModulesCheckView` público** expõe configuração PHP → tirar do público (portão).
- **N9 · Login sem bloqueio por tentativas** (só `sleep(2)`), e mensagens que permitem enumerar utilizadores.
- **N10 · MD5 legado** — janela sem fim; fechar após resolver N1 (migração + remover ramo MD5).
- **N11 · Fuga de exceções** `$e->getMessage()` ao utilizador (`OrcamentoPartnerList.php`, `SystemRequestLogView.php:27`).
- **N12 · Segredos em claro na BD** — SMTP `email_password` (`saas_configuracao`); e DOB/moradas sem cifra/retenção (RGPD). (Nota: **não há** NISS/IBAN no esquema, hipótese anterior corrigida.)

### BAIXOS
- **N13 · CORS `*`** em `MadRestServer.php` — impacto baixo (API usa Bearer, sem cookies); endurecer com allowlist.
- **N14 · Credenciais REST no URL** (`.htaccess auth/$1/$2`) e `==` em vez de `hash_equals` nalguns serviços.
- **N15 · `.htaccess` de `tmp/` e `app/config/`** com `AuthUserFile /dev/null` (frágil) → trocar por `Require all denied`.

## 3. Veredicto atualizado
A Ronda 1 fechou todas as portas abertas que tínhamos. Mantêm-se **2 Críticos novos** (um é ação do Diego — mudar a password do admin; o outro é correção rápida no MultiSearch) e **o IDOR entre empresas (N3)** como o trabalho **arquitetural** decisivo para vender em modo multiempresa. Ainda **não comercializar** até fechar N1, N2 e N3.

## 4. Proposta — Ronda 2
- **Já (ação do Diego):** mudar a palavra-passe do `admin`.
- **Pacote rápido (seguro):** N2 (allowed_classes+hash_equals), N5 (dompdf false), N8 (tirar ModulesCheckView do público), N7 (HOST do reset), N11 (não expor exceções), N15 (.htaccess robusto), N4 (upload exige sessão), N13/N14 (CORS/hash_equals). → novo `go_auto_tudo.zip`.
- **Projeto dedicado (com testes):** N3 scoping multiempresa + N10/N1 fecho do MD5 + N9 bloqueio de tentativas.
