# 04 — Arquitetura modular, camadas e contratos

**Objetivo:** separar responsabilidades sem criar abstrações que não ajudam o projeto.

## 1. A proposta de arquitetura modular

Uma arquitetura modular com camadas conhecidas pode ajudar equipes que precisam entregar rapidamente. Ela busca facilitar a localização, o teste e a alteração do código, deixando claro o que pertence a cada área do negócio.

Módulos e camadas organizam o código de formas diferentes:

- **Módulos:** agrupam capacidades de negócio, como pagamentos, usuários ou reservas.
- **Camadas:** separam responsabilidades técnicas dentro de cada módulo, como receber uma requisição, executar uma regra e persistir dados.

Exemplo de organização:

```text
src/
  modules/
    usuarios/
      usuarios.controller.ts
      usuarios.service.ts
      usuarios.repository.ts
      usuarios.schema.ts
      index.ts
      guidelines.md
    pagamentos/
      pagamentos.controller.ts
      pagamentos.service.ts
      pagamentos.repository.ts
      pagamentos.schema.ts
      index.ts
      guidelines.md
  shared/
    observabilidade/
  guidelines.md
```

Uma organização apenas por pastas globais, como `controllers/`, `services/` e `repositories/`, costuma espalhar uma mesma funcionalidade por muitos lugares. Agrupar por domínio pode reduzir essa dispersão.

Para isolar módulos, é preciso controlar como eles se acessam. Se um módulo usa diretamente as tabelas e os detalhes internos de outro, os dois continuam acoplados, mesmo em pastas separadas.

## 2. Responsabilidades das camadas

| Camada | Faz | Evite concentrar nela |
| --- | --- | --- |
| Controller ou resolver | Converte protocolo e dados de entrada/saída | Regras centrais de negócio |
| Service ou caso de uso | Coordena decisões e operações do fluxo | Detalhes de HTTP e SQL espalhados |
| Repository | Executa o acesso à persistência | Decidir status HTTP e políticas de interface |
| Schema | Verifica o formato de dados em runtime | Substituir todas as regras de negócio |

Um schema pode garantir que `valorCentavos` seja um inteiro positivo. Saber se o usuário tem saldo, autorização ou limite disponível exige outras verificações.

DTO é um formato de transferência de dados; Zod é uma ferramenta de validação. Um DTO pode ter um schema associado, mas os termos não são sinônimos.

<p align="center">
  <strong>Diagrama — Caminho de uma requisição</strong>
</p>

<p align="center">
  <a href="diagramas/svg/04-camadas.svg">
    <img src="diagramas/svg/04-camadas.svg" alt="Caminho de uma requisição" />
  </a>
</p>

<p align="center">
  <a href="diagramas/svg/04-camadas.svg">Ampliar SVG</a> · <a href="diagramas/04-camadas.mmd">Fonte (Mermaid)</a>
</p>

## 3. DI e DIP são conceitos diferentes

**Injeção de dependência (DI)** significa fornecer uma dependência ao componente que a utiliza, em vez de ele sempre construí-la internamente. Isso pode ser feito com funções comuns, sem classes e sem biblioteca.

**Inversão de dependência (DIP)** orienta a relação entre componentes: regras de nível mais alto dependem de contratos adequados, enquanto detalhes implementam esses contratos.

Exemplo completo em TypeScript:

```ts
type Usuario = { id: string; nome: string };

interface UsuariosRepository {
  buscarPorId(id: string): Promise<Usuario | null>;
}

function criarBuscarUsuario(repository: UsuariosRepository) {
  return async function buscarUsuario(id: string) {
    const usuario = await repository.buscarPorId(id);
    return usuario
      ? { ok: true as const, usuario }
      : { ok: false as const, erro: 'USUARIO_NAO_ENCONTRADO' as const };
  };
}

const dados: Usuario[] = [{ id: 'u1', nome: 'Ana' }];
const repositoryEmMemoria: UsuariosRepository = {
  async buscarPorId(id) {
    return dados.find((usuario) => usuario.id === id) ?? null;
  },
};

const buscarUsuario = criarBuscarUsuario(repositoryEmMemoria);
console.log(await buscarUsuario('u1'));
console.log(await buscarUsuario('u2'));
```

A função recebe o repositório por argumento: isso é DI. O caso de uso pede apenas o contrato de consulta, sem depender de uma ORM específica: esse é o objetivo do DIP no exemplo. A função `criarBuscarUsuario` cria uma função de busca já configurada com o repositório escolhido.

