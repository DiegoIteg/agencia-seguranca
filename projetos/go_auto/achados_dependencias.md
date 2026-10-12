# Achados — Dependências e Cadeia de Fornecimento (Go Auto)

* **Agente:** Clara (`dependencias`) — Agência de Segurança
* **Projeto:** Go Auto (ERP) — código em `/root/work/itest`
* **Âmbito:** bibliotecas de terceiros (PHP via Composer + JS de front-end em `lib/`) com CVE conhecidos ou versões desatualizadas.
* **Modo:** só leitura. Nada foi instalado nem alterado. Nenhum segredo registado.
* **Data:** 2026-10-12

> Nota de método: versões PHP extraídas de `composer.lock` (exatas, com referência de commit) e confirmadas em `vendor/`. Versões JS extraídas dos cabeçalhos dos próprios ficheiros em `lib/`. CVE confirmados por pesquisa pública. A gravidade pondera **gravidade do CVE × exposição real no Go Auto**.

---

## 1. Inventário de versões instaladas

### 1.1 Pacotes PHP (Composer — `composer.lock`)

| Pacote | Versão instalada | Última estável | CVE/estado | Gravidade |
| :--- | :--- | :--- | :--- | :--- |
| phpmailer/phpmailer | v6.9.1 | 6.9.x / 6.10.0 | Sem CVE conhecido para 6.9.1 | Baixo |
| dompdf/dompdf | v2.0.4 | 3.x | Sem CVE p/ 2.0.4; ramo 2.x superado por 3.x; **config `setIsRemoteEnabled(true)`** (ver 2.5) | Médio |
| firebase/php-jwt | v6.10.0 | 6.11.x / 7.x | CVE-2025-45769 (disputado, Médio) | Baixo |
| bacon/bacon-qr-code | 2.0.8 | 2.0.x / 3.x | Sem CVE | Baixo |
| picqer/php-barcode-generator | v2.4.0 | 3.x | Sem CVE; uma major atrás | Baixo |
| linfo/linfo | v4.0.8 | v4.0.8 (**projeto abandonado**) | Sem patches; exposto no admin | Médio |
| masterminds/html5 | 2.8.1 | 2.9.x | Sem CVE | Baixo |
| phenx/php-font-lib | 0.5.4 | 0.5.x | Dep. do dompdf 2.x; sem CVE | Baixo |
| phenx/php-svg-lib | 0.5.1 | 0.5.x | Dep. do dompdf 2.x; sem CVE | Baixo |
| sabberworm/php-css-parser | 8.4.0 | 8.x | Sem CVE | Baixo |
| dasprid/enum | 1.0.5 | 1.0.x | Sem CVE | Baixo |
| adianti/plugins | **dev-master** | — | **Dependência não fixada** (ver 2.3) | Médio |
| adianti/pdfdesigner | **dev-master** | — | **Dependência não fixada** (ver 2.3) | Médio |
| pablodalloglio/ole | **dev-master** | — | **Dependência não fixada** (ver 2.3) | Médio |
| pablodalloglio/spreadsheet_excel_writer | **dev-master** | — | **Dependência não fixada** (ver 2.3) | Médio |
| pablodalloglio/fpdf | **dev-master** | — | **Dependência não fixada** (ver 2.3) | Médio |
| pablodalloglio/phprtflite | **dev-master** | — | **Dependência não fixada** (ver 2.3) | Médio |
| madbuild3r/pquery | **dev-master** | — | **Dependência não fixada** (ver 2.3) | Médio |

### 1.2 Bibliotecas JS de front-end (`lib/`)

