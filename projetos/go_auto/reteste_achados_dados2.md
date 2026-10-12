# Go Auto — 2.ª vaga de auditoria (Dados/Segredos + Código)

> Auditoria **defensiva, autorizada** (sistema do Diego / iTEG4Business). Ambiente: cópia de testes `/root/work/itest`.
> Agentes: **Gonçalo** (dados/segredos/RGPD) + **Paulo** (código/SAST). Data: 2026-10-12.
> Classificação: **Crítico** (já) · **Alto** (antes de vender) · **Médio** (próximo ciclo) · **Baixo** (melhoria).
> Regra cumprida: **nenhum valor de segredo escrito** — só a localização (ficheiro:linha).

Esta vaga confirma os **Médios restantes** da 1.ª ronda e procura o que faltou. Boa notícia: os dois Críticos de infra da 1.ª ronda ligados a dados **estão fechados nesta cópia** (ver "Já corrigido").

---

## ALTO

### AD1 · Conta de administrador por omissão (`admin` / `admin`) nos inserts do instalador
- **O que é:** `app/database/iteg-inserts.sql:717` cria `system_users` id=1, login **`admin`**, com `password` = hash **MD5 de "admin"** (hash público bem conhecido). A linha `:719` cria ainda `Admin` com a palavra em claro no campo `password` (essa não autentica, mas é descuido).
- **Onde:** `app/database/iteg-inserts.sql:717` (e `:719`).
- **Risco:** `authenticate()` (`app/model/admin/SystemUsers.php:17077`) aceita MD5 legado → **login `admin`/`admin` funciona** e migra sozinho para bcrypt. Se estes inserts forem aplicados numa instalação real (e o `install.php` da 1.ª ronda ainda reabre a base), fica um administrador total com credenciais por omissão conhecidas. Comprometimento de todo o SaaS.
- **Correção:** não semear contas com palavra-passe conhecida; o instalador deve **forçar definição da palavra-passe do 1.º admin** e criar o registo já em bcrypt. Em qualquer instalação existente, mudar já a palavra-passe do `admin` e remover o utilizador `Admin` (id=2).
- **Verificação:** `authenticate('admin','admin')` → recusado; confirmar que `system_users.password` do admin é `$2y$...` e não os 32 hex.

---

## MÉDIO

### MD1 · dompdf com `setIsRemoteEnabled(true)` — superfície de SSRF na geração de PDFs *(confirmado)*
- **O que é:** `app/lib/html/AdiantiHTMLDocumentParser.php:447` liga o carregamento de recursos remotos quando não há `DOMOptions` definidas. É o parser usado por `BTableWriterHtmlPDF` e por **todos os documentos de registo**: orçamentos (`crm/PDFOrcamentoDocument.php`), OS, recibos/recebimentos (`financeiro/*`), compras e ordens de compra (`compras/*`), guias/etiquetas (`logistica/*`, `crm/PDFOGuiaPickingForm.php`).
- **Risco (real, mas limitado):** o HTML do PDF embute campos do registo/empresa — ex. `PDFOrcamentoDocument.php:103` injeta `<img src='{$empresa->logo}'>`, além de website e dados de contacto. Um utilizador autenticado (contexto multiempresa) que controle um desses campos (logo, website, texto rico) pode apontar a um endereço **interno** (ex. serviços locais, metadados de cloud). Com remote ligado, o dompdf vai buscá-lo no servidor → SSRF / varrimento interno; a resposta pode ser refletida na imagem do PDF. Atenuante: `setChroot(getcwd())` (linha 448) limita a leitura de ficheiros locais à pasta da app, e a exfiltração é só o que renderiza numa imagem.
- **Correção (sem partir logótipos locais):** usar `setIsRemoteEnabled(false)` — **é o que os serviços irmãos já fazem com sucesso** (`service/compras/ComprasDocumentoService.php:113,227`; `service/logistica/LogPdfService.php:12`), prova de que os logótipos **locais** continuam a funcionar sem remote. Se algum logótipo for URL externo, converter para caminho local / data-URI (base64) antes de gerar, ou manter uma allowlist de domínios. Manter o `setChroot`.
- **Verificação:** gerar PDF de orçamento com logo local → sai na mesma; um `<img src="http://169.254.169.254/...">` num campo → **não** é buscado (sem ligação de saída do servidor ao gerar o PDF).

