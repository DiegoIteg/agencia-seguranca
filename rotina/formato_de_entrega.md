# Formato de entrega das correções

## Relatório (sempre)
`projetos/<projeto>/relatorio_de_seguranca.md`, em Docs para o Diego, com:
- **Resumo para a gestão:** quantos achados, por gravidade, e o risco em uma frase.
- **Cada achado:** o que é, onde, o que um atacante faria, risco de negócio, gravidade, como se corrige, estado.
- **Plano priorizado:** corrigir hoje / esta semana / próximo ciclo.

## Correções
- **Go Auto:** SQL idempotente (se houver base de dados) + zip relativo a `public_html` + LEIA-ME com **ONDE e COMO**, SQL de reverter, diff, testes e prints; a instalação é feita pelo Diego no Webmin. Seguir `go_auto/CLAUDE.md`.
- **Sites Wix / Agência:** alterações em rascunho, publicar só com o "sim".
- **Outros projetos:** o formato que o projeto já usa, sempre com forma de voltar atrás.

## Nunca na entrega
Valores de palavras-passe, chaves ou tokens. Referir o sítio e recomendar rotação.
