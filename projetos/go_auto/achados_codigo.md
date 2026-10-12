# Achados de Revisão de Código (SAST) — Go Auto

**Autor:** Paulo (revisão de código / SAST) · **Projeto:** Go Auto (ERP, PHP 8.3 + Adianti/MadBuilder 7.5)
**Código:** `/root/work/itest` · **Tipo:** auditoria defensiva autorizada · **Data:** 2026-10-12
**Método:** grep + leitura, com confirmação da ORIGEM de cada variável. Separa-se o risco real do falso positivo.

> Nota de acesso: várias injeções dependem de o atacante já ter sessão iniciada (utilizador autenticado), por vezes com perfil de administrador. A confirmação do controlo de acessos (quem chega a cada ecrã) é da Nádia. Aqui classifica-se o padrão de código em si.

---

## CRÍTICO

### C1 — Injeção de Objeto PHP: `unserialize()` de dados do cliente sem `allowed_classes`
**O que é:** vários ecrãs desserializam conteúdo enviado pelo browser (`base64_decode` de um campo do pedido) **sem** `['allowed_classes' => false]`. Isto permite instanciar objetos PHP arbitrários a partir de dados do atacante.

**Onde (todos sem qualquer proteção de assinatura):**
- `app/control/crm/TabelaPrecoForm.php` — linhas 548, 588, 624, 662, 696, 734 → `unserialize(base64_decode($param['__row__data']))`
- `app/control/logistica/AtribuirLocalizacaoForm.php` — linhas 639, 675
- `app/control/logistica/LocalizarRecepcaoMercadoriaForm.php` — linhas 471, 507
- `app/control/logistica/RecepcaoMercadoriaForm.php` — linhas 545, 581
- `app/control/saas_admin/SaasPlanoHeaderList.php` — linha 218 → `unserialize(base64_decode($param['_builder_field_options']))`
- `app/control/saas_admin/SaasServicoList.php` — linha 343 (idem)
- `app/lib/builder/BuilderMasterDetailTrait.php` — linha 38 → `unserialize(base64_decode($item))`

**Porque é explorável:** nos métodos de ação do Adianti, `$param` é alimentado pelo pedido HTTP (`$_REQUEST`). Os campos `__row__data`/`_builder_field_options`/`$item` são strings base64 presentes no HTML/pedido, **totalmente controláveis pelo cliente**. Nenhum destes locais verifica assinatura antes de desserializar. Com uma cadeia de "gadgets" (o framework Adianti e dependências como dompdf trazem classes com `__destruct`/`__wakeup` úteis), isto pode escalar para escrita/leitura de ficheiros ou execução de código.

**Contraste (código seguro, a imitar):** `app/control/admin/LoginForm.php:339` usa `unserialize($param['previous_parameters'], ['allowed_classes' => false])`.

**Risco de negócio:** comprometimento total do servidor do ERP (dados de todos os clientes/tenants, faturação, RGPD). É a falha mais grave do lote.

**Correção:** acrescentar `['allowed_classes' => false]` a **todas** estas chamadas (os dados são sempre `stdClass`/escalares, não precisam de classes). Idealmente, substituir o transporte de estado por JSON (`json_encode`/`json_decode`).

**Verificação:** enviar um payload serializado de um objeto de teste e confirmar que já não é instanciado (deixa de haver efeitos de `__wakeup`/`__destruct`); reteste funcional dos ecrãs afetados pela Beatriz.

---

## ALTO

### A1 — Falsificação de pagamento no webhook Mercado Pago (confia no `status` do pedido)
**Onde:** `retorno_mercado_pago.php:42` → `SaasPagamentoService::atualizar($param['external_reference'], $param['status'], $param['payment_type'])`.
**Porque é explorável:** este ficheiro **não verifica assinatura** do webhook. Nos ramos de assinatura (linhas 20–38) há reconsulta à API da MP (`getPayment`/`verificaAssinatura`), o que mitiga; mas no ramo `external_reference` o estado do pagamento é lido **diretamente do corpo do pedido** (`$param['status']`), sem reconsultar a MP. Um atacante que descubra/adivinhe um `external_reference` pode fazer POST a este endpoint com `status=approved` e marcar uma fatura como paga. (Bónus: `linha 11` usa `$request` que nunca é definido neste ficheiro — o log fica vazio.)
**Risco de negócio:** receita perdida; assinaturas/contratos ativados sem pagamento real.
**Correção:** validar a assinatura do webhook (ou, no mínimo, reconsultar sempre o pagamento na API da MP pelo `data_id`/`payment_id` e usar o estado devolvido pela MP, nunca o do corpo). Corrigir a variável `$request`→`$param` no log.
**Verificação:** POST forjado com `status=approved` deixa de alterar o pagamento; só a confirmação vinda da MP o faz.

