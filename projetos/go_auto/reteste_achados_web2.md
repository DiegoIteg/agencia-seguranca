# Go Auto — 2.ª vaga de auditoria web (Nádia) — achados

**Data:** 2026-10-12 · **Âmbito:** ERP Go Auto (PHP 8.3 + Adianti 7.5), cópia em `/root/work/itest` · **Tipo:** auditoria defensiva, só leitura, autorizada.
**Regra cumprida:** nenhum segredo (seed/token/chaves) transcrito; referências por `ficheiro:linha`.
**Nota:** não se repetem os achados já corrigidos na 1.ª ronda (backdoor, .htaccess de .db/.ini, instalador, unserialize do `download.php`, webhooks, ferramentas dev, JWT exp, logs mascarados, cookies, 2FA, uploads autenticados). Aqui está **o que faltou**.

## Resumo por gravidade
| Gravidade | N.º |
| :--- | :--- |
| Crítico | 1 |
| Alto | 2 |
| Médio | 4 |
| Baixo | 2 |

**Críticos**
- **A1 — Injeção de objetos PHP (unserialize) + extração de qualquer tabela via MultiSearch/Autocomplete públicos:** o `hash` de validação não cobre os parâmetros `criteria` (passado a `unserialize()`) nem `mask`/`column`, por isso qualquer utilizador autenticado reutiliza um hash legítimo e controla o payload desserializado e os campos devolvidos.

**Altos**
- **A2 — IDOR entre empresas (falta de scoping por `tenant_id`):** `onEdit`/`onDelete`/listagens carregam registos só pela `key`, sem confirmar que o registo pertence à empresa do utilizador; o portão (`engine.php`) só valida permissão de ECRÃ, não de REGISTO.
- **A3 — Upload anónimo + allowlist contornável no `AdiantiUploaderService`:** classe pública; sem o parâmetro `extensions` só resta a lista negra, e um anónimo escreve ficheiros no servidor (DoS/estacionamento de malware).

---

## A1 — [CRÍTICO] MultiSearch/Autocomplete: unserialize de `criteria` e extração de dados arbitrários
**O que é.** `AdiantiMultiSearchService` e `AdiantiAutocompleteService` são **classes públicas** (`application.ini`, `public_classes[]`) e estão também em `getDefaultPermissions()` (`engine.php`), logo qualquer sessão (anónima no caso do hash, e qualquer utilizador autenticado na prática) as pode invocar. Ambas:
1. Só correm se `md5(seed+database+key+column+model) == $param['hash']` — **mas o hash NÃO inclui `criteria`, `mask`, `value`, `operator` nem `orderColumn`**.
2. Fazem `unserialize(base64_decode($param['criteria']))` — sink clássico de **PHP Object Injection**.
3. Constroem a consulta com `model`, `column` e `mask` vindos do pedido, **sem qualquer filtro de `tenant_id`**, e devolvem até 1000 registos renderizando `mask` com `$object->render(...)` + substituição de métodos.

**Onde.**
- `lib/adianti/service/AdiantiMultiSearchService.php:73` (cálculo do hash sem `criteria`/`mask`), `:77` (`==`), `:90` (`unserialize(base64_decode(...))`), `:160-167` (`load` sem scoping + `render($mask)`).
- `lib/adianti/service/AdiantiAutocompleteService.php:51` (hash), `:54` (`==`), `:67` (`unserialize(base64_decode(...))`), `:83-92` (`load` + `render($mask)`).

**O que um atacante faz.** Em utilização normal, qualquer widget de pesquisa envia um pedido com um `hash` válido para um par `(database,key,column,model)` dos ecrãs do próprio utilizador — visível na rede do browser dele. Como `criteria` e `mask` ficam **fora** do hash, o atacante reenvia esse mesmo hash com:
- um `criteria` malicioso → `unserialize()` de um objeto à escolha (cadeia de *gadgets* em Adianti/Composer pode levar a escrita de ficheiros/RCE — mesma classe do unserialize corrigido na 1.ª ronda, aqui ainda aberto);
- um `mask` tipo `{id}::{password}` e outra `column`/`model` → dumping de colunas sensíveis de qualquer modelo **sem filtro de empresa** (ex.: `SystemUsers`, `Pessoa`).

