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

Instalar não bloqueia nada: o hook só age em repositório que tenha o arquivo `.auditoria-pre-subida` na raiz ou numa branch base do remoto (`origin/<base>`). Os outros projetos da máquina seguem como estão.

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
/auditoria-pre-subida:mapear             # cria ou atualiza o mapa de ameaças do projeto
```

O fluxo:
1. **Validação da stack** nos arquivos tocados (formatador, linter, análise estática, testes). Se falhar, reprova sem gastar o auditor. Em seguida, os **scanners** (ver [Ferramentas opcionais](#ferramentas-opcionais)): gitleaks e TruffleHog commit a commit em `merge-base..HEAD` (pegam o segredo que entrou e saiu dentro da branch), audit de dependências se o diff tocou lockfile e Semgrep só no achado novo. Ferramenta ausente não reprova: o veredito registra "não rodou". Achado de scanner não reprova sozinho: o auditor o transforma em achado ou o descarta com motivo.
2. **Regras da base e mapa de ameaças**: o pacote leva as regras do projeto (guia de arquitetura, checklist, mapa de ameaças, `CLAUDE.md`/`AGENTS.md`, skills do projeto) **na versão do merge-base**; a branch não escreve as regras pelas quais é auditada. Mudar essas regras vira achado (`entrega § E6`), decisão do dono. O **mapa de ameaças** (`<pasta do guia>/ameacas.md`, gerado por `/auditoria-pre-subida:mapear`) lista perfis, isolamento de dados, entradas, dados sensíveis, integrações e controles; o auditor usa os perfis como o "quem" do caminho de exploração.
3. **Auditor** (Opus, só leitura; com mudança em rota, autorização, upload, SQL cru e afins, um **auditor de segurança** extra roda em paralelo, percorrendo S1–S19 em cada entrada alterada): confere o diff em cinco dimensões, cada uma com critérios numerados que vêm no plugin (`skills/auditar/criterios/`) e não dependem de outra instalação:
   - **Arquitetura** (`arquitetura.md`): o guia do projeto manda (`wiki/`, `docs/` ou `doc/` + `arquitetura`/`architecture`, com o checklist dele item a item); sem guia, valem 18 padrões recorrentes (teste de autorização com administrador, regra duplicada, migration com dado, regra em Observer, tela que grava direto, id público sem trava…).
   - **Segurança** (`seguranca.md`, S1–S19, seguindo o OWASP Top 10:2025 e o OWASP Top 10 for LLM Applications 2025; cada item traz a categoria no título): autorização no servidor em toda entrada, IDOR, listas e exports pelo mesmo predicado, injeção, XSS, atribuição em massa, upload, segredos, sessão/CSRF, SSRF, dependências, integridade de dado, lógica de negócio e estado, enumeração, uso posterior/lote/restauração, LLM e MCP, criptografia, log de segurança, falha aberta. Cada achado traz o caminho de exploração seta a seta (`arquivo:linha`).
   - **Boas práticas da stack** (`boas-praticas-laravel.md`, `-python.md`, `-js.md`): consultas, transação e lock, validação, migrations, filas, tipagem, testes, front. Em Laravel, o auditor lê também **a íntegra do `laravel-best-practices` e do `testing-best-practices`** do Laravel Boost v2.10.3 (em `criterios/`, a de testes na variante Pest ou PHPUnit do projeto), e as skills da stack que o projeto tiver (ex.: com Filament, `filament-security-audit` e as referências do `filament-planning`, quando instaladas no projeto).
   - **Ponytail** (`ponytail.md`, P1–P6, e **a íntegra do `ponytail` e do `ponytail-review`** em `criterios/ponytail/`): correto, seguro, aguenta carga, testado, rápido e enxuto — código que não precisava existir, reuso do que já há no repositório, abstração sem uso, duplicação.
   - **Entrega** (`entrega.md`, E1–E6): escopo (cada trecho do diff ligado ao pedido), comportamento preservado em refatoração, sintaxe e estática que a validação não cobriu, evidência de navegador (perfil real, antes × depois, ação exercitada), integração externa testada de verdade (`Http::fake` não basta) e mudança nas regras da auditoria (guia, checklist, `CLAUDE.md`, skills, allowlist de scanner: a branch é auditada pelas regras da base, e mudá-las vira decisão do dono). O auditor é só leitura: confere a evidência que a sessão principal põe no pacote.

   Cada achado traz arquivo:linha, evidência, o critério citado, prioridade P0–P3, correção, teste e se depende de decisão do dono.
4. **Verificador** (Opus, só leitura): tenta refutar cada achado, refazendo o caminho de exploração seta a seta. Só fica o que resistir; o que depende de fato fora do código (configuração de produção, serviço externo) volta como **inconclusivo**, com o fato e como conferir.
5. **Decisões do dono** e inconclusivos viram perguntas interativas.
6. **Veredito** em `.git/auditoria/<sha>/veredito.md`: qualquer achado confirmado no que a branch toca reprova. Dívida pré-existente é listada e não reprova.

Reprovou: corrija, commite e rode de novo. A reauditoria confere as correções e olha só o que mudou.

## O que o hook bloqueia

| Comando | Exige |
|---|---|
| `gh pr create` | veredito APROVADO do `HEAD` (ou do `--head`) |
| `gh pr merge` | veredito local do head do PR, ou a linha `auditoria-pre-subida: APROVADO <sha>` no corpo ou num comentário do PR (merge feito em outra máquina) |
| `git push` para branch base | veredito do commit enviado, ou commit que já está no remoto; merge local vale pelo segundo pai aprovado se o primeiro já estiver no remoto (ou passar pela mesma regra) |

Só em repositório ativado (acima). Push da sua branch de trabalho é livre. Bases padrão: `main master homologacao desenvolvimento develop production producao staging` e a `origin/HEAD` do repositório. Para trocar, defina `AUDITORIA_BASES` (separadas por espaço) no `env` do `settings.json`.

Para desligar num projeto, tire o `.auditoria-pre-subida` da branch base, por um commit auditado. Apagá-lo só na branch de trabalho não desliga: o arquivo presente na base do remoto (`origin/<base>`) também ativa o bloqueio. Na máquina inteira, `/plugin disable auditoria-pre-subida@stochero`.

## Ferramentas opcionais

Os scanners da etapa 1 usam o que estiver instalado; ausente → o veredito registra "não rodou: <ferramenta> não instalada" e a auditoria segue. Ao baixar binário, confira checksum ou assinatura (scanner também sofre ataque de cadeia de suprimentos).

| Ferramenta | Para quê | Instalar |
|---|---|---|
| [gitleaks](https://github.com/gitleaks/gitleaks) | segredos commit a commit | `winget install Gitleaks.Gitleaks` · `brew install gitleaks` · binário do release |
| [TruffleHog](https://github.com/trufflesecurity/trufflehog) | segredos commit a commit, com verificação | `brew install trufflehog` · binário do release do GitHub, conferindo o `checksums.txt` |
| [Semgrep](https://semgrep.dev) | pistas de código inseguro (nunca veredito) | `pip install semgrep` · `brew install semgrep` |
| `pip-audit` | dependências Python | `pip install pip-audit` |

`composer audit`, `npm audit`, `pnpm audit` e `yarn npm audit` já vêm com o gerenciador de pacotes.

- **TruffleHog verifica o segredo**: a verificação, ligada por padrão, consulta a API do provedor da chave. O JSON dele traz o segredo em claro; fica só em `.git/auditoria/<sha>/`, e achados e veredito nunca o copiam.
- **Semgrep no Windows**: a pasta `Scripts` do Python precisa estar no `PATH`; o `semgrep.exe` chama o `pysemgrep`. As regras vêm do registro (`p/security-audit`, `p/php`…), então precisa de rede; as métricas ficam desligadas (`--metrics=off`).

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
