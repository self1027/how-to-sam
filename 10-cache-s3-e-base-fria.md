# 10 — Cache, S3 e dados históricos

**Objetivo:** aliviar consultas repetidas e separar dados de acordo com frequência de acesso e necessidade de atualização.

## 1. Por que cache ajuda?

Se muitas pessoas pedem o mesmo relatório, recalculá-lo em cada chamada pode gastar recursos sem melhorar a resposta. Um cache permite reutilizar um resultado por um período aceitável.

Ao reutilizar um resultado, você pode deixar de mostrar a alteração mais recente da fonte. Antes de escolher o prazo de expiração (TTL), defina quanto atraso o produto aceita e o que fazer se o cache ficar indisponível.

Um exemplo é um dashboard pesado cujos resultados são guardados em Redis. É uma boa hipótese para investigar, mas não substitui analisar a consulta: o primeiro acesso ainda precisa ser atendido sem derrubar o banco.

## 2. Cache-aside

No padrão cache-aside, a aplicação consulta o cache; se não há entrada, busca na fonte e armazena o resultado.

```text
Ler cache
    ├─ encontrou → devolver
    └─ não encontrou → consultar fonte → guardar → devolver
```

Neste exemplo completo, o cache fica na memória de um único processo, e a função recebe o relógio que vai usar. O código serve para estudar o comportamento; ele não coordena várias instâncias:

```js
function criarConsultaComCache(buscar, ttlMs, agora = Date.now) {
  const cache = new Map();

  return async function consultar(chave) {
    const item = cache.get(chave);
    if (item && item.expiraEm > agora()) return item.valor;

    cache.delete(chave);
    const valor = await buscar(chave);
    cache.set(chave, { valor, expiraEm: agora() + ttlMs });
    return valor;
  };
}

let tempo = 0;
let consultasNaFonte = 0;

const consultar = criarConsultaComCache(async (empresaId) => {
  consultasNaFonte++;
  return { empresaId, aprovadas: 10 };
}, 1_000, () => tempo);

await consultar('empresa-a');
await consultar('empresa-a');
console.log(consultasNaFonte); // 1

tempo = 1_001;
await consultar('empresa-a');
console.log(consultasNaFonte); // 2
```

Esse cache não limita a quantidade de chaves nem remove periodicamente as entradas que deixaram de ser acessadas. Também não coordena chamadas simultâneas. Para usá-lo em produção, defina limites, regras de remoção e coordenação entre chamadas. Lembre que cada instância tem seu próprio cache local.

### Chave de cache também é parte da correção

Uma chave de dashboard pode precisar incluir empresa, período, filtros e versão do formato. Se a resposta varia conforme a permissão do usuário, essa variação também precisa ser tratada. Uma chave incompleta pode devolver dados de outro contexto.

Quando a origem muda, você pode invalidar a entrada ou aceitar a defasagem até o TTL. A política precisa combinar com a regra de negócio. Expirar uma resposta em cache é diferente de remover automaticamente um registro durável por TTL no DynamoDB.

<p align="center">
  <strong>Diagrama — Cache-aside e proteção da origem</strong>
</p>

<p align="center">
  <a href="diagramas/svg/10-cache.svg">
    <img src="diagramas/svg/10-cache.svg" alt="Cache-aside e proteção da origem" />
  </a>
</p>

<p align="center">
  <a href="diagramas/svg/10-cache.svg">Ampliar SVG</a> · <a href="diagramas/10-cache.mmd">Fonte (Mermaid)</a>
</p>

## 3. Complemento didático: cache stampede

Se centenas de requisições encontram a mesma entrada expirada ao mesmo tempo, todas podem disparar a consulta pesada. O cache funciona bem enquanto está quente, mas a expiração gera um pico.

Você pode fazer as chamadas da mesma chave compartilharem uma única consulta, atualizar o resultado antes de expirar, variar o TTL ou devolver temporariamente o resultado anterior, se o produto permitir.

Escolher uma dessas estratégias depende de consistência, tolerância a atraso e quantidade de instâncias. Um lock apenas em memória coordena só o próprio processo. Qualquer mecanismo de lock precisa lidar com falha e prazo de liberação.

Observe taxa de acerto, duração das consultas na origem, erros do cache e volume de recomputação. O objetivo é reduzir carga sem transformar uma dependência auxiliar em uma nova fonte de indisponibilidade.

## 4. Dados muito quentes, quentes e frios

A temperatura é uma metáfora para frequência e custo de acesso:

| Categoria | Uso típico | Exemplo de armazenamento |
| --- | --- | --- |
| Muito quente | Dados reutilizados com muita frequência | Resultado em Redis |
| Quente | Dados operacionais recentes | Banco principal da aplicação |
| Frio | Histórico pouco consultado | Objetos arquivados em S3 |

Essas categorias descrevem o uso dos dados neste exemplo. S3 também pode servir conteúdo muito acessado e oferece classes de armazenamento com características diferentes. Compare os requisitos e custos do seu caso.