**Risco de negócio.** Fuga potencial de toda a base (clientes, utilizadores, dados fiscais) e, via *object injection*, comprometimento do servidor. É o achado mais grave desta vaga.

**Correção.**
1. Retirar `AdiantiMultiSearchService`, `AdiantiAutocompleteService` (e `AdiantiUploaderService`) de `public_classes[]`; exigir sessão iniciada (ficam disponíveis a utilizadores logados por `getDefaultPermissions`, que é o uso legítimo).
2. Substituir `unserialize()` por desserialização segura (`JSON`) **ou** incluir `criteria` e `mask` no hash assinado e validar com `hash_equals()`.
3. Validar `model`/`column` contra uma *allowlist*; aplicar filtro de `tenant_id` do utilizador da sessão às consultas.
**Verificação.** Reenviar um pedido legítimo trocando só `criteria`/`mask`/`model` → deve ser rejeitado (hash inválido) e nunca desserializar; confirmar que um utilizador da empresa A não obtém registos da empresa B.

---

## A2 — [ALTO] IDOR entre empresas: registos abertos/apagados só pela `key`, sem scoping por `tenant_id`
**O que é.** Os modelos de negócio têm coluna de inquilino (`tenant_id` em `Orcamento` e `Pessoa`; p.ex. `app/model/.../Orcamento.php:77`, `Pessoa.php:47`) e a sessão guarda `tenant_id`/`account_id` no login (`ApplicationAuthenticationService.php:127-128,246-253`). Porém:
- O portão `engine.php` só verifica se o utilizador tem permissão do **ECRÃ** (`$programs[$class]`) e a ação (criar/alterar) — **nunca** se o REGISTO pedido é da empresa dele.
- Os `onEdit` carregam `new Modelo($param['key'])` **sem `tenant_id`**: `OrcamentoForm.php:1894` (`new Orcamento($key)`), `CadastroDeClientesForm.php:446` (`new Pessoa($key)`), `ViaturaForm.php:153` (`new Viatura($key)`). Padrão repetido em ~112 controllers Form de negócio.
- O apagar tem o mesmo defeito: `OrcamentoList.php:461-463` (`new Orcamento($key, FALSE); $object->delete();`).
- Até as listagens não filtram por empresa: `OrcamentoList.php:87` (`filter_criteria = new TCriteria` sem `tenant_id`) e `:1003-1060` (`onReload` nunca adiciona filtro de inquilino). Não existe filtro global de inquilino em `init.php`/ActiveRecord.

**O que um atacante faz.** Um utilizador legítimo da empresa A, com permissão do ecrã de Orçamentos, muda a `key` no URL (`index.php?class=OrcamentoForm&method=onEdit&key=<id_de_B>`) e lê/edita o orçamento da empresa B; o mesmo para clientes, viaturas, pós-venda, etc.; e apaga registos de B com `&method=onDelete&key=<id_de_B>&delete=1`.

**Risco de negócio.** Quebra total do isolamento multi-empresa do SaaS: confidencialidade e integridade dos dados de todos os clientes do Go Auto.

**Real vs. falso positivo.** O defeito **existe no código hoje**. Na cópia `test.db` há **apenas 1 conta** (`account`=1 registo; `orcamento`/`pessoa` sem múltiplos `tenant_id`), por isso **não é explorável enquanto houver um só inquilino**. Como o produto é multi-empresa (modelos `Account`/`contrato`, `saas_admin`, onboarding), **torna-se Crítico no momento em que existir uma 2.ª empresa**. Classificado **Alto** por isso.

