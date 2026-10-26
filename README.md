# auditoria-pre-subida

Plugin do Claude Code (pt-BR) que **audita a branch antes de subir**: o diff é conferido contra o guia de arquitetura do projeto, segurança e boas práticas da stack, e um verificador adversarial tenta derrubar cada achado. Um hook bloqueia `gh pr create`, `gh pr merge` e `git push` direto numa branch base enquanto o commit não tiver veredito aprovado.

Funciona em qualquer projeto (Laravel, Python, JS/TS), só com o Claude Code. Não precisa de Orca nem de outro plugin.

## Instalar

```
/plugin marketplace add VictorStochero/claude-plugins
/plugin install auditoria-pre-subida@stochero
```

Requisitos: `git` ≥ 2.31, `bash` (no Windows, o do Git for Windows) e `gh` autenticado para PR e merge.

## Ativar num projeto

Instalar não bloqueia nada: o hook só age em repositório que tenha o arquivo `.auditoria-pre-subida` na raiz. Os outros projetos da máquina seguem como estão.

```
touch .auditoria-pre-subida
git add .auditoria-pre-subida && git commit -m "chore: ativa a auditoria antes de subir"
```

Versionado, o arquivo ativa a auditoria para todo o time que tiver o plugin. A skill `/auditoria-pre-subida:auditar` funciona em qualquer repositório, com ou sem o arquivo; sem ele, ninguém é obrigado a rodá-la.

## Usar

Com a branch commitada:

```
/auditoria-pre-subida:auditar            # base detectada (PR aberto, CLAUDE.md ou origin/HEAD)
/auditoria-pre-subida:auditar main       # base explícita
```

O fluxo:
1. **Validação da stack** nos arquivos tocados (formatador, linter, análise estática, testes). Se falhar, reprova sem gastar o auditor.
2. **Auditor** (Opus, só leitura): confere o diff em quatro dimensões, cada uma com critérios numerados que vêm no plugin (`skills/auditar/criterios/`) e não dependem de outra instalação:
   - **Arquitetura** (`arquitetura.md`): o guia do projeto manda (`wiki/`, `docs/` ou `doc/` + `arquitetura`/`architecture`, com o checklist dele item a item); sem guia, valem 18 padrões recorrentes (teste de autorização com administrador, regra duplicada, migration com dado, regra em Observer, tela que grava direto, id público sem trava…).
   - **Segurança** (`seguranca.md`, S1–S12): autorização no servidor em toda entrada, IDOR, listas e exports pelo mesmo predicado, injeção, XSS, atribuição em massa, upload, segredos, sessão/CSRF, SSRF, dependências, integridade de dado. Cada achado traz o caminho concreto de exploração.
   - **Boas práticas da stack** (`boas-praticas-laravel.md`, `-python.md`, `-js.md`): consultas, transação e lock, validação, migrations, filas, tipagem, testes, front. Em Laravel, o auditor lê também **a íntegra do `laravel-best-practices` e do `testing-best-practices`** do Laravel Boost v2.10.3 (em `criterios/`, a de testes na variante Pest ou PHPUnit do projeto), e as skills da stack que o projeto tiver (ex.: com Filament, `filament-security-audit` e as referências do `filament-planning`, quando instaladas no projeto).
   - **Ponytail** (`ponytail.md`, P1–P6, e **a íntegra do `ponytail` e do `ponytail-review`** em `criterios/ponytail/`): correto, seguro, aguenta carga, testado, rápido e enxuto — código que não precisava existir, reuso do que já há no repositório, abstração sem uso, duplicação.

   Cada achado traz arquivo:linha, evidência, o critério citado, prioridade P0–P3, correção, teste e se depende de decisão do dono.
3. **Verificador** (Opus, só leitura): tenta refutar cada achado. Só fica o que resistir.
4. **Decisões do dono** viram perguntas interativas.
5. **Veredito** em `.git/auditoria/<sha>/veredito.md`: qualquer achado confirmado no que a branch toca reprova. Dívida pré-existente é listada e não reprova.

Reprovou: corrija, commite e rode de novo. A reauditoria confere as correções e olha só o que mudou.

## O que o hook bloqueia

| Comando | Exige |
|---|---|
| `gh pr create` | veredito APROVADO do `HEAD` (ou do `--head`) |
| `gh pr merge` | veredito local do head do PR, ou a linha `auditoria-pre-subida: APROVADO <sha>` no corpo ou num comentário do PR (merge feito em outra máquina) |
| `git push` para branch base | veredito do commit enviado; merge local vale pelo segundo pai aprovado |

Só em repositório ativado (acima). Push da sua branch de trabalho é livre. Bases padrão: `main master homologacao desenvolvimento develop production producao staging` e a `origin/HEAD` do repositório. Para trocar, defina `AUDITORIA_BASES` (separadas por espaço) no `env` do `settings.json`.

Para desligar num projeto, apague o `.auditoria-pre-subida`; na máquina inteira, `/plugin disable auditoria-pre-subida@stochero`.

## Prioridades

- **P0**: segurança explorável ou perda de dado.
- **P1**: bug visível, integridade com janela real, regressão.
- **P2**: arquitetura que aumenta o risco.
- **P3**: organização, nomes, comentários, código morto.

## Desenvolvimento

```
bash tests/hook.sh
```

## Licença

MIT © Victor Stochero. Incluídos sem alteração, cada um com sua licença ao lado:
- `skills/auditar/criterios/laravel-best-practices/` e `testing-best-practices/` — skills do [Laravel Boost](https://github.com/laravel/boost) v2.10.3, MIT © Taylor Otwell, renderizadas dos templates como o `boost:install` faz;
- `skills/auditar/criterios/ponytail/` — `ponytail` e `ponytail-review` de [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) v5.3.2, MIT © DietrichGebert.

## Atualizar os critérios de terceiros

1. Ponytail: copie `skills/ponytail/SKILL.md` e `skills/ponytail-review/SKILL.md` da última release para `criterios/ponytail/ponytail.md` e `ponytail-review.md`.
2. Boost: baixe `.ai/laravel/skill/laravel-best-practices/` e `.ai/laravel/skill/testing-best-practices/` da última release e renderize os templates `.blade.php` com o `manutencao/renderiza-boost.php` (usa o Blade de qualquer projeto Laravel; mesmo pipeline do Boost):
   ```
   php manutencao/renderiza-boost.php <projeto>/vendor/autoload.php <origem>/laravel-best-practices skills/auditar/criterios/laravel-best-practices pest
   php manutencao/renderiza-boost.php <projeto>/vendor/autoload.php <origem>/testing-best-practices skills/auditar/criterios/testing-best-practices/pest pest
   php manutencao/renderiza-boost.php <projeto>/vendor/autoload.php <origem>/testing-best-practices skills/auditar/criterios/testing-best-practices/phpunit phpunit
   ```
3. Atualize as versões citadas aqui e nos `criterios/*.md`, e suba a versão do `plugin.json`.
