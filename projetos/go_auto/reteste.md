# Reteste — Go Auto · Cadastro e Reposição de senha
**Data:** 2026-10-11 · **Arnês:** `/root/work/logapp/test_seguranca_senha.php` · **Resultado: 17/17 verde.**

Correções aplicadas na cópia de trabalho e reprovadas:

| Achado | Estado | Prova |
|--------|--------|-------|
| C1 — reset gravava MD5 | **Fechado** | nova senha guardada em bcrypt (`$2y$`), `password_verify` OK, não é hex de 32 |
| A1 — link via HTTP_REFERER | **Fechado** | `HTTP_REFERER` removido; link montado a partir do esquema+host do pedido |
| A2 — token reutilizável | **Fechado** | link reutilizado recusado; token ligado à senha atual (uso único); validade 1h; expirado recusado; impressão forjada recusada |
| A3 — XSS no registo | **Fechado** | saídas escapadas com `htmlspecialchars`; token anti-CSRF + honeypot |
| M1 — enumeração de utilizadores | **Fechado** | mensagem neutra "Se existir uma conta…" |
| M2 — força de senha | **Fechado** | ≥8 com letras e números, no registo e no reset |
| M3 — mass-assignment | **Fechado** | registo por lista branca (sem `fromArray($_POST)`) |
| M4 — spam/robôs | **Mitigado** | honeypot + limite por sessão (registo); limite por sessão (esqueci). Captcha externo (Turnstile) fica como opção futura com as chaves do Diego |
| B1 — validação de email | **Fechado** | `FILTER_VALIDATE_EMAIL` no servidor |
| B2 — PT-PT | **Fechado** | "palavra-passe", "utilizador", "Repor", mensagens corrigidas |
| B3 — token no URL | **Mitigado** | uso único + validade curta (entrega via POST fica como melhoria futura) |

**Instalação:** overlay de código — o Diego sobe `app_servidor_seguranca_senhas.zip` para a `public_html` e extrai. Nada apaga dados; senhas atuais continuam a funcionar.