### MD2 · Aceitação de palavras-passe MD5 legadas — janela aberta *(confirmado)*
- **O que é:** `app/model/admin/SystemUsers.php:17077` — `if (hash_equals($user->password, md5($password))) { updatePasswordHash(...) }`, migra para bcrypt só **quando o utilizador faz login**. Até lá, o hash MD5 permanece válido e aceite.
- **Risco:** utilizadores que nunca mais entraram ficam com MD5 (rápido de quebrar). Se a base vazar, essas palavras-passe caem em minutos. A migração "preguiçosa" não tem fim garantido nem relatório de quantos ainda estão em MD5.
- **Correção (fechar a janela):** migração em lote — identificar quem ainda tem hash de 32 hex e forçar reposição de palavra-passe nessas contas (ou marcar `valida_password`); depois **remover o ramo MD5** de `authenticate()`. Enquanto a conta `admin` por omissão (AD1) existir em MD5, não se consegue remover o ramo — resolver AD1 primeiro.
- **Verificação:** query a contar `password` com 32 hex = 0; remover o `if (md5…)` e confirmar que todas as contas ativas continuam a entrar.

### MD3 · Mensagens de exceção cruas mostradas ao utilizador (fuga de informação)
- **O que é:** `app/control/parceiros/OrcamentoPartnerList.php` mostra `new TMessage('error', $e->getMessage())` em ~10 pontos (ex.: linhas 563, 594, 631, 657, 683, 740, 831, 872, 935 — algumas com comentário "shows the exception error message"). Também em `app/control/log/SystemRequestLogView.php:27`.
- **Risco:** erros de base de dados / SQL / caminhos de ficheiros chegam ao ecrã do utilizador (lista virada a parceiros), ajudando o atacante a mapear o sistema.
- **Correção:** mostrar mensagem genérica ao utilizador e registar o detalhe no log do servidor; nunca `getMessage()` direto na interface.
- **Verificação:** provocar erro → o ecrã mostra texto neutro; o detalhe aparece só em `tmp/php_errors.log`.

### MD4 · RGPD: dados pessoais em claro e sem consentimento/retenção *(confirmado, ajustado)*
- **O que é:** o esquema guarda **data de nascimento** (`iteg-mysql.sql:989` `funcionario.data_nascimento`) e **moradas** (tabela `morada`) em claro; nenhuma cifra em repouso para dados pessoais (o único `openssl_encrypt` é para o payload móvel em `service/builder/BuilderMobileService.php`, não para PII). Não há colunas de **consentimento/retenção/minimização** (procura por `consent/rgpd/retention/consentimento` = nada; só existe `accepted_term_policy` em `system_users`).
- **Correção da hipótese NISS/IBAN:** **não encontrei** colunas `niss`/`iban`/`nib`/`seguranca_social` no esquema `iteg-*`. O risco confirmado é DOB + morada (+ ver MD5 abaixo).
- **Risco:** incumprimento RGPD (minimização, retenção, base de consentimento); PII legível por quem aceder à base.
- **Correção:** definir política de retenção e base legal; considerar cifrar em repouso os campos mais sensíveis (DOB) ou, no mínimo, restringir acesso e registar quem consulta; adicionar consentimento explícito onde se recolhe PII.
- **Verificação:** matriz de dados pessoais com base legal e prazo de retenção; teste de apagamento/anonimização.

### MD5 · Palavra-passe de SMTP guardada em claro na base
- **O que é:** `saas_configuracao` tem coluna `email_password` (ver `iteg-inserts.sql:303`) — segredo de SMTP guardado em claro na BD (não é ficheiro, por isso não é tapado pelo `.htaccess`).
- **Risco:** quem leia a base (ou um backup) obtém a credencial de envio de e-mail da empresa.
- **Correção:** cifrar segredos de gateway/SMTP em repouso (chave fora da BD) ou guardá-los só em segredos de ambiente; mascarar na interface.
- **Verificação:** o valor em BD não é legível em claro; o envio continua a funcionar.

---

## BAIXO

