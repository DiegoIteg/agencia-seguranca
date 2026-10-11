# Checklist OWASP (uso defensivo, só em alvos autorizados do Diego)

Para cada ponto: **testar no ambiente de testes**, registar em `achados.md` com gravidade.

## A01 Controlo de acessos
- [ ] Trocar um id na URL mostra dados de outro utilizador/empresa? (IDOR)
- [ ] No Go Auto: SQL em bruto sem `tenant_id`/`create_unit` → fuga entre empresas?
- [ ] Páginas de administração acessíveis sem perfil?
- [ ] Métodos `static=1` que deviam exigir login/perfil?

## A02 Falhas criptográficas
- [ ] Palavras-passe com hash forte (bcrypt/argon2)? Nunca texto simples/MD5/SHA1.
- [ ] HTTPS em todo o lado; TLS antigo desligado.
- [ ] Dados sensíveis cifrados em repouso quando necessário.

## A03 Injeção
- [ ] SQL: consultas preparadas em todo o lado; nenhum `. $_GET`/`. $_POST` dentro de SQL.
- [ ] Comandos do sistema com entrada do utilizador?
- [ ] XSS: saída escapada em HTML, atributos e JS.

## A04 Desenho inseguro
- [ ] Limites de tentativas (login, recuperação de senha).
- [ ] Fluxos sensíveis com confirmação.

## A05 Configuração fraca
- [ ] Erros não aparecem ao utilizador (sem stack traces).
- [ ] Painéis (Webmin, phpMyAdmin) não expostos.
- [ ] Cabeçalhos: HSTS, CSP, X-Content-Type-Options, X-Frame-Options.
- [ ] Cookies `Secure`, `HttpOnly`, `SameSite`.

## A06 Componentes vulneráveis
- [ ] composer/npm sem CVE conhecido; nada em fim de vida.

## A07 Autenticação
- [ ] Senha forte, bloqueio, sessão que expira, recuperação de senha segura.

## A08 Integridade (software e dados)
- [ ] `unserialize` de dados do utilizador? Uploads validados por tipo e conteúdo.

## A09 Registo e monitorização
- [ ] Há registo de acessos e de erros; alertas de atividade estranha.

## A10 SSRF
- [ ] Pedidos do servidor a URLs controladas pelo utilizador são validados.
