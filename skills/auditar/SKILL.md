---
name: auditar
description: Use antes de abrir PR, mesclar PR ou dar push direto numa branch base (main, homologacao, develop…) — audita o diff da branch contra o guia de arquitetura do projeto, segurança e boas práticas da stack, com contraprova adversarial, e grava o veredito que o hook exige para liberar a subida. Também para "auditar a branch", "revisar antes de subir", "pre-push review".
---

# Auditoria antes de subir

Cinco dimensões, com critérios numerados em `criterios/` (ao lado deste arquivo), que o auditor lê inteiros e cita em cada achado:

| Dimensão | Arquivo | O que cobre |
|---|---|---|
| Arquitetura | `arquitetura.md` | o guia do projeto manda (e o checklist dele, item a item); sem guia, os padrões recorrentes A1–A18 |
| Segurança | `seguranca.md` | S1–S16: autorização no servidor, IDOR, listas/exports, injeção, XSS, atribuição em massa, upload, segredos, sessão/CSRF, SSRF, dependências, integridade, lógica de negócio, enumeração, uso posterior/lote/restauração, LLM/MCP |
| Boas práticas | `boas-praticas-<stack>.md` + `laravel-best-practices/` + `testing-best-practices/` | Laravel (L1–L12 + a íntegra do `laravel-best-practices` e do `testing-best-practices` do Boost v2.10.3, variante Pest ou PHPUnit), Python (Y1–Y8), JS/TS (J1–J8), somadas à skill da stack do projeto, se houver |
| Ponytail | `ponytail.md` + `ponytail/` | P1–P6 + a íntegra do `ponytail` e do `ponytail-review`: correto, seguro, aguenta carga, testado, rápido, enxuto |
| Entrega | `entrega.md` | E1–E6: escopo (diff ligado ao pedido), comportamento preservado em refatoração, sintaxe/estática não coberta, evidência de navegador, integração externa testada de verdade, mudança nas regras da auditoria |

Em repositório com o arquivo `.auditoria-pre-subida` na raiz (ativação versionada pelo projeto), o hook `exige-auditoria.sh` bloqueia `gh pr create`, `gh pr merge` e `git push` direto numa branch base enquanto o commit que sobe não tiver `VEREDITO: APROVADO`. Esta skill produz esse veredito e roda também em repositório sem o arquivo (só não há bloqueio). Para ativar o bloqueio, o usuário versiona o arquivo vazio — sugira, não crie por conta própria. **Qualquer achado confirmado no que a branch toca reprova** (P0 a P3); dívida pré-existente é listada e não reprova.

Arquivos da auditoria: `D=$(git rev-parse --path-format=absolute --git-common-dir)/auditoria/<sha do HEAD>/` — fica fora do versionamento e é compartilhada pelos worktrees do repositório.

## 1. Base e escopo
- Base: o argumento da skill; senão `gh pr view --json baseRefName -q .baseRefName` (PR já aberto); senão a base indicada no `CLAUDE.md`/`AGENTS.md` do projeto; senão `git symbolic-ref --short refs/remotes/origin/HEAD`. Na dúvida, pergunte ao usuário.
- `git fetch origin <base>`; `mb=$(git merge-base origin/<base> HEAD)`.
- Árvore suja (`git status --porcelain` com alteração rastreada): pare e peça commit — a auditoria vale para um commit, não para a árvore.
- Diff vazio: nada a auditar; grave o veredito APROVADO com "diff vazio" e siga.

## 2. Validação da stack (pré-condição, sem agente)
Rode nos arquivos tocados (`git diff --name-only $mb..HEAD`) o que o projeto tiver configurado; o `CLAUDE.md`/`AGENTS.md` do projeto e as skills da stack mandam sobre esta lista:
- PHP/Laravel: `vendor/bin/pint --test <arquivos>`, `php -l`, PHPStan/Larastan se houver `phpstan.neon*`, testes dos arquivos tocados (`php artisan test --compact <arquivos de teste>`), `php artisan route:list --except-vendor` se tocou rotas.
- Python: `ruff check`/`ruff format --check`, `mypy`/`pyright` se configurado, `pytest` dos testes tocados.
- JS/TS: `eslint`/`biome`, `prettier --check`, `tsc --noEmit`, testes tocados (`vitest`/`jest`).
Falhou → `VEREDITO: REPROVADO` com a saída, sem gastar auditor. Se o ambiente tiver fila ou wrapper de testes próprio, use-o.

