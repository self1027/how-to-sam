# Guia de estudo — Node.js, arquitetura, IA e infraestrutura

Este guia reúne explicações, exemplos e exercícios sobre Node.js, arquitetura de software, desenvolvimento com IA e infraestrutura. Você vai estudar como cada parte funciona e quando faz sentido usá-la.

## Sobre o material

Este material consolida duas tardes de aulas privadas do curso Imersão Técnica, ministrado por [Samuel Santos](https://github.com/samsantosb).

Cada capítulo traz conceitos, exemplos de código e perguntas de revisão. Os trechos marcados como complemento didático aprofundam o assunto. Os cuidados técnicos aparecem junto às explicações e estão reunidos no capítulo 12.

As escolhas de arquitetura e infraestrutura dependem do projeto. Uma solução que funciona em uma empresa pode ter outro desempenho, custo ou disponibilidade em outra.

## Ordem de leitura

| Ordem | Arquivo | O que você deve compreender |
| --- | --- | --- |
| 01 | [Como o Node.js executa código](01-nodejs-memoria-e-execucao.md) | V8, libuv, stack, heap e coleta de lixo |
| 02 | [V8, desempenho e tratamento de erros](02-v8-performance-e-erros.md) | JIT, formatos de objetos, profiling e exceções |
| 03 | [Assincronismo e observabilidade](03-assincronismo-e-observabilidade.md) | `await`, trabalho em segundo plano, métricas e percentis |
| 04 | [Arquitetura modular e contratos](04-arquitetura-modular-e-contratos.md) | Camadas, limites de domínio, DI e DIP |
| 05 | [Desenvolvimento com IA](05-ia-contexto-guidelines-e-tarefas.md) | Contexto, guidelines, skills e tarefas pequenas |
| 06 | [Testes e entrega gradual](06-testes-feature-flags-e-entrega.md) | Integração, contratos externos, flags e fallback |
| 07 | [Infraestrutura de execução](07-infraestrutura-nodejs-na-aws.md) | EC2, PM2, Lambda, ECS/Fargate e EKS |
| 08 | [Filas e processamento confiável](08-filas-bullmq-sqs-e-outbox.md) | BullMQ, SQS, pub/sub, idempotência e outbox |
| 09 | [Bancos de dados e escala](09-bancos-de-dados-e-escalabilidade.md) | RDS, Aurora, MongoDB, DynamoDB e escrita em lote |
| 10 | [Cache, S3 e dados históricos](10-cache-s3-e-base-fria.md) | Cache-aside, TTL, streams e arquivamento |
| 11 | [Revisão, exercícios e entrevistas](11-revisao-exercicios-e-entrevistas.md) | Praticar decisões e conectar os capítulos |
| 12 | [Ajustes técnicos e glossário](12-ajustes-tecnicos-e-glossario.md) | Evitar generalizações e revisar o vocabulário |

## Diagramas de apoio

O [quadro de estudo no tldraw](https://www.tldraw.com/f/7Hgqxqm5PZ4YaknNBKr7s) reúne 24 diagramas em 13 páginas, com uma visão geral e os 12 capítulos. O acesso por link permite somente visualização. As [fontes Mermaid, versões SVG e cópia nativa do quadro](diagramas/README.md) estão disponíveis no projeto.

<p align="center">
  <strong>Diagrama — Mapa do percurso de estudo</strong>
</p>

<p align="center">
  <a href="diagramas/svg/00-mapa.svg">
    <img src="diagramas/svg/00-mapa.svg" alt="Mapa do percurso de estudo" />
  </a>
</p>

<p align="center">
  <a href="diagramas/svg/00-mapa.svg">Ampliar SVG</a> · <a href="diagramas/00-mapa.mmd">Fonte (Mermaid)</a>
</p>

## Como usar os exemplos

Os exemplos JavaScript completos usam módulos ES: salve o bloco em um arquivo `.mjs` e execute com `node exemplo.mjs`. Os exemplos foram preparados para Node.js 24. Trechos TypeScript usam `.ts`; a execução sem tipos não substitui a checagem com o compilador TypeScript.

Blocos descritos como **fragmento** dependem das funções, clientes ou tabelas indicados no texto. Exemplos com BullMQ, Zod e SDKs precisam das dependências mencionadas. SQL, configurações de infraestrutura e nomes de tabela são ilustrativos: não há necessidade de contratar serviços para estudar o material.

Para estudar, leia o conceito e tente prever a saída do código antes de executá-lo. Depois, explique o resultado com suas palavras e responda às perguntas sem consultar o capítulo. No capítulo 11, pratique como runtime, aplicação e infraestrutura trabalham juntos.

Os links locais e a sintaxe dos 21 blocos JavaScript/TypeScript foram conferidos na preparação do material. Nos trechos TypeScript, essa checagem removeu as anotações de tipos; ela não substitui a verificação com `tsc`.

Também foram executados 16 exemplos locais: ordem das chamadas, espera assíncrona, cache, expiração lógica e compactação por streams. Os exemplos com Redis, banco, Zod ou serviços externos não foram executados em integração.

## Referências técnicas

As referências oficiais nos capítulos foram consultadas em **16/10/2026** para conferir os pontos técnicos mais sujeitos a erros. Preços, quotas, versões e compatibilidades devem ser reconferidos antes de uma decisão real de infraestrutura.
