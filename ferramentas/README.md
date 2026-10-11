# Ferramentas (defensivas) e como usar

Todas se usam **só em alvos autorizados do Diego** e, quando intrusivas, **em ambiente de testes**.

| Ferramenta | Para quê | Notas |
| :--- | :--- | :--- |
| Playwright | Percorrer a aplicação e testar entradas no navegador | No ambiente de testes; login pelo Diego |
| Pedidos HTTP (curl/python) contidos | Testar parâmetros, cabeçalhos, autenticação | Só o alvo autorizado |
| Pesquisa por padrões (grep/ripgrep) | Varrer o código à procura de padrões perigosos | Confirmar sempre à mão |
| `composer audit`, `npm audit` | Falhas conhecidas nas dependências | Leitura dos ficheiros de dependências |
| Verificadores de TLS/cabeçalhos | Configuração do servidor | Não-intrusivo |

**Nunca** se usam ferramentas para atacar terceiros, nem se criam ferramentas ofensivas. Prova de conceito só para demonstrar ao Diego, contida no ambiente dele.
