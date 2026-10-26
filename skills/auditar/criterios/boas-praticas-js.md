# Critérios — Boas práticas JavaScript/TypeScript (Node, React, Vue, Next, front em geral)

**Consistência primeiro**: o padrão do projeto e o guia de arquitetura dele vencem estes itens; aponte quando o diff cria um segundo jeito. Se houver skill da stack instalada, invoque-a.

## J1 — Servidor e dados
Toda rota, API Route, Server Action e resolver confere sessão **e** dono do recurso (ver `seguranca § S1/S2`); validação do corpo com schema (zod, valibot, joi) no servidor; ORM (Prisma, Drizzle, TypeORM) sem N+1 (`include`/`with`), sem query em laço; transação em escrita de negócio; `await` em toda promessa que importa (sem promessa solta); `timeout`/`AbortController` em `fetch` externo.

## J2 — Erros
Sem `catch {}` vazio; erro de servidor não vaza stack para o cliente; `unhandledRejection` tratado; no front, estado de erro e de carregamento visível.

## J3 — Tipagem
TypeScript sem `any` novo, sem `as` para calar, sem `@ts-ignore`/`@ts-expect-error` sem motivo; `strict` respeitado; tipos de fronteira (API, formulário) validados em runtime, não só declarados.

## J4 — React/Vue
Hooks seguindo as regras (dependências completas em `useEffect`/`useMemo`, sem hook condicional); chave estável em lista (nunca índice em lista que reordena); estado derivado calculado, não duplicado em `useState`; efeito com limpeza (listener, timer, assinatura); sem `dangerouslySetInnerHTML`/`v-html` com dado externo; componente da biblioteca do projeto em vez de feito à mão.

## J5 — Segredos e bundle
Nada de segredo em código que vai ao navegador (`NEXT_PUBLIC_`, `VITE_` expõem); dependência nova justificada e do tamanho certo; import que não puxa a biblioteca inteira.

## J6 — Estilo e organização
ESLint/Biome e Prettier limpos; sem código morto, `console.log` esquecido ou comentário narrativo; regra de negócio fora do componente de tela quando o projeto separa; sem CSS inline onde o projeto usa classes/tokens.

## J7 — Testes
Vitest/Jest/Testing Library testando comportamento (o que o usuário vê), não detalhe interno; rede mockada (MSW); teste de permissão com usuário comum e os dois lados; correção de bug com teste que falhava antes; sem `sleep`/timeout fixo para esperar.

## J8 — Acessibilidade
Elemento interativo é `button`/`a` (não `div` com `onClick`); `label` em campo; `alt` em imagem; foco visível; contraste.
