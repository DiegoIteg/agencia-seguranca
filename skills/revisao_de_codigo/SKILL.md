---
name: "revisao_de_codigo"
description: "Como ler código (PHP/Adianti/JS) à procura de padrões perigosos: SQL concatenado, falta de escopo multi-empresa, saída sem escape, funções perigosas, segredos."
---
# Revisao De Codigo

## Padrões a procurar (confirmar sempre à mão)
- SQL concatenado: `WHERE ... " . $_GET`, variáveis dentro de `query("...")`, sem consulta preparada.
- Falta de escopo multi-empresa: SQL em bruto sem `tenant_id`/`create_unit` (Go Auto).
- Saída sem escape: `echo $x` em HTML → XSS. Usar escape/htmlspecialchars.
- Funções perigosas: `eval`, `exec`, `system`, `shell_exec`, `unserialize` de entrada, `include`/`require` com caminho do utilizador.
- Segredos escritos à mão: chaves/senhas/tokens → referir o sítio, passar ao Gonçalo, recomendar rotação.
- Autorização: ações que gravam sem verificar o perfil; `static=1` indevido.

## Como
Pesquisa por padrões (grep) para varrer, depois confirmação manual (os varrimentos têm falsos positivos). Cada achado com ficheiro e linha em `achados.md`.