| Biblioteca | Versão instalada | Ficheiro | CVE/estado | Gravidade |
| :--- | :--- | :--- | :--- | :--- |
| DataTables | **1.10.7 (2015)** | `lib/jquery/js/jquery.dataTables.min.js` | CVE-2020-28458 (prototype pollution), CVE-2021-23445 (XSS) | **Alto** |
| Summernote | **0.8.18** | `lib/bootstrap/js/summernote.js` | CVE-2024-37629, CVE-2024-29504 (XSS) | **Alto** |
| Bootstrap | 4.3.1 | `lib/bootstrap/js/bootstrap.js` | Bootstrap 4 em **fim de vida** (sem patches de segurança) | Baixo |
| jQuery | 3.6.1 | `lib/jquery/js/jquery.min.js` | Protegido dos XSS major (corrigidos em 3.5.0); uma minor atrás (3.7.1) | Baixo |
| jQuery UI | 1.13.2 | `lib/jquery/js/jquery-ui.js` | 1.13.2 já corrige CVE-2022-31160 | Baixo |
| jQuery Migrate | 3.0.0 (2016) | `lib/jquery/js/jquery-migrate-3.0.0.js` | Muito antigo; sem CVE direto | Baixo |
| Select2 | 4.0.10 | `lib/jquery/js/select2.js` | Sem CVE relevante | Baixo |
| bootstrap-datepicker | 1.7.1 (2017) | `lib/bootstrap/js/bootstrap-datepicker.js` | Projeto dormente/EOL; sem CVE confirmado p/ 1.7.1 | Baixo |
| bootstrap-colorpicker | 2.5.1 | `lib/bootstrap/js/bootstrap-colorpicker.js` | Sem CVE relevante | Baixo |
| Popper | v1/v2 (misto) | `lib/bootstrap/js/popper.*.js` | Sem CVE relevante | Baixo |

### 1.3 Framework

| Componente | Versão | Origem | Estado |
| :--- | :--- | :--- | :--- |
| Adianti Framework | **7.5.1** | `lib/VERSION` (incluído no repo, não via Composer) | Manter atualizado; sem CVE público específico identificado |

> Não existe `package.json`/`package-lock.json` no projeto (raiz, `app/`, `lib/`): as libs JS são incluídas como ficheiros estáticos, pelo que **não há gestão de versões nem atualização automática** do front-end — fator que agrava os achados 2.1 e 2.2.

---

## 2. Achados por gravidade

### CRÍTICO
Nenhum achado de dependências classificado como Crítico. (As falhas exploráveis "já" encontradas no Go Auto são de código/configuração — ver `achados.md` da Nádia/Paulo; aqui só se reportam componentes de terceiros.)

---

### ALTO

#### 2.1 — DataTables 1.10.7 (2015): XSS e prototype pollution
* **Pacote + versão:** DataTables **1.10.7** (`lib/jquery/js/jquery.dataTables.min.js`), lançada em 2015 — cerca de **10 anos desatualizada**.
* **CVE / descrição:**
  * **CVE-2021-23445** — Cross-Site Scripting (XSS): dados de célula não escapados são interpretados como HTML.
  * **CVE-2020-28458** — Prototype Pollution: poluição de `Object.prototype` via opções/dados, que pode levar a XSS ou alteração de comportamento no cliente.
* **Versão que corrige:** 1.10.23 / 1.11.0 (prototype pollution) e **1.11.3** (XSS). Recomenda-se a linha 1.13.x atual.
* **Risco de negócio:** o Go Auto é um ERP **multiempresa** onde dados introduzidos por um utilizador (nomes de clientes, descrições de produtos, moradas, observações) são listados em tabelas. Se esses dados chegarem ao DataTables sem escape, um utilizador mal-intencionado (ou um cliente de um tenant) pode guardar código que **executa no navegador de outro utilizador/gestor** (roubo de sessão, ações em nome da vítima). XSS armazenado é plausível neste contexto.
* **Esforço de atualização:** Médio. Substituir o ficheiro pela versão atual do DataTables e validar que os plugins associados (`dataTables.responsive`) continuam compatíveis. Requer reteste funcional das listagens (Beatriz/Hélder).

#### 2.2 — Summernote 0.8.18: XSS no editor de texto rico
* **Pacote + versão:** Summernote **0.8.18** (`lib/bootstrap/js/summernote.js` / `.min.js`).
* **CVE / descrição:**
  * **CVE-2024-37629** — XSS através da vista de código ("Code View") do editor.
  * **CVE-2024-29504** — XSS por consumo de memória/conteúdo manipulado.
  * O projeto Summernote está **praticamente inativo**; não há release estável que corrija estes CVE (Snyk: "versões *").
