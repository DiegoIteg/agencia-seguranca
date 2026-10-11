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
