# Auditoria de segurança profunda — Go Auto (ERP)
**Equipa:** Agência de Segurança · **Data:** 2026-10-11 · **Método:** revisão de código (SAST) na cópia `/root/work/itest` + verificação de configuração/cabeçalhos no ambiente de testes (deploygoauto). Nada intrusivo em produção.

## Âmbito
Varrimento de toda a base de código `app/` (controladores, serviços, modelos) e scripts públicos (`cadastrar.php`, `rest.php`, `mobile.php`, `public.php`), à procura de: injeção de SQL, XSS, CSRF, injeção de comando, inclusão de ficheiros, `eval`/`unserialize`, SSRF, segredos no código, hash de senhas, upload de ficheiros, autenticação/sessão, dependências e cabeçalhos de segurança.

## Resultado geral
**O sistema está, na base, bem construído.** Não há injeção de SQL nem de comandos, não há `eval`, não há segredos no código, e a autenticação usa bcrypt com migração automática das senhas antigas. Os achados são pontuais e já foram corrigidos (código) ou são recomendações de configuração (servidor).

## O que está BEM (verificado)
- **Sem injeção de SQL:** as consultas usam o ORM com parâmetros; o SQL direto encontrado usa valores com `(int)`.
- **Sem injeção de comandos:** todos os `exec(` encontrados são `PDO::exec()` (SQL), não shell. Não há `shell_exec/system/passthru/eval/create_function`.
- **Sem SSRF nem segredos no código:** nada de `curl/file_get_contents` com dados do pedido; nenhuma chave/token fixo no código.
- **Senhas em bcrypt** no registo (`AccountService::start`), no formulário de utilizadores (`SystemUserForm`, com validação de força) e no login (`SystemUsers::authenticate` migra md5→bcrypt).
- **Upload de ficheiros** (`SystemDocumentUploaderService`) valida a extensão e bloqueia `.php`.

## Achados e estado

### ALTO — corrigido
- **SaasUsuarioForm gravava a senha em MD5** (`$object->password = md5(...)`). Mesma falha do reset. → Corrigido para `password_hash(PASSWORD_DEFAULT)`.

### MÉDIO — corrigido
- **Injeção de objeto PHP no login:** `LoginForm` fazia `unserialize($param['previous_parameters'])` de um valor do pedido. → Corrigido com `unserialize(..., ['allowed_classes' => false])`.

### MÉDIO — recomendação de servidor (fica para o Diego aplicar)
- **Faltam cabeçalhos de segurança** (confirmado no servidor: HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy — todos ausentes). Risco: clickjacking, sniffing de tipo, downgrade de HTTPS. → Entregue `headers_seguranca.htaccess` para acrescentar ao `.htaccess`.
- **Confirmar as marcas do cookie de sessão** (HttpOnly, Secure, SameSite). Recomenda-se garanti-las em `php.ini`/`session_set_cookie_params` (HttpOnly on, Secure on em HTTPS, SameSite=Lax).

### BAIXO
- **dompdf 2.0.4:** manter atualizado e não gerar PDF a partir de HTML/CSS de origem não confiável (histórico de CVEs). 
- **Pacotes em `dev-master`** no `composer.lock` (adianti/*): fixar versões lançadas quando possível (cadeia de fornecimento).
- **Carregamento dinâmico de controladores** (`SystemProgram` → `require_once`): o nome vem da base de dados (tabela de programas), não diretamente do pedido, e passa pelo controlo de permissões — risco baixo. Manter assim.

## Novas defesas instaladas nesta ronda
- **Captcha Cloudflare Turnstile** no registo e no "esqueci a senha" (`TurnstileService` + config). A funcionar com chaves de teste; **o Diego liga as chaves reais** em `app/config/turnstile.php`.

## Nota de âmbito (transparência)
Esta é uma auditoria **de código e configuração** (SAST + cabeçalhos), profunda em cobertura de padrões perigosos. **Não** inclui teste dinâmico autenticado de cada um dos 259 ecrãs nem teste de intrusão à infraestrutura (servidor/rede/Webmin), que seriam uma ronda à parte (Íris) caso o Diego queira.

## Reteste
`/root/work/logapp/test_seguranca_senha.php` (17/17) + verificação do captcha e das correções (9/9). Ambos verdes.