### A2 — Travessia de caminho / leitura arbitrária de ficheiros em `download.php`
**Onde:** `download.php:7` → `$file = $_GET['file'];` usado em `file_exists($file)` e `echo file_get_contents($file)` (linha 51).
**Porque é explorável:** o nome do ficheiro vem cru de `$_GET['file']`, sem `basename()` nem restrição a uma pasta base. A única barreira é ter sessão (`TSession::getValue('logged')`) e a extensão estar numa whitelist (txt, csv, pdf, xml, zip, docx, xlsx…). Com `?file=../../../../etc/passwd`... (sem extensão falha), mas `?file=../../caminho/ficheiro.xml` ou qualquer ficheiro do servidor com extensão permitida (config exportadas, backups `.zip`/`.csv`, ficheiros de outros tenants em `files/`) é lido por qualquer utilizador autenticado.
**Risco de negócio:** fuga de dados entre tenants e de ficheiros do servidor (RGPD, segredos exportados).
**Correção:** resolver o caminho com `realpath()` e confirmar que fica **dentro** de uma pasta base autorizada (ex.: `files/`), aplicar `basename()` e validar que o ficheiro pertence ao tenant/utilizador. Não servir caminhos absolutos/relativos arbitrários.
**Verificação:** `?file=../...` fora da pasta base devolve 403/404; só ficheiros do próprio tenant são servidos.

### A3 — Injeção SQL nas ferramentas de administração (nome de tabela/coluna crus)
**Onde:**
- `app/control/admin/SystemDataBrowser.php:109` → `"... FROM {$table} ".$where_string`, com `$table = $param['table']` (linha 64) e `filter_name`/`order`/`direction` vindos de `$param` (linhas 63–99).
- `app/control/admin/SystemTableList.php:104` → `$table = $param['table']` usado em `setEntity($table)` e no nome do ficheiro CSV (linha 121).
- `app/control/admin/SystemDatabaseExplorer.php:245,251` → `INSERT INTO {$table} ({$columns}) VALUES ({$values})`.
**Porque é explorável:** nomes de tabela/coluna não podem ser parametrizados e aqui são interpolados crus a partir do pedido, sem whitelist. Permite quebrar a query (`table = x WHERE 1=1 UNION SELECT ...` / subqueries). São ferramentas de desenvolvimento/admin do Adianti (poderosas por desenho), mas a interpolação sem validação alarga o estrago para além do pretendido e torna o impacto dependente apenas do controlo de acessos.
**Risco de negócio:** leitura/alteração de qualquer tabela se um utilizador não-admin alcançar estes programas.
**Correção:** validar `database`/`table`/`filter_name`/`order` contra a lista real de bases/tabelas/colunas (metadados) antes de interpolar; restringir rigorosamente o acesso a estes programas (confirmar com a Nádia).
**Verificação:** `table` com carateres fora de `[A-Za-z0-9_]` é rejeitado; confirmar que só admins chegam ao ecrã.

> `app/control/admin/SystemSQLPanel.php:149,219` executa `$data->select` (SQL escrito pelo admin). É uma consola SQL **por desenho** — não é vulnerabilidade, mas tem de ficar restrita a admins e, idealmente, só no ambiente de testes.

---

## MÉDIO

### M1 — Injeção SQL em filtros do SaaS admin (`$data->...` interpolado em subquery)
**Onde:** `app/control/saas_admin/SaasPagamentoList.php:799` (`account_id = '{$data->cliente_id}'`) e `:805` (`saas_plano_id = '{$data->plano_id}'`); `app/control/saas_admin/SaasContratoSeekWindow.php:310`.
**Porque é explorável:** `$data = $this->form->getData()` (SaasPagamentoList:766, no `onSearch`) — valores do formulário de filtro controlados pelo utilizador, interpolados dentro de aspas numa subquery de um `TFilter`. Um valor com `'` quebra a subquery. Normalmente são IDs vindos de seek/select, mas nada impõe que sejam numéricos.
**Risco de negócio:** injeção SQL no backoffice SaaS (dados de contratos/pagamentos de todos os clientes).
**Correção:** `(int)` nos IDs, ou usar `TFilter('account_id','in', [...])` com valores ligados, nunca interpolar string crua.
**Verificação:** `cliente_id = 1' OR '1'='1` deixa de devolver linhas extra.