### BD1 · CORS `Access-Control-Allow-Origin: *` — impacto baixo (API por Bearer) *(confirmado, reclassificado)*
- **O que é:** `MadRestServer.php:3-4` envia `Access-Control-Allow-Origin: *` e `Access-Control-Allow-Headers: *`.
- **Avaliação (a pergunta-chave):** a API **autentica por token Bearer no cabeçalho `Authorization`** (`app/middleware/BearerAuthMiddleware.php:25-37`, `getAuthToken()` → `Bearer {token}`), **não** por cookie/sessão, e **não** há `Access-Control-Allow-Credentials` em lado nenhum. Logo o `*` **não** expõe dados autenticados por cookie: o navegador da vítima não envia o Bearer automaticamente para um site atacante, e o spec proíbe `*` + credenciais. Impacto real: baixo (um site qualquer pode chamar a API, mas precisa de um token válido).
- **Correção (endurecimento):** restringir a origem a uma allowlist de domínios conhecidos e responder a preflight `OPTIONS` só para esses; não usar `*` em produção. (A rota `mobile.php:6` já usa origem fixa — bom modelo.)
- **Verificação:** pedido de origem não listada → sem cabeçalhos CORS; app móvel/parceiro autorizado continua a funcionar.

### BD2 · Método de negação dos `.htaccess` de pastas é frágil
- **O que é:** `app/config/.htaccess` e `tmp/.htaccess` negam com o truque legado `AuthUserFile /dev/null` + `require valid-user`. Em Apache 2.4 sem os módulos de auth básica carregados, isto pode dar 500 ou falhar aberto. Os PDFs de faturas/orçamentos em `tmp/` (nomes `uniqid()`) ficam só atrás deste `.htaccess` — a regra global de extensões **não** cobre `.pdf`.
- **Correção:** trocar por `Require all denied` (como já está na raiz para extensões sensíveis); idealmente servir os PDFs por um controlador com sessão + âmbito de empresa, não por ficheiro estático em `tmp/`.
- **Verificação:** `GET /tmp/<ficheiro>.pdf` → 403; geração/descarregamento pela app continua a funcionar.

---

## Já corrigido nesta cópia (reteste — fechado)

- **Bases/segredos descarregáveis (era K2):** `/.htaccess:136-144` nega agora por extensão `.db/.sqlite/.ini/.log/.lock/.bak/.sql/.sh` com `Require all denied` (+ fallback `Deny from all`). Tapa também os `.sql` de esquema em `app/database/` e o `php_errors.log`. **Bom.**
- **`tmp/` sem `.htaccess`:** agora existe `tmp/.htaccess` (ver BD2 para o reforçar).
- **SQL — re-varredura (item 4):** **sem novos pontos reais de origem de utilizador.**
  - `app/service/ModeloNegocioService.php:105,112,131` concatena SQL, mas só com `(int)$grupoVendasId`, um enum fixo (`PRODUTOS/SERVICOS/HORAS`) e `escopoSql()` — que usa apenas `(int)` de valores de sessão (`:60-66`). Não há entrada de utilizador.
  - `app/service/logistica/LogEntregaService.php:205` usa parâmetros ligados `?` + `LogDb::escopo()` interno. Seguro.
  - `SaasPagamentoList` e `SaasContratoSeekWindow` **já migrados** para `TFilter`/`TCriteria` (parametrizado) — os pontos da 1.ª ronda estão fechados.
  - Sweep a `->query(`/`->exec(`/`TRawStatement`/`->where(` com `$_GET/$_POST/$_REQUEST/$param/$data->` não-inteiro em `app/control` e `app/service`: **0 resultados**.
- **Segredos em claro no código (item 5):** **nenhum**. Os `sk_test_/sk_live_` em `app/service/StripeService.php:19` estão num **comentário/docblock** explicativo ("nunca no código"); os segredos (Stripe/SMTP) são lidos da configuração em BD. Sem `AIza…`, sem `-----BEGIN PRIVATE KEY-----`, sem `sk_live` reais na árvore.
- **Fugas (item 6):** sem ficheiros `phpinfo()` na raiz web; sem `.bak/.orig/.zip/.save/.old` soltos; os `.sql` só em `app/database/` (tapados por `.htaccess`). `init.php:30` manda erros para `tmp/php_errors.log` (protegido). `display_errors`/`debug` já desligados (1.ª ronda).

---

## Resumo de contagem (esta vaga)
**0 Críticos · 1 Alto · 5 Médios · 2 Baixos.** (Vários Médios da 1.ª ronda ligados a dados ficaram **fechados** nesta cópia — ver acima.)

> Nada se altera sem o "sim" do Diego. Cada correção tem forma de reverter e reteste de quem achou.
