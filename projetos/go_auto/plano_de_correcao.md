# Plano de correção — Go Auto · Cadastro e Reposição de senha
**Data:** 2026-10-11 · **Regra:** nada se corrige antes do "sim" do Diego; tudo reversível.

## Veredicto
Os fluxos **funcionam**, mas **não estão suficientemente seguros**. O registo e o login já guardam a senha em bcrypt (bom), mas o **reset volta a gravar em MD5** e o **link de reposição é manipulável** — dois pontos sérios de tomada de conta. Recomenda-se corrigir **C1 + A1 + A2 + A3 antes de abrir o registo/reset ao público**.

## Ordem sugerida (por risco)
| # | Correção | Gravidade | Esforço | Ficheiro |
|---|----------|-----------|---------|----------|
| C1 | Reset grava em bcrypt (não MD5) | Crítico | baixo | `ResetSenhaForm.php` |
| A1 | Link de reposição a partir de URL fixa (não `HTTP_REFERER`) | Alto | baixo | `EsqueciSenhaForm.php` |
| A2 | Token de reposição de uso único + validade 1h | Alto | médio | `ResetSenhaForm.php` (+ `EsqueciSenhaForm.php`) |
| A3 | Escapar saídas no registo (anti-XSS) + token CSRF | Alto | baixo | `cadastrar.php` |
| M1 | "Esqueci a senha" com resposta neutra (anti-enumeração) | Médio | baixo | `EsqueciSenhaForm.php` |
| M2 | Força mínima de senha (registo + reset) | Médio | baixo | `cadastrar.php`, `ResetSenhaForm.php` |
| M3 | Registo sem atribuição em massa (lista branca) | Médio | baixo | `cadastrar.php` |
| M4 | Limite por IP + captcha nos formulários públicos | Médio | médio | `cadastrar.php`, `EsqueciSenhaForm.php` |
| B1–B3 | Validar email no servidor; PT-PT; token fora do URL | Baixo | baixo | vários |

## Notas de instalação
- Tudo isto é **código** → vai num overlay que **o Diego sobe e extrai** (a segurança bloqueia o Claude de extrair código em produção).
- Nenhuma mudança apaga dados. As senhas já existentes continuam a funcionar (o login migra-as).
- Cada correção é reprovada com um teste antes de entregar (reteste).
