# 📋 Sistema Organizador de Tarefas — Documentação do Banco de Dados

> **Banco:** `task_organizer` | **Engine:** InnoDB | **Charset:** utf8mb4_unicode_ci | **Versão:** 1.0

---

## Sumário

1. [Visão Geral da Arquitetura](#1-visão-geral-da-arquitetura)
2. [Diagrama MER — Texto Estruturado](#2-diagrama-mer--texto-estruturado)
3. [Módulos do Sistema](#3-módulos-do-sistema)
4. [Descrição Detalhada de Cada Tabela](#4-descrição-detalhada-de-cada-tabela)
5. [Todos os Relacionamentos](#5-todos-os-relacionamentos)
6. [Triggers](#6-triggers)
7. [Procedures e Funções](#7-procedures-e-funções)
8. [Views](#8-views)
9. [Regras de Negócio Consolidadas](#9-regras-de-negócio-consolidadas)
10. [Diagrama MER Visual (ASCII)](#10-diagrama-mer-visual-ascii)
11. [Como Executar](#11-como-executar)

---

## 1. Visão Geral da Arquitetura

O banco de dados `task_organizer` foi projetado para suportar um sistema colaborativo de gerenciamento de tarefas com as seguintes capacidades:

- **Multiusuário** com controle de papéis e permissões
- **Projetos colaborativos** com múltiplos membros
- **Tarefas hierárquicas** (tarefas e subtarefas)
- **Rastreamento de tempo** trabalhado por tarefa
- **Histórico de auditoria** completo e imutável
- **Notificações e lembretes** configuráveis
- **Dependências entre tarefas** (bloqueio de fluxo)
- **Checklists, comentários e anexos** por tarefa

O banco possui **17 tabelas**, organizadas em **7 módulos funcionais**, com **8 triggers**, **2 stored procedures**, **2 funções** e **3 views**.

---

## 2. Diagrama MER — Texto Estruturado

Abaixo a representação dos relacionamentos no formato entidade → cardinalidade → entidade:

```
usuarios            ||──o{    projetos              (1 usuário cria N projetos)
usuarios            ||──o{    categorias            (1 usuário tem N categorias pessoais)
usuarios            ||──o{    etiquetas             (1 usuário tem N etiquetas)
usuarios            ||──o{    tarefas               (1 usuário cria N tarefas)
usuarios            ||──o{    comentarios           (1 usuário escreve N comentários)
usuarios            ||──o{    lembretes             (1 usuário tem N lembretes)
usuarios            ||──o{    notificacoes          (1 usuário recebe N notificações)
usuarios            ||──||    configuracoes_usuario (1 usuário tem 1 configuração)

projetos            ||──o{    membros_projeto       (1 projeto tem N membros)
projetos            ||──o{    tarefas               (1 projeto tem N tarefas)

categorias          }o──o{    tarefas               (N tarefas pertencem a 1 categoria)
categorias          }o──o|    categorias            (auto-relacionamento: subcategoria)

tarefas             ||──o{    tarefas               (auto-relacionamento: subtarefas)
tarefas             ||──o{    checklist             (1 tarefa tem N checklists)
tarefas             ||──o{    comentarios           (1 tarefa tem N comentários)
tarefas             ||──o{    anexos                (1 tarefa tem N anexos)
tarefas             ||──o{    historico_tarefas     (1 tarefa tem N registros de histórico)
tarefas             ||──o{    lembretes             (1 tarefa tem N lembretes)
tarefas             ||──o{    tempo_registrado      (1 tarefa tem N registros de tempo)
tarefas             ||──o{    dependencias_tarefa   (1 tarefa tem N dependências)
tarefas             }o──o{    etiquetas             (N:N via tarefa_etiquetas)
tarefas             }o──o{    usuarios              (N:N via tarefa_responsaveis)

checklists          ||──o{    checklist_itens       (1 checklist tem N itens)
```

---

## 3. Módulos do Sistema

| # | Módulo | Tabelas |
|---|--------|---------|
| 1 | **Identidade & Acesso** | `usuarios`, `configuracoes_usuario` |
| 2 | **Taxonomia** | `categorias`, `etiquetas` |
| 3 | **Projetos** | `projetos`, `membros_projeto` |
| 4 | **Tarefas** | `tarefas`, `tarefa_responsaveis`, `tarefa_etiquetas`, `dependencias_tarefa` |
| 5 | **Conteúdo** | `checklists`, `checklist_itens`, `comentarios`, `anexos` |
| 6 | **Produtividade** | `tempo_registrado`, `lembretes` |
| 7 | **Rastreamento** | `historico_tarefas`, `notificacoes` |

---

## 4. Descrição Detalhada de Cada Tabela

---

### 4.1 `usuarios`
**Módulo:** Identidade & Acesso

Entidade central do sistema. Representa cada pessoa que acessa a plataforma.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | INT UNSIGNED PK | Identificador único auto-incremento |
| `nome` | VARCHAR(100) | Nome completo do usuário |
| `email` | VARCHAR(150) UNIQUE | E-mail de login — único no sistema |
| `senha_hash` | VARCHAR(255) | Hash da senha (bcrypt/argon2) — nunca texto puro |
| `perfil` | ENUM | `admin` / `gerente` / `membro` — controla permissões globais |
| `status` | ENUM | `ativo` / `inativo` / `suspenso` |
| `avatar_url` | VARCHAR(500) | URL da foto de perfil |
| `telefone` | VARCHAR(20) | Telefone para SMS de lembretes |
| `fuso_horario` | VARCHAR(60) | Timezone IANA (ex: `America/Sao_Paulo`) |
| `token_reset_senha` | VARCHAR(255) | Token temporário para recuperação de senha |
| `token_expira_em` | DATETIME | Validade do token de reset |
| `ultimo_login` | DATETIME | Auditoria de acesso |
| `criado_em` | DATETIME | Preenchido automaticamente na criação |
| `atualizado_em` | DATETIME | Atualizado automaticamente a cada UPDATE |

**Regras de negócio:**
- E-mail deve ser único (índice UNIQUE).
- Senha nunca é armazenada em texto puro.
- Ao criar um usuário, um trigger cria automaticamente seu registro em `configuracoes_usuario`.

---

### 4.2 `configuracoes_usuario`
**Módulo:** Identidade & Acesso

Armazena as preferências individuais de cada usuário. Relação **1:1** com `usuarios`.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `usuario_id` | INT UNSIGNED PK/FK | Referência ao usuário dono |
| `notif_email` | BOOLEAN | Liga/desliga notificações por e-mail |
| `notif_push` | BOOLEAN | Liga/desliga notificações push |
| `notif_prazo` | BOOLEAN | Notificar sobre prazos |
| `notif_atribuicao` | BOOLEAN | Notificar ao ser atribuído |
| `notif_comentario` | BOOLEAN | Notificar novos comentários |
| `notif_mencao` | BOOLEAN | Notificar menções (@usuario) |
| `vista_padrao` | ENUM | Visão padrão: `lista` / `kanban` / `calendario` / `gantt` |
| `tema` | ENUM | Tema visual: `claro` / `escuro` / `sistema` |
| `idioma` | CHAR(5) | Código de idioma BCP-47 (ex: `pt-BR`) |
| `semana_comeca_em` | TINYINT | `0` = Domingo, `1` = Segunda |
| `formato_data` | VARCHAR(20) | Padrão de formatação (ex: `DD/MM/YYYY`) |

**Regras de negócio:**
- Registro criado automaticamente via trigger ao inserir em `usuarios`.
- Chave primária é o próprio `usuario_id` (PK = FK).

---

### 4.3 `categorias`
**Módulo:** Taxonomia

Classificações temáticas para projetos e tarefas. Podem ser **globais** (criadas pelo admin) ou **pessoais** (criadas pelo usuário).

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | INT UNSIGNED PK | Identificador único |
| `nome` | VARCHAR(100) | Nome da categoria |
| `descricao` | VARCHAR(255) | Descrição opcional |
| `cor` | CHAR(7) | Cor hexadecimal (ex: `#FF5733`) |
| `icone` | VARCHAR(50) | Classe de ícone (ex: `fa-briefcase`) |
| `categoria_pai_id` | INT UNSIGNED FK | Auto-relacionamento: subcategoria |
| `usuario_id` | INT UNSIGNED FK | `NULL` = categoria global (admin) |

**Regras de negócio:**
- `usuario_id = NULL` indica categoria global, visível para todos.
- Hierarquia de um nível via auto-relacionamento `categoria_pai_id → id`.
- Ao deletar categoria pai, `categoria_pai_id` dos filhos vira `NULL` (SET NULL).
- Ao deletar usuário, suas categorias pessoais são removidas (CASCADE).

---

### 4.4 `etiquetas`
**Módulo:** Taxonomia

Tags livres criadas pelos usuários para classificação flexível de tarefas. Sempre pessoais (nunca globais).

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | INT UNSIGNED PK | Identificador único |
| `usuario_id` | INT UNSIGNED FK | Dono da etiqueta |
| `nome` | VARCHAR(60) | Nome da tag |
| `cor` | CHAR(7) | Cor hexadecimal |

**Regras de negócio:**
- Nome de etiqueta é único por usuário (índice UNIQUE composto `usuario_id + nome`).
- Relacionada a tarefas via tabela intermediária `tarefa_etiquetas`.

---

### 4.5 `projetos`
**Módulo:** Projetos

Agrupa um conjunto de tarefas relacionadas a um objetivo comum.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | INT UNSIGNED PK | Identificador único |
| `usuario_id` | INT UNSIGNED FK | Dono/criador do projeto |
| `nome` | VARCHAR(150) | Nome do projeto |
| `descricao` | TEXT | Descrição detalhada |
| `cor` | CHAR(7) | Cor de identificação visual |
| `icone` | VARCHAR(50) | Ícone do projeto |
| `status` | ENUM | `rascunho` / `ativo` / `pausado` / `concluido` / `cancelado` |
| `prioridade` | ENUM | `baixa` / `media` / `alta` / `critica` |
| `data_inicio` | DATE | Data de início planejada |
| `data_fim_prevista` | DATE | Prazo esperado de conclusão |
| `data_fim_real` | DATE | Data real de conclusão (preenchida automaticamente) |
| `progresso` | TINYINT(0-100) | Percentual calculado via trigger |
| `categoria_id` | INT UNSIGNED FK | Categoria do projeto |

**Regras de negócio:**
- `data_fim_prevista >= data_inicio` (CHECK constraint).
- `progresso` entre 0 e 100 (CHECK constraint).
- Quando `progresso` chega a 100, trigger marca `status = 'concluido'` e preenche `data_fim_real`.
- Dono do projeto (ON DELETE RESTRICT) — projeto não pode ficar sem dono.

---

### 4.6 `membros_projeto`
**Módulo:** Projetos

Controla quais usuários participam de cada projeto e com qual papel. Relação **N:N** entre `usuarios` e `projetos`.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | INT UNSIGNED PK | Identificador único |
| `projeto_id` | INT UNSIGNED FK | Projeto |
| `usuario_id` | INT UNSIGNED FK | Usuário membro |
| `papel` | ENUM | `visualizador` / `colaborador` / `editor` / `admin` |
| `convidado_por` | INT UNSIGNED FK | Quem enviou o convite |
| `aceito_em` | DATETIME | `NULL` = convite pendente; preenchido ao aceitar |

**Regras de negócio:**
- Um usuário não pode ser membro duplicado no mesmo projeto (UNIQUE `projeto_id + usuario_id`).
- Convite pendente: `aceito_em = NULL`.
- `papel = 'admin'` é concedido ao dono automaticamente pela procedure de criação.

---

### 4.7 `tarefas`
**Módulo:** Tarefas

Entidade principal do sistema. Representa uma unidade de trabalho, podendo ser independente ou pertencer a um projeto.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | INT UNSIGNED PK | Identificador único |
| `projeto_id` | INT UNSIGNED FK | `NULL` = tarefa pessoal sem projeto |
| `tarefa_pai_id` | INT UNSIGNED FK | Auto-relacionamento: define subtarefas |
| `criado_por` | INT UNSIGNED FK | Usuário que criou a tarefa |
| `responsavel_id` | INT UNSIGNED FK | Responsável principal |
| `categoria_id` | INT UNSIGNED FK | Categoria da tarefa |
| `titulo` | VARCHAR(250) | Título da tarefa |
| `descricao` | TEXT | Descrição detalhada |
| `status` | ENUM | `pendente` / `em_andamento` / `em_revisao` / `concluida` / `cancelada` |
| `prioridade` | ENUM | `baixa` / `media` / `alta` / `critica` |
| `data_inicio` | DATETIME | Quando a tarefa deve iniciar |
| `data_prazo` | DATETIME | Deadline da tarefa |
| `data_conclusao` | DATETIME | Quando foi realmente concluída |
| `horas_estimadas` | DECIMAL(6,2) | Estimativa de esforço em horas |
| `horas_trabalhadas` | DECIMAL(6,2) | Calculado automaticamente via trigger |
| `pontuacao` | SMALLINT | Story points (metodologias ágeis) |
| `ordem` | INT | Posição no board Kanban/lista |
| `recorrente` | BOOLEAN | Se a tarefa se repete |
| `tipo_recorrencia` | ENUM | `diaria` / `semanal` / `quinzenal` / `mensal` / `anual` |
| `proxima_recorrencia` | DATE | Próxima data de geração da recorrência |

**Regras de negócio:**
- `tarefa_pai_id <> id` — uma tarefa não pode ser subtarefa de si mesma (CHECK).
- `data_prazo >= data_inicio` (CHECK).
- Se `recorrente = TRUE`, então `tipo_recorrencia` é obrigatório (CHECK).
- `horas_trabalhadas` é atualizado automaticamente via trigger ao inserir em `tempo_registrado`.
- Ao concluir uma tarefa, o trigger recalcula o `progresso` do projeto pai.

---

### 4.8 `tarefa_responsaveis`
**Módulo:** Tarefas

Permite que uma tarefa tenha **múltiplos responsáveis** além do responsável principal. Relação **N:N** entre `tarefas` e `usuarios`.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `tarefa_id` | INT UNSIGNED PK/FK | Tarefa |
| `usuario_id` | INT UNSIGNED PK/FK | Usuário responsável adicional |
| `atribuido_em` | DATETIME | Timestamp da atribuição |
| `atribuido_por` | INT UNSIGNED FK | Quem fez a atribuição |

**Regras de negócio:**
- Chave primária composta impede duplicidade de responsável na mesma tarefa.
- A procedure `sp_atribuir_responsavel` valida se o usuário é membro do projeto antes de inserir.

---

### 4.9 `tarefa_etiquetas`
**Módulo:** Tarefas

Tabela de junção para o relacionamento **N:N** entre `tarefas` e `etiquetas`.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `tarefa_id` | INT UNSIGNED PK/FK | Tarefa |
| `etiqueta_id` | INT UNSIGNED PK/FK | Etiqueta vinculada |

**Regras de negócio:**
- Chave primária composta impede duplicidade.
- Ao remover tarefa ou etiqueta, registros são removidos em cascata.

---

### 4.10 `dependencias_tarefa`
**Módulo:** Tarefas

Define relações de **bloqueio e dependência** entre tarefas.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | INT UNSIGNED PK | Identificador único |
| `tarefa_id` | INT UNSIGNED FK | Tarefa que **depende** de outra |
| `depende_de_id` | INT UNSIGNED FK | Tarefa **bloqueante** |
| `tipo` | ENUM | `bloqueia` / `relacionada` / `duplicata` |

**Regras de negócio:**
- `tarefa_id <> depende_de_id` — uma tarefa não pode depender de si mesma (CHECK).
- UNIQUE composto impede dependência duplicada.
- A procedure `sp_concluir_tarefa` verifica se existem dependências do tipo `bloqueia` ainda abertas antes de permitir a conclusão.

---

### 4.11 `checklists`
**Módulo:** Conteúdo

Listas de verificação associadas a uma tarefa. Uma tarefa pode ter múltiplos checklists.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | INT UNSIGNED PK | Identificador único |
| `tarefa_id` | INT UNSIGNED FK | Tarefa dona do checklist |
| `titulo` | VARCHAR(150) | Título da lista |
| `ordem` | TINYINT | Posição de exibição entre os checklists |

---

### 4.12 `checklist_itens`
**Módulo:** Conteúdo

Itens individuais marcáveis dentro de um checklist.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | INT UNSIGNED PK | Identificador único |
| `checklist_id` | INT UNSIGNED FK | Checklist pai |
| `descricao` | VARCHAR(300) | Texto do item |
| `concluido` | BOOLEAN | Se o item foi marcado |
| `concluido_por` | INT UNSIGNED FK | Usuário que marcou |
| `concluido_em` | DATETIME | Timestamp da conclusão (preenchido por trigger) |
| `ordem` | SMALLINT | Posição de exibição |

**Regras de negócio:**
- Trigger preenche automaticamente `concluido_em` ao marcar o item.
- Ao desmarcar, `concluido_em` e `concluido_por` são zerados automaticamente.

---

### 4.13 `comentarios`
**Módulo:** Conteúdo

Discussão colaborativa vinculada a cada tarefa.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | INT UNSIGNED PK | Identificador único |
| `tarefa_id` | INT UNSIGNED FK | Tarefa comentada |
| `usuario_id` | INT UNSIGNED FK | Autor do comentário |
| `conteudo` | TEXT | Corpo do comentário (suporta Markdown) |
| `editado` | BOOLEAN | Se o conteúdo foi alterado |
| `editado_em` | DATETIME | Timestamp da última edição |
| `deletado` | BOOLEAN | Soft delete |
| `deletado_em` | DATETIME | Timestamp da remoção lógica |

**Regras de negócio:**
- **Soft delete**: comentários não são fisicamente removidos.
- Trigger detecta mudança de `conteudo` e marca `editado = TRUE` e `editado_em = NOW()` automaticamente.
- `ON DELETE RESTRICT` em `usuario_id` — usuário não pode ser removido se tiver comentários.

---

### 4.14 `anexos`
**Módulo:** Conteúdo

Arquivos carregados (upload) e vinculados a tarefas.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | INT UNSIGNED PK | Identificador único |
| `tarefa_id` | INT UNSIGNED FK | Tarefa dona do arquivo |
| `usuario_id` | INT UNSIGNED FK | Quem fez o upload |
| `nome_original` | VARCHAR(255) | Nome do arquivo conforme enviado |
| `nome_storage` | VARCHAR(255) | Nome interno no storage (UUID) |
| `mime_type` | VARCHAR(100) | Tipo MIME do arquivo |
| `tamanho_bytes` | BIGINT UNSIGNED | Tamanho em bytes |
| `url` | VARCHAR(500) | URL de acesso ao arquivo |
| `deletado` | BOOLEAN | Soft delete |

**Regras de negócio:**
- Nome no storage é gerado como UUID para evitar colisões.
- Validação de tipo e tamanho máximo deve ser realizada na camada de aplicação.
- Soft delete mantém rastreabilidade mesmo após remoção.

---

### 4.15 `tempo_registrado`
**Módulo:** Produtividade

Registro de sessões de trabalho (time tracking) por usuário e por tarefa.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | BIGINT UNSIGNED PK | Identificador único |
| `tarefa_id` | INT UNSIGNED FK | Tarefa trabalhada |
| `usuario_id` | INT UNSIGNED FK | Usuário que trabalhou |
| `inicio` | DATETIME | Início da sessão |
| `fim` | DATETIME | Fim da sessão |
| `duracao_minutos` | INT UNSIGNED | Calculado automaticamente pelo trigger |
| `descricao` | VARCHAR(300) | Descrição do que foi feito |

**Regras de negócio:**
- `fim > inicio` — constraint CHECK impede inversão de horário.
- Trigger `trg_tempo_calcular_duracao` preenche `duracao_minutos` automaticamente ao inserir.
- Trigger `trg_tempo_atualizar_horas_tarefa` recalcula `tarefas.horas_trabalhadas` após cada inserção.

---

### 4.16 `lembretes`
**Módulo:** Produtividade

Agendamento de alertas futuros vinculados a tarefas, por canal de entrega.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | INT UNSIGNED PK | Identificador único |
| `tarefa_id` | INT UNSIGNED FK | Tarefa referenciada |
| `usuario_id` | INT UNSIGNED FK | Destinatário do lembrete |
| `data_hora` | DATETIME | Quando o lembrete deve ser disparado |
| `canal` | SET | `email` / `push` / `sms` (pode combinar) |
| `mensagem` | VARCHAR(300) | Mensagem customizada |
| `enviado` | BOOLEAN | Se já foi disparado |
| `enviado_em` | DATETIME | Timestamp do envio |

**Regras de negócio:**
- O campo `canal` é do tipo SET, permitindo múltiplos canais simultâneos (ex: `'email,push'`).
- O índice `idx_enviado_data` otimiza a consulta do job de disparo de lembretes.
- Validação de `data_hora` no futuro deve ser realizada na camada de aplicação.

---

### 4.17 `historico_tarefas`
**Módulo:** Rastreamento

Log de auditoria **imutável** de todas as alterações realizadas nas tarefas.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | BIGINT UNSIGNED PK | Identificador único (BIGINT para volume alto) |
| `tarefa_id` | INT UNSIGNED FK | Tarefa afetada |
| `usuario_id` | INT UNSIGNED FK | Quem realizou a ação (`NULL` = sistema) |
| `acao` | VARCHAR(80) | Tipo da ação (ex: `status_alterado`) |
| `campo` | VARCHAR(80) | Campo que foi alterado |
| `valor_anterior` | TEXT | Valor antes da alteração |
| `valor_novo` | TEXT | Valor após a alteração |
| `criado_em` | DATETIME | Timestamp da ação |

**Regras de negócio:**
- Registros nunca são atualizados — apenas inseridos (imutabilidade por convenção).
- Preenchido automaticamente por triggers e pela procedure `sp_concluir_tarefa`.
- `usuario_id = NULL` indica ação automática do sistema.

---

### 4.18 `notificacoes`
**Módulo:** Rastreamento

Central de mensagens e alertas entregues aos usuários dentro do sistema.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | BIGINT UNSIGNED PK | Identificador único |
| `usuario_id` | INT UNSIGNED FK | Destinatário |
| `tipo` | ENUM | `prazo_proximo` / `tarefa_atribuida` / `comentario` / `mencao` / `conclusao` / `lembrete` / `convite_projeto` / `sistema` |
| `titulo` | VARCHAR(200) | Título exibido na notificação |
| `mensagem` | TEXT | Corpo detalhado |
| `referencia_tipo` | VARCHAR(50) | Tipo do objeto relacionado (ex: `tarefa`) |
| `referencia_id` | INT UNSIGNED | ID do objeto relacionado |
| `lida` | BOOLEAN | Se o usuário já visualizou |
| `lida_em` | DATETIME | Timestamp de leitura |
| `expira_em` | DATETIME | TTL da notificação (sugerido: 90 dias) |

---

## 5. Todos os Relacionamentos

### 5.1 Relacionamentos 1:1

| Tabela A | Tabela B | Chave | Descrição |
|----------|----------|-------|-----------|
| `usuarios` | `configuracoes_usuario` | `configuracoes_usuario.usuario_id` | Cada usuário tem exatamente uma configuração |

---

### 5.2 Relacionamentos 1:N

| Tabela "1" | Tabela "N" | Chave Estrangeira | ON DELETE |
|------------|------------|-------------------|-----------|
| `usuarios` | `projetos` | `projetos.usuario_id` | RESTRICT |
| `usuarios` | `categorias` | `categorias.usuario_id` | CASCADE |
| `usuarios` | `etiquetas` | `etiquetas.usuario_id` | CASCADE |
| `usuarios` | `tarefas` (criador) | `tarefas.criado_por` | RESTRICT |
| `usuarios` | `tarefas` (responsável) | `tarefas.responsavel_id` | SET NULL |
| `usuarios` | `comentarios` | `comentarios.usuario_id` | RESTRICT |
| `usuarios` | `anexos` | `anexos.usuario_id` | RESTRICT |
| `usuarios` | `lembretes` | `lembretes.usuario_id` | CASCADE |
| `usuarios` | `notificacoes` | `notificacoes.usuario_id` | CASCADE |
| `usuarios` | `historico_tarefas` | `historico_tarefas.usuario_id` | SET NULL |
| `usuarios` | `tempo_registrado` | `tempo_registrado.usuario_id` | RESTRICT |
| `projetos` | `tarefas` | `tarefas.projeto_id` | CASCADE |
| `projetos` | `membros_projeto` | `membros_projeto.projeto_id` | CASCADE |
| `categorias` | `tarefas` | `tarefas.categoria_id` | SET NULL |
| `categorias` | `projetos` | `projetos.categoria_id` | SET NULL |
| `tarefas` | `checklists` | `checklists.tarefa_id` | CASCADE |
| `tarefas` | `comentarios` | `comentarios.tarefa_id` | CASCADE |
| `tarefas` | `anexos` | `anexos.tarefa_id` | CASCADE |
| `tarefas` | `lembretes` | `lembretes.tarefa_id` | CASCADE |
| `tarefas` | `historico_tarefas` | `historico_tarefas.tarefa_id` | CASCADE |
| `tarefas` | `tempo_registrado` | `tempo_registrado.tarefa_id` | CASCADE |
| `checklists` | `checklist_itens` | `checklist_itens.checklist_id` | CASCADE |

---

### 5.3 Relacionamentos N:N (via tabela intermediária)

| Tabela A | Tabela B | Tabela Intermediária | Colunas |
|----------|----------|---------------------|---------|
| `tarefas` | `etiquetas` | `tarefa_etiquetas` | `tarefa_id`, `etiqueta_id` |
| `tarefas` | `usuarios` | `tarefa_responsaveis` | `tarefa_id`, `usuario_id` |
| `projetos` | `usuarios` | `membros_projeto` | `projeto_id`, `usuario_id` |

---

### 5.4 Auto-relacionamentos

| Tabela | Coluna | Descrição |
|--------|--------|-----------|
| `categorias` | `categoria_pai_id → id` | Hierarquia pai/filho de categorias |
| `tarefas` | `tarefa_pai_id → id` | Hierarquia tarefa/subtarefa |
| `dependencias_tarefa` | `tarefa_id` e `depende_de_id` → `tarefas.id` | Dependência entre duas tarefas distintas |

---

## 6. Triggers

| Trigger | Tabela | Evento | Função |
|---------|--------|--------|--------|
| `trg_tempo_calcular_duracao` | `tempo_registrado` | BEFORE INSERT | Calcula `duracao_minutos = fim - inicio` |
| `trg_tempo_atualizar_horas_tarefa` | `tempo_registrado` | AFTER INSERT | Recalcula `tarefas.horas_trabalhadas` |
| `trg_tarefa_historico_status` | `tarefas` | AFTER UPDATE | Registra mudanças de status, prioridade e prazo no histórico |
| `trg_progresso_projeto` | `tarefas` | AFTER UPDATE | Recalcula `projetos.progresso` ao mudar status da tarefa |
| `trg_projeto_conclusao_automatica` | `projetos` | AFTER UPDATE | Marca projeto como `concluido` quando `progresso = 100` |
| `trg_criar_configuracoes_usuario` | `usuarios` | AFTER INSERT | Cria registro padrão em `configuracoes_usuario` |
| `trg_checklist_concluido_em` | `checklist_itens` | BEFORE UPDATE | Preenche/limpa `concluido_em` ao marcar/desmarcar item |
| `trg_comentario_editado` | `comentarios` | BEFORE UPDATE | Marca `editado = TRUE` e `editado_em = NOW()` ao editar |

---

## 7. Procedures e Funções

### `sp_concluir_tarefa(p_tarefa_id, p_usuario_id)`
Conclui uma tarefa com as seguintes validações:
1. Verifica se o status atual permite conclusão (`pendente`, `em_andamento`, `em_revisao`).
2. Verifica se existem tarefas bloqueantes (tipo `bloqueia`) ainda não concluídas.
3. Atualiza `status = 'concluida'` e `data_conclusao = NOW()`.
4. Insere registro no `historico_tarefas`.

### `sp_atribuir_responsavel(p_tarefa_id, p_responsavel, p_atribuido_por)`
Atribui um responsável a uma tarefa com as seguintes validações:
1. Se a tarefa pertencer a um projeto, verifica se o usuário é membro.
2. Atualiza `tarefas.responsavel_id`.
3. Insere em `tarefa_responsaveis` (IGNORE duplicata).
4. Gera notificação do tipo `tarefa_atribuida` para o responsável.
5. Registra a ação no `historico_tarefas`.

### `fn_progresso_projeto(p_projeto_id)`
Retorna o percentual de conclusão do projeto calculado como:
> `(tarefas raiz concluídas / total de tarefas raiz) × 100`

### `fn_calcular_duracao_minutos(p_inicio, p_fim)`
Função utilitária que retorna a diferença em minutos entre dois DATETIME.

---

## 8. Views

### `vw_tarefas_atrasadas`
Lista todas as tarefas com `data_prazo < NOW()` que não estão concluídas nem canceladas, incluindo o nome do responsável, nome do projeto e quantas horas de atraso.

### `vw_resumo_projetos`
Painel consolidado de projetos com: progresso, total de tarefas, tarefas concluídas, em andamento e atrasadas.

### `vw_minhas_tarefas`
View de dashboard pessoal com todas as tarefas ativas, indicando se estão atrasadas, qual categoria e projeto pertencem.

---

## 9. Regras de Negócio Consolidadas

| # | Regra | Onde está implementada |
|---|-------|----------------------|
| 1 | E-mail de usuário único no sistema | UNIQUE INDEX em `usuarios.email` |
| 2 | Senha nunca armazenada em texto puro | Documentação + convenção de aplicação |
| 3 | Configurações criadas automaticamente ao cadastrar usuário | Trigger `trg_criar_configuracoes_usuario` |
| 4 | Categoria pode ser global (admin) ou pessoal (por usuário) | `categorias.usuario_id = NULL` = global |
| 5 | Hierarquia de categorias (pai/filho) | Auto-relacionamento `categoria_pai_id` |
| 6 | Etiqueta única por nome por usuário | UNIQUE (`usuario_id`, `nome`) |
| 7 | Data fim do projeto deve ser maior ou igual à data início | CHECK `chk_datas_projeto` |
| 8 | Progresso do projeto entre 0 e 100 | CHECK `chk_progresso` |
| 9 | Projeto concluído automaticamente ao atingir 100% | Trigger `trg_projeto_conclusao_automatica` |
| 10 | Usuário membro de projeto não pode ser duplicado | UNIQUE (`projeto_id`, `usuario_id`) |
| 11 | Tarefa não pode ser subtarefa de si mesma | CHECK `chk_nao_pai_proprio` |
| 12 | Data prazo da tarefa >= data início | CHECK `chk_prazo_tarefa` |
| 13 | Tarefa recorrente exige tipo de recorrência | CHECK `chk_recorrencia` |
| 14 | Horas trabalhadas calculadas automaticamente | Trigger `trg_tempo_atualizar_horas_tarefa` |
| 15 | Fim do registro de tempo > início | CHECK `chk_fim_maior_inicio` |
| 16 | Duração em minutos calculada automaticamente | Trigger `trg_tempo_calcular_duracao` |
| 17 | Histórico imutável de alterações de status/prioridade/prazo | Trigger `trg_tarefa_historico_status` |
| 18 | Tarefa bloqueada não pode ser concluída | Procedure `sp_concluir_tarefa` |
| 19 | Responsável deve ser membro do projeto | Procedure `sp_atribuir_responsavel` |
| 20 | Notificação automática ao atribuir responsável | Procedure `sp_atribuir_responsavel` |
| 21 | Progresso do projeto recalculado ao concluir tarefa | Trigger `trg_progresso_projeto` |
| 22 | Comentário marca edição automaticamente | Trigger `trg_comentario_editado` |
| 23 | Item de checklist registra quem/quando concluiu | Trigger `trg_checklist_concluido_em` |
| 24 | Uma tarefa não pode depender de si mesma | CHECK `chk_nao_auto_dependencia` |
| 25 | Soft delete em comentários e anexos | Colunas `deletado` + `deletado_em` |

---

## 10. Diagrama MER Visual (ASCII)

```
┌─────────────────┐         ┌──────────────────────┐
│    usuarios     │─────────│ configuracoes_usuario │
│─────────────────│  1 : 1  │──────────────────────│
│ id (PK)         │         │ usuario_id (PK/FK)    │
│ nome            │         │ notif_email           │
│ email (UNIQUE)  │         │ vista_padrao          │
│ perfil          │         │ tema                  │
│ status          │         └──────────────────────┘
└────────┬────────┘
         │ 1
    ┌────┴────┐
    │         │
    │ N       │ N
    ▼         ▼
┌──────────┐  ┌──────────────┐       ┌───────────┐
│ projetos │  │  categorias  │◄──────│ categorias│
│──────────│  │──────────────│  pai  │ (auto-rel)│
│ id (PK)  │  │ id (PK)      │       └───────────┘
│ nome     │  │ nome         │
│ status   │  │ cor          │
│ progresso│  │ usuario_id   │
└────┬─────┘  └──────┬───────┘
     │                │
     │ 1              │ N
     ▼                ▼
┌─────────────────────────────────────────────────────┐
│                      tarefas                        │
│─────────────────────────────────────────────────────│
│ id (PK)           titulo          status            │
│ projeto_id (FK)   descricao       prioridade        │
│ tarefa_pai_id(FK) data_prazo      horas_estimadas   │
│ criado_por (FK)   data_conclusao  horas_trabalhadas │
│ responsavel_id    recorrente      pontuacao         │
└──────────────────────┬──────────────────────────────┘
                       │
         ┌─────────────┼──────────────┬──────────────┐
         │             │              │              │
         ▼             ▼              ▼              ▼
   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
   │checklists│  │comentarios│  │  anexos  │  │ lembretes│
   │──────────│  │──────────│  │──────────│  │──────────│
   │ id       │  │ id       │  │ id       │  │ id       │
   │ titulo   │  │ conteudo │  │ url      │  │ data_hora│
   └────┬─────┘  │ editado  │  │ deletado │  │ canal    │
        │        │ deletado │  └──────────┘  └──────────┘
        ▼        └──────────┘
  ┌───────────┐
  │checklist_ │
  │  itens    │
  │───────────│
  │ id        │
  │ descricao │
  │ concluido │
  └───────────┘

Relações N:N:
tarefas ◄────► tarefa_etiquetas ◄────► etiquetas
tarefas ◄────► tarefa_responsaveis ◄──► usuarios
projetos ◄───► membros_projeto ◄──────► usuarios

Rastreamento:
tarefas ────► historico_tarefas
tarefas ────► tempo_registrado
usuarios ───► notificacoes
tarefas ────► dependencias_tarefa (auto-N:N)
```

---

## 11. Como Executar

### Pré-requisitos
- MySQL 8.0+ ou MariaDB 10.6+
- Usuário com permissões `CREATE`, `DROP`, `TRIGGER`, `PROCEDURE`, `FUNCTION`

### Importação completa
```bash
mysql -u root -p < task_organizer_database.sql
```

### Verificar tabelas criadas
```sql
USE task_organizer;
SHOW TABLES;
```

### Verificar triggers
```sql
SHOW TRIGGERS FROM task_organizer;
```

### Verificar procedures
```sql
SHOW PROCEDURE STATUS WHERE Db = 'task_organizer';
```

### Verificar views
```sql
SHOW FULL TABLES WHERE Table_type = 'VIEW';
```

### Exemplo de uso — criar tarefa e registrar tempo
```sql
-- Inserir usuário
INSERT INTO usuarios (nome, email, senha_hash) VALUES ('Maria Silva', 'maria@email.com', '$hash');

-- Criar projeto
INSERT INTO projetos (usuario_id, nome, status) VALUES (1, 'Meu Projeto', 'ativo');

-- Criar tarefa
INSERT INTO tarefas (projeto_id, criado_por, titulo, status, prioridade, data_prazo)
VALUES (1, 1, 'Desenvolver tela de login', 'pendente', 'alta', '2024-12-31 18:00:00');

-- Registrar tempo trabalhado
INSERT INTO tempo_registrado (tarefa_id, usuario_id, inicio, fim, descricao)
VALUES (1, 1, '2024-12-01 09:00:00', '2024-12-01 11:30:00', 'Desenvolvimento do formulário');

-- Concluir tarefa via procedure
CALL sp_concluir_tarefa(1, 1);
```

---

> **Versão:** 1.0 | **Gerado em:** 2024 | **Engine:** InnoDB | **Charset:** utf8mb4_unicode_ci
