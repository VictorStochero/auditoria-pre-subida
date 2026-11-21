---
name: mapear
description: Use para criar ou atualizar o mapa de ameaças do projeto (perfis, isolamento de dados, entradas, dados sensíveis, integrações, controles) que o auditor usa como o "quem" e o "por onde" da auditoria de segurança. Também para "mapear ameaças", "threat model do projeto", "atualizar o mapa de ameaças".
---

# Mapa de ameaças

Produz `ameacas.md` no formato de `criterios/mapa-ameacas.md` (pasta `criterios/` da skill `auditar`, em `../auditar/criterios/` a partir deste arquivo). A auditoria lê o mapa da versão do merge-base; mapa novo ou alterado numa branch passa pelo `entrega § E6`.

## 1. Onde fica
- Ache o guia de arquitetura como a `auditar` § 3: `wiki/`, `docs/`, `doc/` + `arquitetura`/`architecture`, ou o que o `CLAUDE.md`/`AGENTS.md` apontar. Caminho do mapa: `<pasta do guia>/ameacas.md`; sem guia, `docs/ameacas.md`.
- Mapa já existente: leia para atualizar (mantém o que segue verdadeiro, corrige o resto).

## 2. Mapear
Despache o subagente `auditoria-pre-subida:auditor` com: "Mapeie as ameaças do projeto seguindo `<pasta criterios>/mapa-ameacas.md`." — e, se existir, o caminho do mapa atual para atualizar. Se o ambiente impuser outro despachante para revisão, use-o com o mesmo agente e o mesmo pedido.

## 3. Gravar e confirmar
- Grave a resposta no caminho do mapa, na árvore de trabalho. Confira que não há valor de segredo nem dado de produção.
- Mostre ao usuário o resumo (perfis, entradas sem autorização, pontos frágeis) e **pergunte antes de commitar** (AskUserQuestion). Não commite sozinho.
- Lembre ao usuário: versionado numa branch, o mapa novo passa pelo `entrega § E6` e é lido como regra só depois de entrar na base.