### Scanners
Depois da validação da stack, rode e grave a saída em `$D`. Ferramenta ausente **não reprova**: registre "não rodou: <ferramenta> não instalada" e siga. Código de saída 1 do gitleaks e 183 do TruffleHog (com `--fail`) só significam "achou"; leia o JSON.
- **Segredos commit a commit** em `$mb..HEAD` — pega o segredo que entrou e saiu dentro da branch, que o `diff.patch` final não mostra:
  - `gitleaks git --log-opts="$mb..HEAD" --redact --no-banner --report-format json --report-path "$D/gitleaks.json" .`
  - `trufflehog git file://. --since-commit "$mb" --json --no-update > "$D/trufflehog.json"` (verificação ligada: consulta a API do provedor da chave).
  - O JSON do TruffleHog traz o segredo em claro: fica só em `$D` (dentro do `.git`, fora do versionamento). **Achados, veredito e mensagens nunca copiam o valor** — só commit, arquivo, linha, detector e se foi verificado.
- **Dependências**, só se o diff tocar lockfile (senão "não se aplica"):
  - `composer.lock`: `composer audit --locked --format=json > "$D/deps-composer.json"`
  - JS: o audit do gerenciador do projeto, em JSON, `$D/deps-<npm|pnpm|yarn>.json` — `npm audit --omit=dev --json`, `pnpm audit --prod --json`, `yarn npm audit --json`
  - Python: `pip-audit --format json -o "$D/deps-pip-audit.json"`
- **Semgrep** como pistas, nunca veredito, só o achado novo da branch: `semgrep scan --baseline-commit "$mb" --metrics=off --config p/security-audit --config <pacote da stack> --json --output "$D/semgrep.json" --quiet`; pacote da stack: `p/php`, `p/python`, `p/javascript` ou `p/typescript` (um `--config` por stack tocada).
- Resumo em `$D/scanners.md`: ferramenta · versão · comando · resultado (`n achados` | `não rodou` | `não se aplica`); sem valor de segredo. O `pacote.md` aponta para ele e para os JSON.

Achado de scanner **não reprova sozinho e não pula o auditor**: entra no pacote e o auditor o transforma em achado ou o descarta com motivo (`auditor.md` § Scanners). Correção de segredo em commit da branch: revogar/rotacionar a chave **e** reescrever a branch (o segredo continua no histórico); se a branch já foi para o remoto, rotacionar é obrigatório.

## 3. Pacote
Grave em `$D`:
- `diff.patch`: `git diff $mb..HEAD`.
- `pacote.md`: **caminho absoluto da pasta `criterios/` desta skill** (o diretório base da skill + `/criterios`: `arquitetura.md`, `seguranca.md`, `boas-praticas-laravel.md`, `boas-praticas-python.md`, `boas-praticas-js.md`, `ponytail.md`, `entrega.md`, `mapa-ameacas.md` e as íntegras `laravel-best-practices/`, `testing-best-practices/` e `ponytail/`), o framework de teste do projeto (Pest ou PHPUnit), branch, base, merge-base e HEAD (curto e completo), `git log --oneline $mb..HEAD`, `git diff --stat $mb..HEAD`, stack detectada (`composer.json`, `pyproject.toml`/`requirements*.txt`, `package.json`), e as **regras do projeto na versão do merge-base**, em `$D/regras-base/` (a branch não escreve as regras pelas quais é auditada): guia de arquitetura (`wiki/`, `docs/`, `doc/` + `arquitetura`/`architecture`; ou o que o `CLAUDE.md` apontar), checklist do guia (Grep por `Checklist` no guia), mapa de ameaças, `CLAUDE.md`, `AGENTS.md`, `.claude/skills`, `.ai/skills`. Caminho absoluto do `diff.patch`.
  - Localize os caminhos no HEAD, liste os que existem no merge-base com `git ls-tree -r --name-only "$mb" -- <caminhos>` e extraia só esses: `mkdir -p "$D/regras-base" && git archive "$mb" -- <existentes> | tar -x -C "$D/regras-base"`. **Não use `<sha>:<caminho>`**: no Git Bash do Windows o argumento com `/` e `:` é convertido como lista de caminhos e quebra.
  - Regra que só existe no HEAD (a branch a criou) não entra em `regras-base/`: o pacote registra "criada na branch" e ela passa pelo `entrega § E6`.
- Para a dimensão Entrega, o `pacote.md` leva também (da sessão principal; o auditor não abre navegador nem roda teste): o **pedido original/issue e o critério de pronto**; se a tarefa é **refatoração sem pedido de mudança**; as **telas tocadas com a evidência de navegador** (perfil usado, antes × depois, ação exercitada); as **integrações externas tocadas com a evidência do teste real**; os **comandos da etapa 2 que rodaram**, por arquivo ou tipo de arquivo, com o resultado de cada um. Registre "não se aplica" (sem tela ou integração tocada, tarefa que não é refatoração) ou "sem evidência" (tocou e não há prova) — o auditor trata só o segundo como achado.
- Os scanners da etapa 2: caminho do `$D/scanners.md` e dos JSON que existirem (`gitleaks.json`, `trufflehog.json`, `deps-*.json`, `semgrep.json`).
- Reauditoria (já existe `auditoria/<sha anterior>/` desta branch, `REPROVADO`): acrescente ao pacote os achados anteriores e o `git diff <sha anterior>..HEAD`. O auditor confere as correções e audita só o delta.