**Correção.** Centralizar o scoping: ao carregar/alterar/apagar por `key`, adicionar sempre `tenant_id = TSession::getValue('tenant_id')` (ou um `TRecord` base/*trait* que injete o filtro em `load`/`delete` e nas listagens). Rejeitar com 404/401 quando o registo não for da empresa.
**Verificação.** Com duas empresas de teste, confirmar que A não abre nem apaga `key` de B (resposta negada), e que as listagens só mostram registos da própria empresa.

---

## A3 — [MÉDIO→ALTO] Upload anónimo e allowlist contornável (`AdiantiUploaderService`)
**O que é.** Classe **pública** (`application.ini`). Em `lib/adianti/service/AdiantiUploaderService.php:38`:
- O ficheiro só é recusado pela **lista negra** de extensões (`:42-71`). A *allowlist* por campo (`extensions`+`hash`, `:73-99`) **só é verificada se `extensions` vier no pedido** — omitindo-o, um anónimo envia qualquer extensão que não esteja na lista negra (ex.: `.svg`, `.xml`, `.zip`, imagens).
- Grava em `tmp/` (`:50,103`).

**O que um atacante faz.** Sem login, enche o disco do servidor (DoS — já há 1034 ficheiros em `tmp/`), estaciona ficheiros maliciosos e, se `tmp/` fosse servido, teria XSS armazenado via `.svg`.

**Mitigação existente (apurada).** `tmp/.htaccess` e `files/.htaccess` têm `AuthUserFile /dev/null` + `require valid-user`, ou seja **nenhum pedido web serve esses ficheiros** — isto remove a execução/serviço direto e baixa a gravidade para **Médio** (fica o DoS e o abuso de armazenamento anónimo).

**Risco de negócio.** Indisponibilidade por enchimento de disco; superfície de abuso aberta à Internet sem autenticação.

**Correção.** Tirar `AdiantiUploaderService` de `public_classes[]` (exigir sessão); validar sempre a allowlist mesmo sem `extensions`; limitar tamanho/quantidade por sessão; `hash_equals()` em vez de `===` textual.
**Verificação.** Pedido anónimo ao uploader → 401; com `extensions` omitido → recusa à mesma extensões não previstas.

---

## A4 — [MÉDIO] CSRF em ações que alteram estado por GET (sem token)
**O que é.** As ações do Adianti (incl. apagar) são acionadas por **GET** e **não há token anti-CSRF** nos formulários de negócio — só `SystemProfileForm.php:57` chama `enableCSRFProtection()`. `OrcamentoList.php:448-463` apaga diretamente com `index.php?class=OrcamentoList&method=onDelete&key=N&delete=1` (o `TQuestion` é só o caminho de UI; o URL com `delete=1` salta a confirmação). O `.htaccess` ainda publica rotas `*-ondelete`/`*-delete`.

**Mitigação existente.** `init.php:26` define `session.cookie_samesite = 'Lax'`, que bloqueia o CSRF automático mais comum (POST cross-site, `<img>`/form escondido). **Mas `Lax` deixa passar o cookie em navegação de topo por GET** (clique num link, `window.open`, `location=`), que é exatamente como estas ações destrutivas são chamadas → o CSRF por link preparado continua viável.

**O que um atacante faz.** Leva uma vítima autenticada a abrir um link que apaga/altera registos (e, combinado com A2, registos de qualquer empresa).

**Risco de negócio.** Perda/alteração de dados por engano induzido; sem rasto de consentimento.

**Correção.** Token anti-CSRF por pedido em todas as ações de escrita (`enableCSRFProtection()` ou equivalente global no `engine.php`); exigir POST para apagar/gravar; endurecer cookie para `SameSite=Strict` onde o fluxo permitir.
**Verificação.** Reproduzir o GET de apagar a partir de outro site/origem → deve ser recusado por falta de token válido.

---

## A5 — [MÉDIO] Ligação de reposição de senha confia no cabeçalho `Host` (envenenamento)
**O que é.** O fluxo de reset está, no geral, bem feito (anti-enumeração, Turnstile, JWT ligado à senha atual com uso único, expiração 1 h, `ResetSenhaForm.php:104-134` com `hash_equals`). Porém, o URL enviado por e-mail é construído a partir de `$_SERVER['HTTP_HOST']` — `EsqueciSenhaForm.php:123-125`.

**O que um atacante faz.** Pede reposição para o e-mail da vítima com um cabeçalho `Host` forjado; se o vhost for *catch-all*/por omissão, o link do e-mail aponta para o domínio do atacante e, se a vítima clicar, o token JWT vaza → tomada de conta.

**Risco de negócio.** Comprometimento de contas por sequestro do link de reposição.

**Correção.** Construir o URL a partir de um domínio canónico configurado (`application.ini`), não de `HTTP_HOST`; no Apache, fixar `ServerName`/`UseCanonicalName On` e rejeitar `Host` desconhecido.
**Verificação.** Pedir reset com `Host` falso → o link do e-mail mantém o domínio canónico.

---

## A6 — [MÉDIO] `SystemModulesCheckView` público expõe configuração do servidor
**O que é.** Classe **pública** (`application.ini`). `app/control/admin/SystemModulesCheckView.php` mostra extensões PHP carregadas e diretivas do `php.ini` (valores atuais vs. recomendados).

**O que um atacante faz.** Sem login, obtém versão de PHP, extensões e afinações do servidor — reconhecimento que facilita ataques dirigidos.

**Risco de negócio.** Divulgação de informação técnica que acelera a exploração de outras falhas.

**Correção.** Retirar de `public_classes[]` (é página de diagnóstico de instalação); restringir a administradores.
**Verificação.** Aceder sem sessão → 401/redireccionamento para login.

---

## A7 — [BAIXO] Login sem bloqueio por tentativas; enumeração de utilizador por mensagem
**O que é.** O `LoginForm.php` **regenera o id de sessão no login** (`:236` `TSession::regenerate()`) — **fixação de sessão está tratada**. Mas não há contador/bloqueio de tentativas falhadas: só `sleep(2)` (`:361`) e reCAPTCHA **opcional** (`:382`, só se o admin o ativar). Além disso, `ApplicationAuthenticationService::authenticate` distingue "utilizador não existe" (`SystemUsers::validate`, lança antes) de "senha errada" (`SystemUsers::authenticate`), permitindo enumeração de contas.

**O que um atacante faz.** Força bruta/credential stuffing limitada só pelo atraso de 2 s (paralelizável) quando o reCAPTCHA está desligado; e enumera logins válidos pelas mensagens distintas.

**Risco de negócio.** Maior probabilidade de tomada de conta por adivinhação de senha.

**Correção.** Bloqueio progressivo por conta/IP após N falhas; reCAPTCHA/Turnstile obrigatório no login após falhas; mensagem de erro genérica e igual para login inexistente e senha errada.
**Verificação.** N tentativas falhadas seguidas → bloqueio temporário; mensagens iguais nos dois casos.

---

## A8 — [BAIXO] Credenciais REST na própria URL (ficam em logs)
**O que é.** `.htaccess`: `RewriteRule ^auth/([A-Za-z0-9]*)/([A-Za-z0-9]*)$ rest.php?...&login=$1&password=$2`. A senha viaja no caminho do URL → fica em logs de acesso/proxy.

**Correção.** Receber credenciais por corpo POST (JSON), nunca na URL; remover/retrair a rota `auth/<login>/<password>`.
**Verificação.** Confirmar que o `getToken` só aceita POST e que nada de credenciais aparece nos logs.

---

## Falsos positivos / áreas verificadas e OK
- **XSS nos painéis e listagens:** a equipa escapa de forma consistente com `htmlspecialchars` (PHP 8.3 escapa aspas por omissão) — `CrmPainelDia.php:391-396`, `PainelUiService.php:187,449` (`cartao`/`textoBusca`), `ProducaoPainelHtml.php:45,84,110` (`carro`/linhas), transformadores de estado (`TercerizacaoList.php:219`, `ProducaoList.php:229`) usam rótulos fixos, não texto livre. Sem XSS explorável encontrado nestes pontos.
- **Reposição de senha (`ResetSenhaForm`)**, **cabeçalhos de segurança** (`init.php:15-23`), **cookies** (`:25-27`) e **fixação de sessão** (`LoginForm.php:236`): corretos.
- **`tmp/` e `files/`**: não serviveis por web (`.htaccess` `require valid-user`), e `.htaccess` raiz nega `.db/.ini/.log/...`.
- **`SystemPasswordResetForm`/`SystemRequestPasswordResetForm`**: são stubs vazios (sem lógica, sem risco); **`NovaContaForm`** tem rota mas **não** está em `public_classes` e `user_register=0`, logo o portão bloqueia o acesso anónimo.

## Prioridade de correção sugerida
1. **A1** (público + unserialize + extração) — já.
2. **A2** (scoping por `tenant_id`) — antes de onboarding de uma 2.ª empresa.
3. **A3/A4/A5/A6** — próxima semana.
4. **A7/A8** — ciclo seguinte.
