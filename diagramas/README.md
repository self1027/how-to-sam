# Diagramas de estudo

Os 24 diagramas complementam os 12 capítulos do guia e estão organizados em 13 páginas no [quadro tldraw](https://www.tldraw.com/f/7Hgqxqm5PZ4YaknNBKr7s).

Os diagramas também aparecem diretamente no [README do guia](../README.md) e nas seções correspondentes dos 12 capítulos. Títulos, imagens, legendas e links ficam centralizados. Os SVGs têm fundo claro, borda discreta e margem interna, com texto alternativo, opção de ampliar e link para a fonte Mermaid.

Use o menu de páginas do quadro para escolher um capítulo. As formas e conexões são editáveis. Cada página reúne objetivo, fluxos, pontos para lembrar e uma pergunta de revisão.

Arquivos disponíveis:

- [Quadro completo em formato nativo tldraw](guia-de-estudo.tldr): cópia exportada pelo próprio tldraw, com as 13 páginas e os 24 diagramas.
- [Índice das versões SVG](svg/README.md): renderizações individuais das fontes Mermaid.
- [Conteúdo estruturado](guia-de-estudo.json): títulos, fontes Mermaid, notas, perguntas e referências.
- [Registro da conferência do quadro](validacao-tldraw.json) e [validação dos 24 SVGs](svg/validacao.json), incluindo sintaxe Mermaid, XML e abertura como imagem no navegador.
- [Configuração de exportação Mermaid](mermaid.config.json), [preparação do fundo dos SVGs](preparar-svg.ps1) e [verificador de SVGs](validar-svg.ps1).

Os arquivos Mermaid da tabela abaixo preservam as fontes editáveis dos diagramas. A organização visual, as cores e as notas adicionais do quadro ficam preservadas no arquivo nativo `.tldr`.

Para novas exportações, use `mermaid.config.json`: `htmlLabels: false` deve estar na raiz da configuração para gerar rótulos SVG sem HTML embutido, conforme a [configuração oficial do Mermaid](https://mermaid.js.org/config/schema-docs/config-properties-htmllabels.html). Depois execute os comandos abaixo na raiz do repositório. A preparação adiciona o fundo e pode ser repetida sem acumular margens. O verificador rejeita XML malformado, HTML embutido e ausência do fundo.

```powershell
powershell -NoProfile -File diagramas/preparar-svg.ps1
powershell -NoProfile -File diagramas/validar-svg.ps1
```

| Página | Conteúdo | Diagramas |
| --- | --- | --- |
| 00 · Comece aqui | Como os assuntos se conectam | [Mapa do percurso de estudo](00-mapa.mmd) |
| 01 · Node.js e memória | Node.js: execução, pilha e memória | [1 · Quem executa cada tipo de trabalho?](01-runtime.mmd) · [2 · Por que o GC não libera tudo?](01-memoria.mmd) |
| 02 · V8 e desempenho | V8, desempenho e tratamento de erros | [1 · Modelo conceitual de execução e otimização](02-v8.mmd) · [2 · Investigar antes de otimizar](02-decisao.mmd) |
| 03 · Async e observabilidade | Assincronismo e observabilidade | [1 · O que acontece durante um await?](03-await.mmd) · [2 · Da métrica à decisão de engenharia](03-metricas.mmd) |
| 04 · Módulos e contratos | Arquitetura modular e contratos | [1 · Caminho de uma requisição](04-camadas.mmd) · [2 · DI e DIP vistos separadamente](04-di.mmd) |
| 05 · Desenvolvimento com IA | IA: contexto, tarefas e aprendizado | [Do problema de produto ao aprendizado](05-ciclo.mmd) |
| 06 · Testes e entrega | Verificação e entrega gradual | [1 · Validar uma integração externa](06-contrato.mmd) · [2 · Deploy não é exposição ao público](06-release.mmd) |
| 07 · Infraestrutura | Escolher onde executar Node.js | [Da necessidade ao modelo de execução](07-infra.mmd) |
| 08 · Filas e outbox | Filas e processamento confiável | [1 · Outbox: resolver a escrita dupla](08-outbox.mmd) · [2 · Repetir o trabalho sem duplicar o efeito](08-worker.mmd) · [3 · Fila de trabalho e distribuição para assinantes](08-fanout.mmd) |
| 09 · Bancos e escala | Dados, consistência e capacidade | [1 · Escolher pelo padrão de acesso](09-banco.mmd) · [2 · Escrever em lote sem esperar indefinidamente](09-lote.mmd) · [3 · Expiração lógica e limpeza física](09-ttl.mmd) |
| 10 · Cache e histórico | Cache, S3 e dados históricos | [1 · Cache-aside e proteção da origem](10-cache.mmd) · [2 · Arquivar com recuperação verificável](10-arquivo.mmd) |
| 11 · Casos integrados | Conectar os capítulos em decisões | [1 · Webhook de pagamento: do aceite ao resultado](11-webhook.mmd) · [2 · Dashboard lento: investigação e alternativas](11-dashboard.mmd) |
| 12 · Revisão e glossário | Revisar conceitos sem generalizações | [Mapa das distinções que sustentam o guia](12-conceitos.mmd) |

Cada página do quadro apresenta o objetivo, os fluxos, ressalvas e uma pergunta de revisão. Os modelos são didáticos e não representam recomendações universais de arquitetura.

O plugin tldraw criou o quadro. Como sua conexão de edição não reconheceu o editor aberto, a montagem foi concluída pela interface web do tldraw, usando a importação nativa de Mermaid em formas editáveis. Uma nova abertura do quadro confirmou as 13 páginas, os 24 diagramas e as conexões salvas.

As fontes principais são os capítulos locais. Foram conferidas também as referências oficiais de [event loop e worker pool do Node.js](https://nodejs.org/en/learn/asynchronous-work/dont-block-the-event-loop), [transactional outbox](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html) e [TTL do DynamoDB](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html).
