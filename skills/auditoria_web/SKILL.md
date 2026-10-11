---
name: "auditoria_web"
description: "Como auditar uma aplicação web ou API do Diego à procura de vulnerabilidades OWASP, em ambiente de testes e dentro do âmbito autorizado."
---
# Auditoria Web

## Antes de começar
Confirmar `projetos/<projeto>/autorizacao.md`: alvo é do Diego, ambiente = testes/cópia. Login feito pelo Diego.

## Passos
1. **Mapa:** listar páginas, APIs, formulários, uploads, parâmetros e o login (`ambito.md`).
2. **Por cada entrada**, testar com valores contidos: aspas e `OR 1=1` (injeção), `<script>` inofensivo (XSS), trocar ids (IDOR), pedidos sem token (CSRF).
3. **Autenticação/sessão:** senha fraca, bloqueio, expiração, recuperação.
4. **Configuração:** cabeçalhos, cookies, mensagens de erro.
5. Ferramentas: Playwright e pedidos HTTP contidos; prova de conceito mínima.

## Entrega
Cada achado em `achados.md`: passo a passo, pedido, o que se conseguiu, gravidade, correção.

## Nunca
Fora do alvo; produção com dados reais; guardar o que apanhar.
