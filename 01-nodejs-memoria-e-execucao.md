# 01 — Como o Node.js executa código

**Objetivo:** entender onde o código executa, como chamadas se organizam e por que memória e CPU exigem cuidados diferentes.

## 1. Node.js é um ambiente de execução

JavaScript é a linguagem. Node.js fornece um ambiente para executá-la fora do navegador, com APIs de arquivos, rede, processos e outros recursos do sistema operacional.

Para entender a execução, veja o papel de cada parte:

| Componente | Responsabilidade |
| --- | --- |
| V8 | Executar JavaScript, interpretar bytecode, compilar trechos e gerenciar o heap de objetos JavaScript |
| libuv | Oferecer a base do event loop e abstrações de operações assíncronas entre sistemas operacionais |
| APIs e bindings do Node.js | Conectar o código JavaScript a funcionalidades nativas, como sistema de arquivos e criptografia |
| Sistema operacional | Executar threads e processos e oferecer mecanismos de I/O |

Essa divisão simplifica o estudo. O Node.js tem outras bibliotecas e partes internas, e uma chamada pode passar por vários componentes.

## 2. O que significa dizer que JavaScript é single-thread?

No uso comum, um mesmo event loop executa os callbacks JavaScript um de cada vez. Se uma função faz um cálculo longo na thread principal, os outros callbacks precisam esperar.

