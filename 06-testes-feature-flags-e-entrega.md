# 06 — Testes, feature flags e entrega gradual

**Objetivo:** verificar o comportamento do código e liberar mudanças aos poucos.

## 1. O teste deve proteger um comportamento

Um teste útil expressa algo que o sistema precisa garantir. No fluxo de pagamento, não basta verificar que uma função interna foi chamada: pode ser necessário garantir que uma entrada inválida não criou uma cobrança, ou que um evento duplicado não alterou o saldo duas vezes.

| Tipo de teste | Escopo típico | Exemplo |
| --- | --- | --- |
| Unitário | Uma regra ou componente isolado | Calcular um desconto dentro do limite |
| Integração | Componentes colaborando | Serviço persistindo e consultando no banco de teste |
| Contrato | Acordo em uma fronteira | Resposta do parceiro possui o formato esperado |
| Ponta a ponta | Caminho completo relevante | Requisição HTTP gera o resultado de negócio |
| Carga e estresse | Comportamento sob volume e saturação | Verificar latência e erros com aumento de requisições |

As equipes podem usar esses nomes de formas diferentes. Explique o que cada teste executa, quais dependências são reais e quais falhas ele detecta.

## 2. Ambientes efêmeros e mocks

Uma estratégia é criar um banco temporário na pipeline, preparar sua estrutura e testar a API. Ao terminar, o ambiente é removido. Assim, os testes não dependem dos dados imprevisíveis de um banco compartilhado.

Um fluxo de validação pode ser:

```text
Criar banco de teste
    → aplicar migrações
    → preparar dados mínimos
    → iniciar a aplicação
    → executar os cenários
    → coletar relatórios
    → encerrar os recursos mesmo se houver falha
```

Um banco real temporário permite testar consultas e restrições que um mock pode não reproduzir. Já os mocks ajudam a simular falhas difíceis de provocar e a testar integrações externas sem chamá-las a cada execução.

Se dividir a suíte em várias máquinas, cada grupo deve ter isolamento de dados e recursos. Paralelizar testes que modificam o mesmo estado pode criar falhas intermitentes. O número de testes por máquina deve ser ajustado ao custo dos cenários e aos recursos disponíveis.

## 3. Valide as respostas dos parceiros em runtime

Uma anotação TypeScript não verifica o JSON que chega pela rede. Se o fornecedor mudar o formato da resposta, o erro pode aparecer só mais adiante, longe da integração que o causou.

Exemplo TypeScript com Zod. Dependência necessária: `npm install zod`. A função abaixo é um fragmento reutilizável; o chamador fornece a URL e trata as falhas:

```ts
import { z } from 'zod';

const RespostaPagamento = z.object({
  id: z.string().min(1),
  status: z.enum(['aprovado', 'recusado', 'pendente']),
  valorCentavos: z.number().int().nonnegative().safe(),
});

export async function consultarPagamento(url: string) {
  const resposta = await fetch(url, {
    signal: AbortSignal.timeout(3_000),
  });

  if (!resposta.ok) {
    throw new Error(`Parceiro respondeu HTTP ${resposta.status}`);
  }

  const corpo: unknown = await resposta.json();
  return RespostaPagamento.parse(corpo);
}
```

A checagem de status evita tratar uma página de erro como pagamento válido. O timeout limita o tempo de espera. O schema confere a estrutura recebida, mas ainda não garante, por exemplo, que o ID corresponda ao pedido consultado.

**Complemento didático:** critérios adicionais podem limitar tamanho da resposta, validar correlação, verificar autenticação e definir quais falhas aceitam retry. Uma nova tentativa de operação com efeito colateral exige idempotência.

Para testar terceiros, use um substituto controlado ou a homologação do parceiro. Ambiente de teste não deve disparar cobranças e webhooks no ambiente de produção. Respostas representativas e cenários de contrato ajudam sem tornar toda pipeline dependente da disponibilidade externa.

<p align="center">
  <strong>Diagrama — Validar uma integração externa</strong>
</p>

<p align="center">
  <a href="diagramas/svg/06-contrato.svg">
    <img src="diagramas/svg/06-contrato.svg" alt="Validar uma integração externa" />
  </a>
</p>

<p align="center">
  <a href="diagramas/svg/06-contrato.svg">Ampliar SVG</a> · <a href="diagramas/06-contrato.mmd">Fonte (Mermaid)</a>
</p>

## 4. Feature flags separam deploy de exposição

Deploy coloca o código em um ambiente. Release disponibiliza um comportamento a um público. Uma feature flag permite implantar o código e ativar a funcionalidade apenas para um grupo.

Exemplo completo de roteamento para dois comportamentos sem efeitos externos:

