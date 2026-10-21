# Autorização e âmbito — Go Auto · Cadastro e Reposição de senha

- **Projeto / alvo:** Go Auto (ERP do Diego) — fluxos de **registo de conta/utilizador** (`cadastrar.php` → `AccountService::start`) e **reposição de palavra-passe** (`EsqueciSenhaForm` → email → `ResetSenhaForm`), mais o login (`ApplicationAuthenticationService` / `SystemUsers::authenticate`).
- **Dono:** Diego (iTEG4Business). É do próprio.
- **Autorização:** o Diego pediu esta revisão nesta conversa — confirmada: [x] Sim
- **Ambiente:** revisão de **código** (leitura) na cópia de trabalho `/root/work/itest`. Nada se corre contra produção. Sem testes intrusivos.
- **Fora de âmbito:** não se altera nada sem o "sim" do Diego; palavras-passe/chaves/tokens nunca são escritos na conversa nem em ficheiros.
- **Dados reais:** não aplicável (revisão de código).
- **Data:** 2026-10-11

---
## Ronda 2026-10-17 — isolamento entre empresas, segredos e palavras-passe (pedido do Diego na conversa)
- **Pedido:** «qualquer problema deve ser também corrigido, acione o agente necessário, senhas e dados da Veloster jamais podem aparecer» — confirmado [x] Sim (2026-10-17 08:48).
- **Alvo:** código do Go Auto na réplica local `/root/work/demo/site2` (cópia de trabalho, git), servidor local 127.0.0.1:8771. Nada contra produção.
- **Dados:** as cópias locais foram limpas antes da ronda: ficou só a empresa 1 (demonstração, fictícia); dados de outras empresas (incl. Veloster) e todos os segredos/palavras-passe apagados. Testes de isolamento usam uma 2.ª empresa FICTÍCIA criada para o efeito.
- **Entrega:** correções no pack v37 (com cópia de segurança e desfazer), só instaladas com o "sim" do Diego.
