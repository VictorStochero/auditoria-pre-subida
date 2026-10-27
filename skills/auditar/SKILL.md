---
name: auditar
description: Use antes de abrir PR, mesclar PR ou dar push direto numa branch base (main, homologacao, develop…) — audita o diff da branch contra o guia de arquitetura do projeto, segurança e boas práticas da stack, com contraprova adversarial, e grava o veredito que o hook exige para liberar a subida. Também para "auditar a branch", "revisar antes de subir", "pre-push review".
---

# Auditoria antes de subir

Quatro dimensões, com critérios numerados em `criterios/` (ao lado deste arquivo), que o auditor lê inteiros e cita em cada achado:

| Dimensão | Arquivo | O que cobre |
|---|---|---|
| Arquitetura | `arquitetura.md` | o guia do projeto manda (e o checklist dele, item a item); sem guia, os padrões recorrentes A1–A18 |
| Segurança | `seguranca.md` | S1–S12: autorização no servidor, IDOR, listas/exports, injeção, XSS, atribuição em massa, upload, segredos, sessão/CSRF, SSRF, dependências, integridade |
| Boas práticas | `boas-praticas-<stack>.md` + `laravel-best-practices/` + `testing-best-practices/` | Laravel (L1–L12 + a íntegra do `laravel-best-practices` e do `testing-best-practices` do Boost v2.10.3, variante Pest ou PHPUnit), Python (Y1–Y8), JS/TS (J1–J8), somadas à skill da stack do projeto, se houver |
| Ponytail | `ponytail.md` + `ponytail/` | P1–P6 + a íntegra do `ponytail` e do `ponytail-review`: correto, seguro, aguenta carga, testado, rápido, enxuto |

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

## 3. Pacote
Grave em `$D`:
- `diff.patch`: `git diff $mb..HEAD`.
- `pacote.md`: **caminho absoluto da pasta `criterios/` desta skill** (o diretório base da skill + `/criterios`: `arquitetura.md`, `seguranca.md`, `boas-praticas-laravel.md`, `boas-praticas-python.md`, `boas-praticas-js.md`, `ponytail.md` e as íntegras `laravel-best-practices/`, `testing-best-practices/` e `ponytail/`), o framework de teste do projeto (Pest ou PHPUnit), branch, base, merge-base e HEAD (curto e completo), `git log --oneline $mb..HEAD`, `git diff --stat $mb..HEAD`, stack detectada (`composer.json`, `pyproject.toml`/`requirements*.txt`, `package.json`), e os caminhos que existirem: guia de arquitetura (`wiki/`, `docs/`, `doc/` + `arquitetura`/`architecture`; ou o que o `CLAUDE.md` apontar), checklist do guia (Grep por `Checklist` no guia), `CLAUDE.md`, `AGENTS.md`, `.claude/skills`, `.ai/skills`. Caminho absoluto do `diff.patch`.
- Reauditoria (já existe `auditoria/<sha anterior>/` desta branch, `REPROVADO`): acrescente ao pacote os achados anteriores e o `git diff <sha anterior>..HEAD`. O auditor confere as correções e audita só o delta.

Diff grande (mais de ~40 arquivos ou ~3.000 linhas): divida por domínio/pasta em até 4 fatias, um `pacote-<fatia>.md` cada, e um auditor por fatia em paralelo.

## 4. Auditor
Despache o subagente `auditoria-pre-subida:auditor` (Opus, só leitura) com o pedido: "Audite o pacote em `<D>/pacote.md`." Grave a resposta em `$D/achados.md` (fatias: concatene).
Se o ambiente impuser outro despachante para revisão (ex.: worker do Orca), use-o com o mesmo agente (`claude --agent auditoria-pre-subida:auditor`) e o mesmo pedido.

## 5. Contraprova
Com ao menos um achado "na branch", despache `auditoria-pre-subida:verificador` com "Contraprove `<D>/achados.md` com o pacote `<D>/pacote.md`." Grave em `$D/verificacao.md`. Achado REFUTADO sai; prioridade revista vale a do verificador. Divergência que você não consegue decidir lendo o código: leve ao usuário.

## 6. Decisões do dono
Achado com "Decisão do dono: sim" vai ao usuário como pergunta interativa (AskUserQuestion, até 4 por vez), com o contexto para decidir sem abrir o código e a opção recomendada pelo guia. Resposta que mantém o código como está (exceção aceita) tira o achado do gate e fica registrada no veredito; resposta que manda corrigir mantém o achado.

## 7. Veredito
Grave `$D/veredito.md` — **a primeira linha é lida pelo hook**:
```
VEREDITO: APROVADO | REPROVADO
Branch: <branch> · HEAD: <sha completo> · base: <base> @ <merge-base curto> · <data>
Validação da stack: ok | falhou (<comando>)
Na branch: <n> confirmados (P0 <a> · P1 <b> · P2 <c> · P3 <d>) · refutados <r>
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