```js
const configuracao = {
  novaBuscaAtiva: true,
  empresasPiloto: new Set(['empresa-a']),
};

function escolherBusca(empresaId, config) {
  return config.novaBuscaAtiva && config.empresasPiloto.has(empresaId)
    ? 'v2'
    : 'v1';
}

console.log(escolherBusca('empresa-a', configuracao)); // v2
console.log(escolherBusca('empresa-b', configuracao)); // v1

configuracao.novaBuscaAtiva = false;
console.log(escolherBusca('empresa-a', configuracao)); // v1
```

Em produção, defina como a configuração muda, quem pode alterá-la e o comportamento se o serviço de flags falhar. Se o mesmo usuário alterna de grupo a cada requisição, a análise fica difícil; grupos estáveis facilitam a comparação.

Uma flag não garante rollback de dados. Migrações destrutivas e efeitos já executados continuam existindo depois de desligar uma funcionalidade. Planeje compatibilidade entre versões e remoção posterior das flags temporárias.

<p align="center">
  <strong>Diagrama — Deploy não é exposição ao público</strong>
</p>

<p align="center">
  <a href="diagramas/svg/06-release.svg">
    <img src="diagramas/svg/06-release.svg" alt="Deploy não é exposição ao público" />
  </a>
</p>

<p align="center">
  <a href="diagramas/svg/06-release.svg">Ampliar SVG</a> · <a href="diagramas/06-release.mmd">Fonte (Mermaid)</a>
</p>

## 5. Fallback exige equivalência de negócio

Fallback é recorrer a uma alternativa quando a tentativa principal falha. Uma opção é chamar a versão anterior de uma consulta sem efeitos colaterais. O resultado precisa ser aceitável para o negócio, e a falha deve ficar registrada.

Exemplo completo para uma leitura simulada:

```js
async function consultarComFallback(buscaNova, buscaAntiga, registrar) {
  try {
    return await buscaNova();
  } catch (erro) {
    registrar({ evento: 'fallback_consulta', mensagem: String(erro) });
    return buscaAntiga();
  }
}

const resultado = await consultarComFallback(
  async () => { throw new Error('Fonte nova indisponível'); },
  async () => ({ origem: 'anterior', itens: [] }),
  (evento) => console.log(evento),
);

console.log(resultado.origem); // anterior
```

**Limite importante:** se a primeira tentativa realizou uma cobrança e apenas a resposta se perdeu, chamar outra implementação pode cobrar novamente. Nesse caso, é preciso identificar a operação, consultar seu estado e usar garantias de idempotência. Um `catch` genérico não cria essas garantias.

Fail-fast significa interromper quando uma condição impede continuar corretamente. Uma degradação controlada procura preservar uma parte válida do serviço. Nenhuma das abordagens é universal: autorização, integridade e regras de negócio determinam quando continuar é aceitável.

## 6. Revisão adversarial e testes de falha

Uma revisão adversarial procura situações em que a implementação falha: entradas inesperadas, timeouts, repetição, indisponibilidade e excesso de volume. Ela explora o que pode dar errado além do caminho de sucesso.

Planeje experimentos em um ambiente controlado, com limites de carga e critérios de parada. A lista de cenários pode incluir resposta inválida de parceiro, worker encerrado durante o processamento, mensagem duplicada e banco temporariamente indisponível.

Um teste de carga aumenta volume para observar comportamento. Chaos engineering trabalha com hipóteses e falhas introduzidas de forma controlada. Os termos não são intercambiáveis, embora os experimentos possam se complementar.

## 7. O que uma tarefa de entrega deve registrar

Uma tarefa relevante deve indicar comportamento esperado, validação, métricas necessárias e ação de recuperação. Algumas mudanças precisam apenas de um teste e um log; outras exigem dashboard, flag e alerta.

Escolha os mecanismos de acordo com a importância do fluxo. O time precisa conseguir verificar o resultado e agir se houver uma falha.

## Revisão ativa

1. Qual falha um banco real de teste detecta e um mock simples pode esconder?
2. Por que conferir apenas o tipo TypeScript de uma resposta HTTP é insuficiente?
3. Por que desligar uma flag não desfaz automaticamente uma cobrança?
4. Qual diferença entre fallback de leitura e retry de escrita com efeito financeiro?

### Respostas esperadas

1. Um banco real pode revelar erros nas consultas, migrações e restrições que o mock não reproduz.
2. O tipo TypeScript não confere os dados recebidos. Essa validação precisa acontecer durante a execução.
3. A flag muda qual código será usado. Ela não remove uma cobrança já realizada ou outros efeitos persistidos.
4. Um fallback de leitura pode devolver um resultado alternativo aceitável. Repetir uma escrita financeira pode cobrar de novo se a primeira tentativa já tiver sido aceita.

Próximo: [Infraestrutura Node.js na AWS](07-infraestrutura-nodejs-na-aws.md).
