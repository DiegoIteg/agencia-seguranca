# Autorização e âmbito — Go Auto · Cadastro e Reposição de senha

- **Projeto / alvo:** Go Auto (ERP do Diego) — fluxos de **registo de conta/utilizador** (`cadastrar.php` → `AccountService::start`) e **reposição de palavra-passe** (`EsqueciSenhaForm` → email → `ResetSenhaForm`), mais o login (`ApplicationAuthenticationService` / `SystemUsers::authenticate`).
- **Dono:** Diego (iTEG4Business). É do próprio.
- **Autorização:** o Diego pediu esta revisão nesta conversa — confirmada: [x] Sim
- **Ambiente:** revisão de **código** (leitura) na cópia de trabalho `/root/work/itest`. Nada se corre contra produção. Sem testes intrusivos.
- **Fora de âmbito:** não se altera nada sem o "sim" do Diego; palavras-passe/chaves/tokens nunca são escritos na conversa nem em ficheiros.
- **Dados reais:** não aplicável (revisão de código).
- **Data:** 2026-10-11