### M2 — `unserialize()` protegido por MAC md5 "caseiro", ainda sem `allowed_classes`
**Onde:** `app/lib/builder/BuilderSeekWindowTrait.php:37` e `:57` → desserializa `_seek_fields`/`_seek_filters` só se `md5($seed.$fields.$filters) == $param['_seek_hash']`.
**Porque é (parcialmente) mitigado e ainda assim risco:** há verificação de integridade com um segredo (`seed` da config), o que impede forja trivial — **bom**. Mas: (a) continua sem `allowed_classes => false`; (b) é um MAC caseiro por concatenação com md5, sujeito em teoria a *length-extension* (um utilizador legítimo recebe pares válidos (dados+hash) e poderia estender `_seek_filters`); (c) a comparação usa `==` (não `hash_equals`), timing-leak. Se o `seed` vazar (ver área da Gonçalo), vira object injection completa.
**Risco de negócio:** escalonamento para injeção de objeto no builder.
**Correção:** `allowed_classes => false`; trocar o MAC por `hash_hmac('sha256', ...)` comparado com `hash_equals()`.
**Verificação:** payload estendido por length-extension é rejeitado; classes arbitrárias não são instanciadas.

### M3 — Código 2FA por e-mail gerado com `rand()` (previsível)
**Onde:** `app/service/auth/TwoFactorEmailService.php:25` → `str_pad(rand(0, 999999), 6, '0', ...)`.
**Porque é explorável:** `rand()` não é criptograficamente seguro; o estado do PRNG é previsível/forçável, enfraquecendo o segundo fator (código de 6 dígitos, validade 10 min).
**Risco de negócio:** contorno do 2FA → acesso indevido a contas.
**Correção:** `random_int(0, 999999)`. Acrescentar limite de tentativas (confirmar que existe).
**Verificação:** confirmar uso de `random_int` e bloqueio após N tentativas.

### M4 — Upload com lista-negra incompleta e nome de ficheiro sem `basename()`
**Onde:** `app/service/system/SystemDocumentUploaderService.class.php` — `$path = $folder.$file['name']` (linha 41) com `$folder = 'tmp/'`; lista-negra em linha 70.
**Porque é explorável:** (a) `$file['name']` é usado sem `basename()` → travessia de caminho (`name = ../../files/...tenant...pdf`) para escrever fora de `tmp/`; (b) a lista-negra (`php, php3, php4, phtml, ...`) **não** cobre `phar`, `php5`, `php7`, `pht`, `phps`; (c) o filtro de extensão é por `strpos` do nome e o MIME por `finfo` — um polyglot (PDF+PHP válido) passa o MIME e, com extensão permitida mas servível como script, ou com `.html`/`.svg`, permite XSS armazenado. Combinado com a A2 (download) ou com uma pasta servida, agrava.
**Risco de negócio:** escrita de ficheiros fora da área prevista; XSS armazenado; em cenário favorável, webshell.
**Correção:** usar sempre `basename($file['name'])` + nome gerado pelo servidor; whitelist de extensões (não lista-negra); guardar uploads fora da raiz web e servir via script controlado.
**Verificação:** `name` com `../` escreve só dentro da pasta; `.phar`/`.svg` são recusados.
**Contraste (seguro, a imitar):** `app/service/logistica/LogEntregaService.php:132` — whitelist de MIME, extensão forçada pelo tipo, nome = `(int)` + `bin2hex(random_bytes(6))`.

### M5 — Webhook Banco Inter sem verificação de assinatura
**Onde:** `hook_inter.php` — processa o corpo do pedido e chama `$service->getInfo(...)`.
**Porque:** não há verificação de assinatura/origem. Mitiga que reconsulta o pagamento (`getInfo`) antes de atualizar, mas falta autenticar o emissor. Há ainda bugs funcionais: `$service` (linha 29) e `$request` no log nunca são definidos neste ficheiro, e itera `$request` como objeto (`$dados->codigoCobranca`) sobre um array associativo — passar à Equipa de Testes.
**Correção:** validar assinatura/IP de origem do Inter; corrigir as variáveis indefinidas.
**Verificação:** pedido sem assinatura válida é recusado.

---

## BAIXO / INFORMATIVO