Isso não significa que o processo inteiro possua apenas uma thread. Há trabalho nativo em outras threads e é possível criar threads JavaScript explicitamente. I/O de rede também pode avançar pelo sistema operacional sem ocupar uma thread do pool para cada conexão. A documentação distingue o [event loop do worker pool](https://nodejs.org/en/learn/asynchronous-work/dont-block-the-event-loop).

O pool da libuv tem tamanho padrão de **quatro threads**, configurável na inicialização com `UV_THREADPOOL_SIZE`. Esse número descreve o pool, não a quantidade total de threads do Node.js. Aumentá-lo não faz um `for` JavaScript ser executado em paralelo. Veja a [documentação da libuv](https://docs.libuv.org/en/v1.x/threadpool.html).

<p align="center">
  <strong>Diagrama — Quem executa cada tipo de trabalho?</strong>
</p>

<p align="center">
  <a href="diagramas/svg/01-runtime.svg">
    <img src="diagramas/svg/01-runtime.svg" alt="Quem executa cada tipo de trabalho?" />
  </a>
</p>

<p align="center">
  <em>Modelo conceitual: não representa a ordem completa das fases do event loop e das microtasks.</em>
</p>

<p align="center">
  <a href="diagramas/svg/01-runtime.svg">Ampliar SVG</a> · <a href="diagramas/01-runtime.mmd">Fonte (Mermaid)</a>
</p>

## 3. Call stack: uma pilha de chamadas

A *call stack* registra as chamadas síncronas em andamento. Ela segue LIFO: *last in, first out*, ou último a entrar, primeiro a sair.

Exemplo completo:

```js
function c() {
  console.log('C: início');
  console.log('C: fim');
}

function b() {
  console.log('B: início');
  c();
  console.log('B: fim');
}

function a() {
  console.log('A: início');
  b();
  console.log('A: fim');
}

a();
```

Saída:

```text
A: início
B: início
C: início
C: fim
B: fim
A: fim
```

Enquanto `c()` executa, `a()` e `b()` ficam esperando. Quando `c()` termina, `b()` continua; depois, `a()` continua. Nesse encadeamento, a primeira função chamada é a última a terminar.

### Stack trace

Um objeto `Error` normalmente registra as chamadas que ajudam a localizar onde o erro foi criado e como o código chegou até ali. Esse registro não copia os dados da memória e pode não mostrar todas as operações assíncronas envolvidas.

**Complemento didático:** lançar uma exceção altera o fluxo de controle. O runtime procura um tratador aplicável; chamadas podem ser abandonadas durante essa propagação. Já a criação de `new Error()` e o lançamento com `throw` são operações distintas.

## 4. Recursão e estouro de pilha

Uma função recursiva chama a si mesma, direta ou indiretamente. Cada chamada síncrona acrescenta trabalho à pilha. Recursão sem término, ou profunda demais, pode causar `RangeError: Maximum call stack size exceeded`.

Se o problema é percorrer uma sequência grande, uma versão iterativa pode ser mais apropriada:

```js
function somaAte(n) {
  if (!Number.isSafeInteger(n) || n < 0 || n > 1_000_000) {
    throw new RangeError('n deve ser um inteiro entre 0 e 1.000.000');
  }

  let total = 0;
  for (let i = 1; i <= n; i++) total += i;
  return total;
}

console.log(somaAte(5)); // 15
```

Esse exemplo resolve o crescimento da pilha, mas o laço continua consumindo CPU. Evitar recursão não elimina a necessidade de limitar entrada e tempo de processamento.

**Ajuste técnico:** requisições HTTP concorrentes não somam automaticamente suas profundidades recursivas em uma única pilha permanente. Cada trecho JavaScript executa quando ganha a vez. Ainda assim, uma recursão longa bloqueia a thread enquanto roda, e muitas operações pendentes podem reter memória.

## 5. Heap: objetos e suas referências

O heap é uma região de memória gerenciada pelo motor, onde ficam muitas alocações feitas durante a execução, como objetos. Duas variáveis podem apontar para o mesmo objeto. Nesse caso, copiar a referência não copia o conteúdo.

```js
const original = { nome: 'Ana', preferencias: { tema: 'claro' } };
const alias = original;
const copiaRasa = { ...original };

alias.nome = 'Bia';
copiaRasa.preferencias.tema = 'escuro';

console.log(original.nome);             // Bia
console.log(original.preferencias.tema); // escuro
console.log(copiaRasa === original);    // false
console.log(copiaRasa.preferencias === original.preferencias); // true
```

O spread criou um novo objeto externo, mas os dois ainda apontam para o mesmo objeto `preferencias`. Por isso, mudar o tema pela cópia também altera o original. Referências compartilhadas também podem manter objetos na memória.

A explicação “primitivos na stack e objetos no heap” serve de introdução, mas não é uma regra física universal. Representação de números e strings, closures e otimizações variam. No trabalho cotidiano, entender identidade, referências e tempo de vida costuma ser mais útil do que pressupor a localização de cada valor.

## 6. Garbage collector: liberar o que perdeu utilidade

O coletor de lixo recupera a memória de objetos que o programa já não consegue alcançar por suas referências. Terminar uma função não libera necessariamente os objetos criados nela: outra parte do código pode continuar apontando para eles.

Uma causa comum de crescimento de memória é uma coleção global que nunca descarta entradas:

```js
const cache = new Map();

function guardar(id, dados) {
  cache.set(id, dados);
}

guardar('pedido-1', { itens: [1, 2, 3] });
console.log(cache.size); // 1

// Quando a entrada não for mais necessária:
cache.delete('pedido-1');
console.log(cache.size); // 0
```

Em um cache real, defina quantas entradas guardar, quando elas expiram e como serão removidas. O coletor não sabe se o negócio ainda precisa de uma entrada. Enquanto o programa consegue alcançar o `Map` e a entrada está nele, ela permanece acessível.

Referências circulares, sozinhas, não provam vazamento: coletores modernos conseguem recuperar ciclos inteiramente inalcançáveis. “Orinoco” está relacionado à evolução do coletor do V8; não significa que toda memória será devolvida imediatamente ao sistema operacional. O artigo [Trash talk: the Orinoco garbage collector](https://v8.dev/blog/trash-talk) explica alcançabilidade e coleta.

<p align="center">
  <strong>Diagrama — Por que o GC não libera tudo?</strong>
</p>

<p align="center">
  <a href="diagramas/svg/01-memoria.svg">
    <img src="diagramas/svg/01-memoria.svg" alt="Por que o GC não libera tudo?" />
  </a>
</p>

<p align="center">
  <a href="diagramas/svg/01-memoria.svg">Ampliar SVG</a> · <a href="diagramas/01-memoria.mmd">Fonte (Mermaid)</a>
</p>

## 7. O que observar na prática

CPU alta pode apontar para cálculos, serialização, compressão ou funções síncronas demoradas. Memória crescendo pode indicar retenção, caches sem limite, filas acumuladas ou alocações intensas. Pausas de coleta de lixo podem afetar a latência, mas é preciso medi-las para confirmar a causa.

Antes de alterar parâmetros do runtime, descubra qual recurso está sob pressão. Uma correção para CPU não necessariamente resolve retenção de memória.

## Revisão ativa

1. Por que a saída do exemplo de `a`, `b` e `c` confirma o comportamento LIFO?
2. Qual é a diferença entre copiar um objeto e copiar sua referência?
3. Por que um objeto criado dentro de uma função pode continuar ocupando memória?
4. Por que aumentar `UV_THREADPOOL_SIZE` não acelera automaticamente um cálculo JavaScript?

### Respostas esperadas

1. `c()` precisa terminar para `b()` continuar, e `b()` precisa terminar para `a()` continuar. A última chamada a entrar é a primeira a sair.
2. Copiar uma referência faz duas variáveis apontarem para o mesmo objeto. Copiar o objeto cria outro objeto, embora uma cópia rasa ainda possa compartilhar objetos internos.
3. Outra parte do programa pode manter uma referência ao objeto depois que a função termina.
4. O pool executa tarefas nativas específicas. Ele não divide automaticamente um cálculo JavaScript entre suas threads.

Próximo: [V8, desempenho e erros](02-v8-performance-e-erros.md).
