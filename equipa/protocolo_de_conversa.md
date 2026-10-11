# Protocolo de Conversa da Equipa de Segurança

> Cada auditoria tem um quadro de conversa, `projetos/<projeto>/conversa.md`, onde se pedem coisas, se entregam achados, se discorda e se decide. Antes de começar, cada agente lê as mensagens que lhe foram dirigidas; no fim, escreve o que fez e a quem passa.

## 1. Formato de cada mensagem
```
### AAAA-MM-DD HH:MM · De: <Nome> → Para: <Nome(s) | Equipa | Diego>
**Tipo:** Pedido | Achado | Entrega | Pergunta | Opinião | Discordância | Decisão | Aprovação
**Assunto:** …
Texto curto. Ficheiros: `…`
**Próximo passo:** quem faz o quê, até quando.
```

## 2. Reuniões (escritas na conversa.md)
| Reunião | Quando | Quem | Resultado |
| :--- | :--- | :--- | :--- |
| **Âmbito** | No início | Vítor (abre) + Diego | Alvo confirmado como do Diego, autorização, ambiente |
| **Triagem** | Análise feita | Todos apresentam os achados; Vítor classifica o risco | Lista priorizada |
| **Plano de correção** | Triagem feita | Vítor consolida → **Diego valida** | "Sim", ajustes ou "não" como **Decisão** |
| **Reteste** | Correção aplicada | Quem achou confirma que fechou | Fechado / Reabrir |

## 3. Regras
- Nunca escrever segredos (palavras-passe, chaves, tokens) na conversa — referir o sítio.
- Nada se corrige sem **Aprovação** do Diego registada.
- Cada achado tem um dono até ser **Resolvido**.