### B1 — `eval()` em SwaggerController
`app/controller/SwaggerController.php:463,471` → `eval("return {$group[2]};")`. Origem: `$group[2]` vem de `preg_match` sobre o **conteúdo dos ficheiros de rotas** lidos por `file_get_contents` (não input de utilizador). Não é diretamente explorável por um atacante externo, mas é um padrão perigoso. **Correção:** substituir por um parser (ex.: extrair o array com `json_decode`/tokenizer) em vez de `eval`.

### B2 — `require_once $arquivo` com nome vindo da BD
`app/model/admin/SystemProgram.php:174` → `$arquivo` construído a partir de `$program->controller` (coluna `system_program`), sem remover `..`. LFI teórica se um admin conseguir gravar `controller` com travessia. Admin-gated → baixo. **Correção:** validar `controller` contra `[A-Za-z0-9_\\]+` antes de montar o caminho.

### B3 — md5 legado na autenticação
`app/model/admin/SystemUsers.php:17077` → `hash_equals($user->password, md5($password))`. É um **caminho de migração**: se o hash guardado for md5 legado, migra logo para bcrypt (`updatePasswordHash`, `password_hash(PASSWORD_DEFAULT)`); as palavras-passe novas usam bcrypt (`AccountService:49`, `FuncionarioUsuarioService:142/160`). Risco residual: contas dormentes mantêm md5 na BD até ao próximo login; se a BD vazar, esses hashes são fracos. **Correção:** forçar reposição de palavra-passe das contas ainda em md5.

### B4 — Aleatoriedade fraca em nomes de ficheiro (não-segurança)
`EtiquetaProdutoForm.php:156`, `CadProdutosBarCode.php:140`, `EtiquetaLocalizacaoForm.php:165`, `EtiquetaLocalizacaoComprasForm.php:165` usam `uniqid()`; `AdiantiBarcodeDocumentGenerator.php:154,167` usa `mt_rand()`. São nomes de PDFs temporários, **não** tokens de segurança — risco baixo (colisão/previsibilidade de nome em `tmp/`). Preferir `bin2hex(random_bytes())`.

### B5 — `eval` client-side em gráficos
`app/lib/widget/builder/charts/BChart.php:1084,1085` embute `eval('{$values}')` em JS gerado. Se `$values` for influenciável por dados do utilizador, é XSS/execução JS no cliente. Verificar a origem de `$values` (parece vir de configuração do gráfico). **Correção:** não gerar `eval` no cliente.

---

## FALSOS POSITIVOS (verificados — registados para não voltar a assinalar)

- **`ProcessoCadastrosList.php` e `ProcessoEtapaList.php`** (pedidos como foco): **seguros**. Todos os IDs são `(int)` (`$id=(int)$id`, `$id=(int)($param['id']??0)`, `$nicho=(int)(...)`); `$col` é ternário entre dois nomes fixos; `$tabela` vem do mapa de constantes `self::TABELAS`. Bom exemplo de interpolação de inteiros segura.
- **`ComprasService::analise()` / `::qualidadeFornecedores()`**: `$ano` é `(int)` com validação de intervalo 2000–2100 (`ComprasAnaliseDashboard:48-49`); `$desde`/`$ate` vêm de `intervalo($per)` com `$per` validado contra whitelist `PERIODOS` e datas construídas por `date()`. Sem input cru.
- **`PosVendaList.php:159-160`**: `$termo`/`$mat` passam por `$conn->quote(...)` antes da interpolação — correto.
- **`ParceirosList.php` / `VendaParceriasList.php` / `OrcamentoPartnerList.php`** (`$filterVar`): `$filterVar` é constante de classe (`GrupoPessoa::PARCEIROS`, `Setor::PRODUCAO`) ou subquery fixa escrita no código — não vem do pedido.
- **`LoginForm.php:339`**: `unserialize(..., ['allowed_classes' => false])` — correto.
- **`LogEntregaService::guardarFoto()`**: whitelist de MIME + extensão forçada + nome com `random_bytes` + `(int)` — upload seguro.
- **`RhFicheiroService.php:89,92`**: `shell_exec` com `escapeshellarg()` em ambos os argumentos — correto.
- **`stripe_webhook.php`**: valida assinatura HMAC via `StripeService::validarWebhook($payload, $cabecalho, client_secret)` — correto (modelo a seguir para a MP e o Inter).

---

## Resumo de contagem

| Gravidade | Nº |
| :--- | :--- |
| Crítico | 1 (famílias de ficheiros) |
| Alto | 3 |
| Médio | 5 |
| Baixo/Informativo | 5 |
| Falsos positivos registados | 8 |