O contrato pode ser declarado com `interface` ou `type`. Não é necessário escrever `implements` em toda classe: a compatibilidade estrutural permite que um valor satisfaça o formato esperado. Veja o [Handbook de interfaces](https://www.typescriptlang.org/docs/handbook/interfaces.html).

<p align="center">
  <strong>Diagrama — DI e DIP vistos separadamente</strong>
</p>

<p align="center">
  <a href="diagramas/svg/04-di.svg">
    <img src="diagramas/svg/04-di.svg" alt="DI e DIP vistos separadamente" />
  </a>
</p>

<p align="center">
  <a href="diagramas/svg/04-di.svg">Ampliar SVG</a> · <a href="diagramas/04-di.mmd">Fonte (Mermaid)</a>
</p>

## 4. Tipos não existem em runtime, mas têm valor

Interfaces e anotações de tipos são removidas na transformação para JavaScript. Elas ajudam a verificar o código antes da execução, documentar contratos e fazer refatorações. Para conferir um JSON recebido pela rede, você precisa de validação em runtime. Veja a documentação de [tipos apagados do TypeScript](https://www.typescriptlang.org/docs/handbook/2/basic-types.html#erased-types).

**Ajuste técnico:** a ausência da interface em runtime não torna DI ou DIP inúteis. Esses mecanismos também ajudam a explicitar dependências, variar configurações, testar componentes e substituir integrações. Sua utilidade depende do problema, não de o tipo ocupar memória durante a execução.

Criar uma interface idêntica para cada classe, sem necessidade de substituição ou isolamento, pode adicionar trabalho desnecessário. A alternativa é desenhar contratos pequenos em fronteiras relevantes.

## 5. Importação direta e mocks de módulo

Também é possível importar um repositório diretamente e substituí-lo em testes. Esse estilo pode reduzir configuração, especialmente em módulos pequenos.

Um fragmento desse desenho seria:

```ts
// Fragmento: o arquivo usuarios.repository.ts deve exportar buscarPorId.
import { buscarPorId } from './usuarios.repository.js';

export async function consultarUsuario(id: string) {
  return buscarPorId(id);
}
```

Para testá-lo isoladamente, o runner precisa oferecer uma forma compatível de substituir a dependência. O comportamento varia com ESM, CommonJS, carregamento e cache de módulos.

**Ajuste técnico:** um mock de módulo não deve ser entendido como uma aplicação obrigatória de `eval` nem como reescrita universal do código-fonte em runtime. O mecanismo depende da ferramenta. Mocks também podem esconder um acoplamento que dificultará outros usos.

| Pergunta | Importação direta | Dependência fornecida |
| --- | --- | --- |
| Existe configuração adicional? | Geralmente menor | Há um ponto de composição |
| A dependência está explícita no contrato? | Aparece nos imports | Aparece nos parâmetros |
| É fácil trocar por requisição ou teste? | Pode depender do runner | Pode receber outro objeto/função |
| É obrigatório usar classes? | Não | Não |

Escolha o desenho que facilite a evolução do sistema com um custo adequado ao problema. A quantidade de arquivos, sozinha, não mostra se uma solução é simples de manter.

## 6. Limites entre módulos

O arquivo `index.ts` pode expor uma API pública do módulo. Outros módulos importam essa API, em vez de acessar livremente detalhes internos. Regras de lint, revisão e testes arquiteturais podem reforçar o limite quando necessário.

Ao transformar um módulo em serviço, uma chamada local pode virar uma chamada HTTP ou uma mensagem. Será preciso lidar com tempo de rede, autenticação, novas tentativas e falhas em que só parte do sistema fica indisponível. Manter os dados consistentes entre serviços também exige cuidado. Os módulos facilitam essa separação, mas ainda há trabalho a fazer.

Uma regra que precisa de uma transação envolvendo várias tabelas merece atenção especial: mover metade dela para outro serviço muda as garantias do fluxo.

## 7. Como justificar a escolha

Uma resposta técnica convincente liga a decisão ao contexto:

> Para uma equipe pequena, começaria com um monólito modular. Cada módulo concentraria suas regras e usaria camadas simples. Isso reduz o custo de navegação e operação. Contratos seriam explícitos nas integrações e fronteiras que precisam de substituição. Separaria serviços quando houver um motivo concreto de escala, autonomia ou isolamento.

Essa proposta depende do contexto descrito. Arquiteturas hexagonal, clean, MVC e em camadas podem atender necessidades diferentes e compartilhar vários princípios.

## Revisão ativa

1. Qual a diferença entre agrupar código por domínio e por camada?
2. É possível aplicar DI com uma função? Localize isso no exemplo.
3. Por que um tipo estático não valida automaticamente uma resposta HTTP?
4. Quais garantias mudam quando um import local vira uma chamada de rede?

### Respostas esperadas

1. A organização por domínio reúne o código de uma funcionalidade. A organização por camada reúne responsabilidades técnicas, como controllers e repositories.
2. Sim. No exemplo, `criarBuscarUsuario` recebe o repositório como argumento.
3. Os tipos são removidos na transformação para JavaScript. A resposta HTTP precisa ser validada durante a execução.
4. A chamada passa a depender da rede e pode falhar mesmo com parte do sistema funcionando. É preciso rever consistência e recuperação.

Próximo: [IA, contexto e tarefas](05-ia-contexto-guidelines-e-tarefas.md).