* **Versão que corrige:** sem correção oficial disponível — mitigação por sanitização no servidor ou substituição do editor.
* **Risco de negócio:** editores de texto rico guardam HTML. Conteúdo criado por um utilizador (ex.: modelos de e-mail, descrições, notas) é depois **mostrado a outros utilizadores**. Sem sanitização do lado do servidor, isto é um vetor direto de **XSS armazenado** — especialmente perigoso num ERP com perfis de gestor/admin.
* **Esforço de atualização:** Médio-Alto. Não basta atualizar (não há patch). Mitigação: **sanitizar o HTML no servidor** (allowlist de etiquetas) antes de guardar/apresentar, ou migrar para um editor mantido. Decisão a validar pelo Diego.

---

### MÉDIO

#### 2.3 — Dependências Composer não fixadas (`dev-master`)
* **Pacotes:** `adianti/plugins`, `adianti/pdfdesigner`, `pablodalloglio/ole`, `pablodalloglio/spreadsheet_excel_writer`, `pablodalloglio/fpdf`, `pablodalloglio/phprtflite`, `madbuild3r/pquery` — todos pedidos como **`dev-master`** no `composer.json`.
* **Descrição:** `dev-master` segue sempre o último commit do ramo principal, sem versão fixa. O `composer.lock` fixa um commit atual, mas qualquer `composer update` pode trazer código novo e não revisto. É um risco de **cadeia de fornecimento** (supply chain): se uma destas contas/repos for comprometida, código arbitrário entra no ERP numa atualização de rotina.
* **Versão que corrige:** fixar tags/versões estáveis (ou pelo menos fixar commits e exigir revisão antes de atualizar).
* **Risco de negócio:** atualização "inocente" pode introduzir regressões ou código malicioso em produção. Probabilidade baixa, impacto alto.
* **Esforço:** Baixo-Médio (alterar constraints, testar instalação reproduzível).

#### 2.4 — linfo 4.0.8: projeto abandonado, exposto no admin
* **Pacote + versão:** `linfo/linfo` **v4.0.8**.
* **Descrição:** o projeto Linfo está **arquivado/abandonado** (sem manutenção nem patches de segurança). É usado em `app/control/admin/SystemInformationView.php` (`use Linfo\Linfo;`) para mostrar informação do sistema (CPU, memória, discos, rede, processos).
* **Versão que corrige:** não há — biblioteca descontinuada.
* **Risco de negócio:** historicamente o Linfo teve XSS refletido. A exposição no Go Auto é **limitada a utilizadores admin** (ecrã de informação de sistema), o que reduz a probabilidade, mas a página revela informação de infraestrutura sensível (processos, rede, discos) que não devia estar acessível além do estritamente necessário. Sem patches futuros, qualquer falha nova fica por corrigir.
* **Esforço:** Médio. Restringir o acesso ao ecrã, ou substituir a dependência por recolha própria de métricas. Decisão de negócio (o ecrã é mesmo necessário?).

#### 2.5 — dompdf 2.0.4 + remote ativado (ramo EOL)
* **Pacote + versão:** `dompdf/dompdf` **v2.0.4** (último do ramo 2.x; existe 3.x atual).
* **Descrição:** o 2.0.4 não tem CVE conhecido por si, **mas**: (a) o ramo 2.x está superado pelo 3.x (sem futuras correções de segurança); (b) em `app/lib/html/AdiantiHTMLDocumentParser.php` (linha ~447) o dompdf é instanciado com **`setIsRemoteEnabled(true)`** quando não há opções explícitas. Este parser gera os PDF de orçamentos, ordens de serviço/compra, guias de picking e etiquetas — documentos cujo HTML inclui **dados de registos** (clientes, produtos, moradas) potencialmente controlados pelo utilizador.
  * Com `isRemoteEnabled=true`, HTML/CSS com recursos remotos (ex.: `<img src>`, `@font-face`) fazem o servidor buscar URLs → superfície de **SSRF**. O `setChroot(getcwd())` limita ficheiros locais mas **não** desliga o acesso remoto.
  * *Nota de coordenação:* a exploração concreta (que campos chegam ao HTML sem escape) é da área da Nádia (web) e do Paulo (código); aqui fica o alerta do lado da dependência/configuração.
* **Versão que corrige:** atualizar para **dompdf 3.x** e **desligar `isRemoteEnabled`** por omissão (só ativar onde for mesmo necessário, com allowlist de domínios).
* **Risco de negócio:** SSRF pode permitir ao atacante fazer o servidor contactar serviços internos/metadados do alojamento. Probabilidade depende do escape dos dados; precaução justifica Médio.
* **Esforço:** Médio (migração 2.x→3.x exige reteste da geração de PDF) + Baixo (mudar a flag).