Diff grande (mais de ~40 arquivos ou ~3.000 linhas): divida por domínio/pasta em até 4 fatias, um `pacote-<fatia>.md` cada, e um auditor por fatia em paralelo.

## 4. Auditor
Despache o subagente `auditoria-pre-subida:auditor` (Opus, só leitura) com o pedido: "Audite o pacote em `<D>/pacote.md`." Grave a resposta em `$D/achados.md` (fatias: concatene).
Se o ambiente impuser outro despachante para revisão (ex.: worker do Orca), use-o com o mesmo agente (`claude --agent auditoria-pre-subida:auditor`) e o mesmo pedido; vale também para o auditor de segurança abaixo e para o verificador.

**Auditor de segurança extra (condicional).** A sessão decide pelo diff, sem agente. Há gatilho se:
- `git diff --name-only $mb..HEAD` tem caminho que contém `route|controller|polic|permission|middleware|auth|livewire|filament|api|upload|webhook|mcp` (sem diferenciar maiúsculas: `grep -Ei`), ou
- `git diff $mb..HEAD -G '<regex>' --name-only` lista algo, com `<regex>` = `DB::raw|whereRaw|selectRaw|orderByRaw|havingRaw|cursor\.execute|\.raw\(|shell_exec|proc_open|subprocess|child_process|eval\(|unserialize|pickle\.loads|yaml\.load|\{!!|v-html|dangerouslySetInnerHTML|mark_safe|innerHTML|Storage::|UploadedFile|withoutMiddleware|Gate::|authorize` (regex estendida do git).

Com gatilho, despache **em paralelo** ao auditor principal uma segunda instância de `auditoria-pre-subida:auditor` com "Audite o pacote em `<D>/pacote.md` com foco: segurança." e grave a resposta em `$D/achados-seguranca.md`. Junte as duas listas em `achados.md`: mesmo Onde + mesmo critério = um achado só (fica o de caminho completo), numeração A<k> contínua. Com fatias, um auditor de segurança por fatia que tenha gatilho.

## 5. Contraprova
Com ao menos um achado "na branch", despache `auditoria-pre-subida:verificador` com "Contraprove `<D>/achados.md` com o pacote `<D>/pacote.md`." Grave em `$D/verificacao.md`. Achado REFUTADO sai; prioridade revista vale a do verificador. **INCONCLUSIVO** (o caminho fecha no código, mas depende de fato fora dele) segue para a etapa 6. Divergência que você não consegue decidir lendo o código: leve ao usuário.

## 6. Decisões do dono
Achado com "Decisão do dono: sim" (inclusive `entrega § E6`: "aceitar a nova regra?") vai ao usuário como pergunta interativa (AskUserQuestion, até 4 por vez), com o contexto para decidir sem abrir o código e a opção recomendada pelo guia. Resposta que mantém o código como está (exceção aceita) tira o achado do gate e fica registrada no veredito; resposta que manda corrigir mantém o achado.

Achado **INCONCLUSIVO** vai na mesma rodada de perguntas, com o fato e como conferir (o `Fato a conferir` do verificador): "o fato se confirma" mantém o achado; "não se confirma" tira.

## 7. Veredito
Grave `$D/veredito.md` — **a primeira linha é lida pelo hook**:
```
VEREDITO: APROVADO | REPROVADO
Branch: <branch> · HEAD: <sha completo> · base: <base> @ <merge-base curto> · <data>
Validação da stack: ok | falhou (<comando>)
Scanners: gitleaks <n|não rodou> · trufflehog <…> · semgrep <…> · dependências <…|não se aplica>
Na branch: <n> confirmados (P0 <a> · P1 <b> · P2 <c> · P3 <d>) · refutados <r> · inconclusivos <i>
Exceções decididas pelo dono: <lista ou "nenhuma">

<os achados confirmados, no formato do auditor, com a prioridade final>

## Pré-existente (não reprova)
<lista do auditor>
```
APROVADO só com: validação ok **e** zero achado confirmado na branch fora das exceções decididas pelo dono.

Mostre ao usuário uma tabela (achado · prioridade · arquivo:linha · correção em uma linha) e o veredito. Reprovado: corrigir na branch, commitar e rodar esta skill de novo (reauditoria do delta).

## 8. Depois de aprovado
- Ao abrir o PR, inclua no corpo a linha `auditoria-pre-subida: APROVADO <sha completo>` e o resumo do veredito: quem mesclar em outra máquina passa pelo hook por esse marcador.
- PR já aberto e commit novo aprovado: o marcador vai num comentário (`gh pr comment`) — é ação remota, peça confirmação ao usuário antes.
- Merge local na base e push: o hook aceita o commit de merge cujo segundo pai foi aprovado e cujo primeiro pai já está no remoto (ou passa pela mesma regra).
