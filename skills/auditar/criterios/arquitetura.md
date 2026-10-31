# Critérios — Arquitetura

## A0 — O guia do projeto manda
Se o projeto tem guia de arquitetura (`wiki/`, `docs/` ou `doc/` + `arquitetura`/`architecture`, ou o que o `CLAUDE.md`/`AGENTS.md` apontar), ele é a régua: vence o código vizinho e estes itens. Leia o índice e as páginas dos assuntos que o diff toca; checklist do guia (de PR, de commit, de revisão) vira tabela item a item. Achado cita `<arquivo do guia> § <seção>` e diz o que a regra afirma. Se a regra foi escrita depois do commit auditado, diga.

Sem guia, ou onde o guia é omisso, valem os itens abaixo, e o achado vira **"Decisão do dono: sim"** quando a regra não é óbvia para o projeto.

## Padrões recorrentes
Em ordem de frequência. Cada um é uma verificação fixa.

| Item | O que procurar | Por que importa |
|---|---|---|
| A1 — Teste de autorização com administrador | teste de permissão que usa super admin/admin/`is_staff`, ou só testa o lado "pode" | administrador passa por tudo; o teste não prova a regra |
| A2 — Regra reinventada ou duplicada | condição de negócio que já existe em outra classe, copiada ou reescrita (Grep pelo nome do status, do campo, da permissão) | duas cópias divergem na primeira mudança |
| A3 — Migration com dado, classe da aplicação ou sem guarda | migration que faz `UPDATE`/`INSERT`, importa Model/Service, ou quebra se rodar de novo | dado e schema têm ciclos diferentes; o Model muda e a migration antiga quebra |
| A4 — Classe nova em pasta genérica | `Support/`, `Helpers/`, `Utils/`, `common/` recebendo regra de negócio | regra sem dono, ninguém acha para reaproveitar |
| A5 — Sem trava sobre o objeto da tela | transição de estado decidida sobre o objeto carregado na tela, sem reler e travar o registro | dois usuários ao mesmo tempo gravam por cima |
| A6 — JS/CSS inline no template | `style=`, `<script>`, lógica em atributo de template | foge do padrão visual e não é testado |
| A7 — Observer/signal/hook de model com regra de fluxo | observer que decide fluxo, cria registro relacionado ou dispara aviso de negócio | efeito escondido, roda onde ninguém espera (seed, import, teste) |
| A8 — Burla do analisador estático | baseline novo, ignore novo, `mixed`/`any`/cast só para passar | esconde o erro que o analisador achou |
| A9 — Comentário narrativo | data, número de issue, "antes era", "corrigido por" | história vai para o commit; o comentário apodrece |
| A10 — Autor da sessão dentro da regra | `Auth::user()`/`request.user`/sessão lida dentro da regra de negócio | job, command e import não têm sessão; quebra ou grava autor errado |
| A11 — Autorização fora da regra de permissão | `if ($user->cargo == ...)` espalhado em vez de Policy/permission central | cada tela decide diferente |
| A12 — Tela grava direto | página/componente/view fazendo `create`/`update` de negócio sem passar pela camada de regra | regra repetida e sem transação |
| A13 — Id público sem trava | ver `seguranca § S2` | IDOR |
| A14 — Nome de tabela à mão em SQL | `'tabela'` literal em query crua | renomear tabela quebra em silêncio |
| A15 — Comportamento visível mudou sem decisão | coluna, filtro, campo, botão, aba, ordenação ou granularidade de lista mudou sem pedido registrado (em refatoração, ver `entrega § E2`) | o usuário perde algo que usava |
| A16 — Query no template | consulta ao banco dentro de Blade/Jinja/JSX de servidor | N+1 escondido e regra na tela |
| A17 — Herança de página/tela | `BaseX` com subclasses variando a mesma tela | mudança numa variante quebra a outra |
| A18 — Service com regra de negócio que tem dono | "Service" genérico acumulando regras de domínios diferentes | sem fronteira, tudo depende de tudo |

## Princípios gerais (quando o guia é omisso)
- Uma pergunta por camada: tela coleta e autoriza; a regra de negócio vive numa unidade de propósito único (Action/use case/service do domínio); persistência no model/repositório; efeito externo depois do commit.
- Nomes do domínio do negócio, no idioma do projeto; pasta pelo domínio, não pelo tipo técnico, se o projeto já faz assim.
- Refatoração preserva comportamento: diferença de comportamento achada é regressão, não melhoria, salvo pedido na issue ou do dono; em refatoração sem pedido de mudança vale `entrega § E2` (restaurar, não perguntar).
- Código morto sai junto com a mudança que o tornou morto; teste dele também.