---

### BAIXO

#### 2.6 — Front-end genericamente desatualizado / EOL
* **Bootstrap 4.3.1** — Bootstrap 4 em fim de vida (sem patches). O XSS CVE-2019-8331 já está corrigido no 4.3.1, logo não há CVE explorável, mas a stack devia migrar para 5.x a médio prazo.
* **jQuery 3.6.1** — segura dos XSS major (corrigidos no 3.5.0); apenas uma minor atrás do 3.7.1.
* **jQuery Migrate 3.0.0 (2016)**, **bootstrap-datepicker 1.7.1**, **Select2 4.0.10**, **Popper**, **bootstrap-colorpicker 2.5.1** — todos antigos/dormentes, sem CVE explorável confirmado no contexto do Go Auto. Atualizar por higiene, não por urgência.
* **Risco de negócio:** baixo e teórico; acumulam dívida técnica e dificultam futuras correções.
* **Esforço:** Médio-Alto se feito em bloco (Bootstrap 4→5 é uma migração grande).

#### 2.7 — firebase/php-jwt 6.10.0 (CVE-2025-45769, disputado)
* **Descrição:** CVE-2025-45769 (CVSS 6.5, Médio) descreve "encriptação fraca" por comprimento de chave; **está marcado como disputado** — os mantenedores alegam que o comprimento da chave é responsabilidade da aplicação, não da biblioteca. As falhas clássicas de confusão de algoritmo já estão corrigidas desde o 6.0.
* **Versão que corrige:** 7.x (mudança major) — avaliar sem urgência.
* **Risco de negócio:** baixo/teórico desde que a aplicação use chaves fortes e algoritmo fixo (a validar com o Gonçalo/Paulo onde o JWT é verificado).
* **Esforço:** Baixo (constraint), mas 7.x pode ter breaking changes.

#### 2.8 — Pacotes PHP ligeiramente atrás (sem CVE)
`phpmailer 6.9.1` (→6.10.0), `picqer/php-barcode-generator 2.4.0` (→3.x), `bacon/bacon-qr-code 2.0.8`, `masterminds/html5 2.8.1` — sem CVE conhecido; atualizar em ciclo normal de manutenção.

---

## 3. Resumo (contagem por gravidade)

| Gravidade | Nº | Achados |
| :--- | :--- | :--- |
| Crítico | 0 | — |
| Alto | 2 | 2.1 DataTables 1.10.7 (XSS + prototype pollution); 2.2 Summernote 0.8.18 (XSS) |
| Médio | 3 | 2.3 Dependências Composer `dev-master`; 2.4 linfo 4.0.8 (abandonado, admin); 2.5 dompdf 2.0.4 + `isRemoteEnabled(true)` (SSRF/EOL) |
| Baixo | 3 | 2.6 Front-end desatualizado/EOL; 2.7 php-jwt 6.10.0 (CVE disputado); 2.8 pacotes PHP atrás sem CVE |

## 4. Recomendação de prioridade (a validar pelo Diego)
1. **Já:** mitigar XSS do Summernote (sanitizar HTML no servidor) e atualizar DataTables para 1.13.x.
2. **Esta semana:** fixar as dependências `dev-master` em versões/commits revistos; rever necessidade e acesso do ecrã Linfo.
3. **Próximo ciclo:** migrar dompdf 2.x→3.x e desligar `isRemoteEnabled` por omissão; planear migração Bootstrap 4→5 e atualização do resto do front-end.

> **Pendente de coordenação:** confirmar com a Nádia (web) e o Paulo (código) se os dados que alimentam DataTables, Summernote e o HTML do dompdf chegam já escapados/sanitizados — isso define se 2.1, 2.2 e 2.5 sobem a Alto/Crítico ou se são risco contido.
> **Confirmado por pesquisa pública:** CVE-2021-23445, CVE-2020-28458 (DataTables); CVE-2024-37629, CVE-2024-29504 (Summernote); CVE-2025-45769 (php-jwt, disputado). dompdf 2.0.4 sem CVE próprio conhecido.