## 5. S3 é armazenamento de objetos

S3 armazena objetos em buckets, como vídeos, PDFs, imagens, arquivos de eventos e exportações. Não é um banco relacional e não fornece, por padrão, os mesmos acessos e índices de uma tabela SQL. Veja [What is Amazon S3?](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html).

Salvar milhões de registros em um JSON gigante e baixá-lo para procurar um único ID pode ser um desenho ruim. Organize o arquivo e sua chave a partir dos acessos: por empresa, data ou outro recorte pertinente.

Athena é um serviço de consulta que pode analisar dados em S3; não é simplesmente outro local para guardar os registros. Um histórico analítico pode usar formatos e partições próprios para esse acesso.

## 6. Arquivamento exige um protocolo

Mover dados históricos para uma base fria pode reduzir o volume no banco operacional. Antes de remover os dados da origem, confirme que consegue recuperá-los no destino.

Um fluxo de referência:

1. Definir uma faixa de dados elegível, com corte de tempo e política de retenção.
2. Exportar sem depender de carregar todo o conjunto em memória.
3. Registrar um manifesto com faixa, quantidade, localização e verificação de integridade.
4. Confirmar que o arquivo pode ser lido e que o fluxo de recuperação funciona.
5. Remover ou marcar dados de origem de forma retomável e idempotente.
6. Observar falhas e reconciliar exportações incompletas.

Esse complemento didático detalha os cuidados para manter o histórico recente no banco e o antigo no S3. As etapas permitem conferir o que foi movido e investigar falhas.

A aplicação também precisa saber em qual arquivo está o histórico. Use um catálogo ou uma regra de localização que sempre leve ao arquivo certo. Assim, não será necessário baixar arquivos ao acaso quando o dado não estiver no banco.

Arquivar por idade costuma ter significado de negócio mais claro que simplesmente apagar tudo que excede um número de linhas. Nenhuma quantidade fixa de registros define quando um banco ficará lento: índices, tamanho dos dados e consultas importam.

<p align="center">
  <strong>Diagrama — Arquivar com recuperação verificável</strong>
</p>

<p align="center">
  <a href="diagramas/svg/10-arquivo.svg">
    <img src="diagramas/svg/10-arquivo.svg" alt="Arquivar com recuperação verificável" />
  </a>
</p>

<p align="center">
  <a href="diagramas/svg/10-arquivo.svg">Ampliar SVG</a> · <a href="diagramas/10-arquivo.mmd">Fonte (Mermaid)</a>
</p>

## 7. Streams e backpressure

Streams permitem transferir e transformar dados sem manter todo o arquivo simultaneamente na memória da aplicação.

Exemplo local completo, **desde que exista o arquivo `entrada.ndjson`**. Ele cria ou substitui `saida.ndjson.gz` no diretório de execução:

```js
import { createReadStream, createWriteStream } from 'node:fs';
import { createGzip } from 'node:zlib';
import { pipeline } from 'node:stream/promises';

await pipeline(
  createReadStream('entrada.ndjson'),
  createGzip(),
  createWriteStream('saida.ndjson.gz'),
);

console.log('Arquivo compactado');
```

`pipeline` coordena os streams e propaga falhas. Backpressure faz quem envia os dados respeitar a velocidade de quem os recebe. Isso evita que os dados em espera cresçam sem controle, mas ainda há consumo de memória e custo de processamento.

Em uma exportação para S3, o mesmo princípio se aplica: ler de forma paginada ou por stream, transformar e enviar com buffers limitados. A API concreta depende do cliente do banco e do SDK utilizado.

## 8. Dashboards e cargas diferentes

Uma tabela pode atender tanto o aplicativo transacional quanto consultas analíticas complexas. Essa disputa nem sempre se resolve com mais índices.

Você pode usar réplicas, cache, paginação ou um histórico separado. Outra opção é manter totais pré-calculados ou dados organizados para relatórios, deixando claro o atraso de atualização. Para cada escolha, avalie onde ficará o custo e como manter e recuperar os dados.

Antes de escolher, identifique quais dados precisam ser atuais, quais filtros são frequentes e qual volume de consulta existe. “Dashboard em tempo real” precisa ser traduzido em uma tolerância concreta de atraso.

## Revisão ativa

1. Que campos precisam entrar na chave de um cache de relatório por empresa?
2. Por que só acrescentar TTL não impede um pico de consultas na origem?
3. O que deve ser verificado antes de remover dados já exportados?
4. Por que stream e paginação ajudam de modos diferentes?

### Respostas esperadas

1. Empresa, filtros, período e qualquer diferença de permissão que altere a resposta.
2. Várias chamadas podem encontrar a entrada expirada e refazer a mesma consulta ao mesmo tempo.
3. Confira a integridade dos dados, onde o arquivo está e se consegue ler e recuperar seu conteúdo.
4. Streams limitam os dados em espera durante a transferência. Paginação divide a consulta em porções menores.

Próximo: [Revisão e exercícios](11-revisao-exercicios-e-entrevistas.md).
