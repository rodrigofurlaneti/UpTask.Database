-- =============================================================================
-- SISTEMA ORGANIZADOR DE TAREFAS - MODELAGEM COMPLETA MySQL
-- Versão: 1.0
-- Descrição: Banco de dados completo com todas as regras de negócio modeladas
-- =============================================================================

-- -----------------------------------------------------------------------------
-- CONFIGURAÇÕES INICIAIS
-- -----------------------------------------------------------------------------
SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- -----------------------------------------------------------------------------
-- CRIAÇÃO DO SCHEMA
-- -----------------------------------------------------------------------------
DROP SCHEMA IF EXISTS `task_organizer`;
CREATE SCHEMA IF NOT EXISTS `task_organizer` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `task_organizer`;


-- =============================================================================
-- 1. TABELA: usuarios
--    Regras de negócio:
--    - Email único por usuário
--    - Senha deve ser armazenada como hash (bcrypt/argon2)
--    - Status: ativo, inativo, suspenso
--    - Perfil: admin, gerente, membro
--    - Data de criação e última atualização automáticas
-- =============================================================================
CREATE TABLE IF NOT EXISTS `usuarios` (
  `id`                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `nome`                VARCHAR(100)    NOT NULL,
  `email`               VARCHAR(150)    NOT NULL,
  `senha_hash`          VARCHAR(255)    NOT NULL                        COMMENT 'Hash bcrypt/argon2 - nunca armazenar senha pura',
  `perfil`              ENUM('admin','gerente','membro')
                                        NOT NULL DEFAULT 'membro',
  `status`              ENUM('ativo','inativo','suspenso')
                                        NOT NULL DEFAULT 'ativo',
  `avatar_url`          VARCHAR(500)    NULL,
  `telefone`            VARCHAR(20)     NULL,
  `fuso_horario`        VARCHAR(60)     NOT NULL DEFAULT 'America/Sao_Paulo',
  `token_reset_senha`   VARCHAR(255)    NULL                            COMMENT 'Token temporário para reset de senha',
  `token_expira_em`     DATETIME        NULL,
  `ultimo_login`        DATETIME        NULL,
  `criado_em`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `atualizado_em`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_email` (`email`),
  INDEX `idx_status` (`status`),
  INDEX `idx_perfil` (`perfil`)
) ENGINE=InnoDB COMMENT='Usuários do sistema';


-- =============================================================================
-- 2. TABELA: categorias
--    Regras de negócio:
--    - Categoria pode ser global (admin) ou pessoal (por usuário)
--    - Hierarquia de 1 nível (categoria pai/filho)
--    - Cor em hexadecimal para identificação visual
--    - Ícone opcional
-- =============================================================================
CREATE TABLE IF NOT EXISTS `categorias` (
  `id`                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `nome`                VARCHAR(100)    NOT NULL,
  `descricao`           VARCHAR(255)    NULL,
  `cor`                 CHAR(7)         NOT NULL DEFAULT '#607D8B'      COMMENT 'Hex color ex: #FF5733',
  `icone`               VARCHAR(50)     NULL                            COMMENT 'Nome do ícone ex: fa-briefcase',
  `categoria_pai_id`    INT UNSIGNED    NULL                            COMMENT 'Hierarquia de subcategorias',
  `usuario_id`          INT UNSIGNED    NULL                            COMMENT 'NULL = categoria global (admin)',
  `criado_em`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_usuario` (`usuario_id`),
  INDEX `idx_pai` (`categoria_pai_id`),
  CONSTRAINT `fk_cat_usuario`
    FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_cat_pai`
    FOREIGN KEY (`categoria_pai_id`) REFERENCES `categorias` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Categorias de tarefas';


-- =============================================================================
-- 3. TABELA: etiquetas (tags)
--    Regras de negócio:
--    - Etiqueta é sempre do usuário (não global)
--    - Nome único por usuário
--    - Cor personalizável
-- =============================================================================
CREATE TABLE IF NOT EXISTS `etiquetas` (
  `id`                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `usuario_id`          INT UNSIGNED    NOT NULL,
  `nome`                VARCHAR(60)     NOT NULL,
  `cor`                 CHAR(7)         NOT NULL DEFAULT '#9E9E9E',
  `criado_em`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_tag_usuario` (`usuario_id`, `nome`),
  CONSTRAINT `fk_tag_usuario`
    FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Etiquetas/tags para classificação livre';


-- =============================================================================
-- 4. TABELA: projetos
--    Regras de negócio:
--    - Todo projeto tem um dono (usuario_id)
--    - Status: rascunho, ativo, pausado, concluido, cancelado
--    - Data início não pode ser maior que data fim
--    - Progresso calculado automaticamente via procedure/trigger
--    - Pode ter cor e ícone para identificação visual
-- =============================================================================
CREATE TABLE IF NOT EXISTS `projetos` (
  `id`                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `usuario_id`          INT UNSIGNED    NOT NULL                        COMMENT 'Dono do projeto',
  `nome`                VARCHAR(150)    NOT NULL,
  `descricao`           TEXT            NULL,
  `cor`                 CHAR(7)         NOT NULL DEFAULT '#1976D2',
  `icone`               VARCHAR(50)     NULL,
  `status`              ENUM('rascunho','ativo','pausado','concluido','cancelado')
                                        NOT NULL DEFAULT 'rascunho',
  `prioridade`          ENUM('baixa','media','alta','critica')
                                        NOT NULL DEFAULT 'media',
  `data_inicio`         DATE            NULL,
  `data_fim_prevista`   DATE            NULL,
  `data_fim_real`       DATE            NULL,
  `progresso`           TINYINT UNSIGNED NOT NULL DEFAULT 0             COMMENT '0-100 percentual calculado',
  `categoria_id`        INT UNSIGNED    NULL,
  `criado_em`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `atualizado_em`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_usuario` (`usuario_id`),
  INDEX `idx_status` (`status`),
  INDEX `idx_categoria` (`categoria_id`),
  CONSTRAINT `fk_proj_usuario`
    FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_proj_categoria`
    FOREIGN KEY (`categoria_id`) REFERENCES `categorias` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `chk_datas_projeto`
    CHECK (`data_fim_prevista` IS NULL OR `data_inicio` IS NULL OR `data_fim_prevista` >= `data_inicio`),
  CONSTRAINT `chk_progresso`
    CHECK (`progresso` BETWEEN 0 AND 100)
) ENGINE=InnoDB COMMENT='Projetos que agrupam tarefas';


-- =============================================================================
-- 5. TABELA: membros_projeto
--    Regras de negócio:
--    - Um projeto pode ter múltiplos membros
--    - Papéis: visualizador, colaborador, editor, admin
--    - O dono do projeto sempre tem papel admin (garantido por trigger)
--    - Não pode duplicar membro no mesmo projeto
-- =============================================================================
CREATE TABLE IF NOT EXISTS `membros_projeto` (
  `id`                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `projeto_id`          INT UNSIGNED    NOT NULL,
  `usuario_id`          INT UNSIGNED    NOT NULL,
  `papel`               ENUM('visualizador','colaborador','editor','admin')
                                        NOT NULL DEFAULT 'colaborador',
  `convidado_por`       INT UNSIGNED    NULL,
  `aceito_em`           DATETIME        NULL                            COMMENT 'NULL = convite pendente',
  `criado_em`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_membro_projeto` (`projeto_id`, `usuario_id`),
  INDEX `idx_usuario` (`usuario_id`),
  CONSTRAINT `fk_mp_projeto`
    FOREIGN KEY (`projeto_id`) REFERENCES `projetos` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_mp_usuario`
    FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_mp_convidado_por`
    FOREIGN KEY (`convidado_por`) REFERENCES `usuarios` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Membros de cada projeto com seus papéis';


-- =============================================================================
-- 6. TABELA: tarefas
--    Regras de negócio:
--    - Status: pendente, em_andamento, em_revisao, concluida, cancelada
--    - Prioridade: baixa, media, alta, critica
--    - Uma tarefa pode ter tarefa pai (subtarefa)
--    - Prazo de conclusão (deadline)
--    - Uma tarefa não pode ser pai de si mesma
--    - Recorrência: diaria, semanal, mensal, anual
--    - Estimativa de horas vs horas reais trabalhadas
--    - Pontuação (story points) para metodologias ágeis
-- =============================================================================
CREATE TABLE IF NOT EXISTS `tarefas` (
  `id`                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `projeto_id`          INT UNSIGNED    NULL                            COMMENT 'NULL = tarefa pessoal sem projeto',
  `tarefa_pai_id`       INT UNSIGNED    NULL                            COMMENT 'Para subtarefas',
  `criado_por`          INT UNSIGNED    NOT NULL,
  `responsavel_id`      INT UNSIGNED    NULL                            COMMENT 'Usuário principal responsável',
  `categoria_id`        INT UNSIGNED    NULL,
  `titulo`              VARCHAR(250)    NOT NULL,
  `descricao`           TEXT            NULL,
  `status`              ENUM('pendente','em_andamento','em_revisao','concluida','cancelada')
                                        NOT NULL DEFAULT 'pendente',
  `prioridade`          ENUM('baixa','media','alta','critica')
                                        NOT NULL DEFAULT 'media',
  `data_inicio`         DATETIME        NULL,
  `data_prazo`          DATETIME        NULL                            COMMENT 'Deadline',
  `data_conclusao`      DATETIME        NULL                            COMMENT 'Quando foi realmente concluída',
  `horas_estimadas`     DECIMAL(6,2)    NULL                            COMMENT 'Story points / estimativa',
  `horas_trabalhadas`   DECIMAL(6,2)    NOT NULL DEFAULT 0.00,
  `pontuacao`           SMALLINT UNSIGNED NULL                          COMMENT 'Story points ágil',
  `ordem`               INT UNSIGNED    NOT NULL DEFAULT 0              COMMENT 'Posição no kanban/lista',
  `recorrente`          BOOLEAN         NOT NULL DEFAULT FALSE,
  `tipo_recorrencia`    ENUM('diaria','semanal','quinzenal','mensal','anual')
                                        NULL,
  `proxima_recorrencia` DATE            NULL,
  `criado_em`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `atualizado_em`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_projeto` (`projeto_id`),
  INDEX `idx_responsavel` (`responsavel_id`),
  INDEX `idx_status` (`status`),
  INDEX `idx_prioridade` (`prioridade`),
  INDEX `idx_prazo` (`data_prazo`),
  INDEX `idx_pai` (`tarefa_pai_id`),
  INDEX `idx_criado_por` (`criado_por`),
  CONSTRAINT `fk_tar_projeto`
    FOREIGN KEY (`projeto_id`) REFERENCES `projetos` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_tar_pai`
    FOREIGN KEY (`tarefa_pai_id`) REFERENCES `tarefas` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_tar_criado`
    FOREIGN KEY (`criado_por`) REFERENCES `usuarios` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_tar_responsavel`
    FOREIGN KEY (`responsavel_id`) REFERENCES `usuarios` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_tar_categoria`
    FOREIGN KEY (`categoria_id`) REFERENCES `categorias` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `chk_prazo_tarefa`
    CHECK (`data_prazo` IS NULL OR `data_inicio` IS NULL OR `data_prazo` >= `data_inicio`),
  CONSTRAINT `chk_nao_pai_proprio`
    CHECK (`tarefa_pai_id` IS NULL OR `tarefa_pai_id` <> `id`),
  CONSTRAINT `chk_horas`
    CHECK (`horas_trabalhadas` >= 0 AND (`horas_estimadas` IS NULL OR `horas_estimadas` >= 0)),
  CONSTRAINT `chk_recorrencia`
    CHECK (`recorrente` = FALSE OR `tipo_recorrencia` IS NOT NULL)
) ENGINE=InnoDB COMMENT='Tarefas principais e subtarefas';


-- =============================================================================
-- 7. TABELA: tarefa_responsaveis (múltiplos responsáveis)
--    Regras de negócio:
--    - Uma tarefa pode ter múltiplos responsáveis além do principal
--    - Não duplicar o mesmo usuário na mesma tarefa
-- =============================================================================
CREATE TABLE IF NOT EXISTS `tarefa_responsaveis` (
  `tarefa_id`           INT UNSIGNED    NOT NULL,
  `usuario_id`          INT UNSIGNED    NOT NULL,
  `atribuido_em`        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `atribuido_por`       INT UNSIGNED    NULL,
  PRIMARY KEY (`tarefa_id`, `usuario_id`),
  CONSTRAINT `fk_tr_tarefa`
    FOREIGN KEY (`tarefa_id`) REFERENCES `tarefas` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_tr_usuario`
    FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_tr_atribuido`
    FOREIGN KEY (`atribuido_por`) REFERENCES `usuarios` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Múltiplos responsáveis por tarefa';


-- =============================================================================
-- 8. TABELA: tarefa_etiquetas (relação N:N)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `tarefa_etiquetas` (
  `tarefa_id`           INT UNSIGNED    NOT NULL,
  `etiqueta_id`         INT UNSIGNED    NOT NULL,
  PRIMARY KEY (`tarefa_id`, `etiqueta_id`),
  CONSTRAINT `fk_te_tarefa`
    FOREIGN KEY (`tarefa_id`) REFERENCES `tarefas` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_te_etiqueta`
    FOREIGN KEY (`etiqueta_id`) REFERENCES `etiquetas` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Etiquetas vinculadas às tarefas';


-- =============================================================================
-- 9. TABELA: checklists
--    Regras de negócio:
--    - Uma tarefa pode ter múltiplos checklists
--    - Cada checklist tem itens marcáveis
-- =============================================================================
CREATE TABLE IF NOT EXISTS `checklists` (
  `id`                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `tarefa_id`           INT UNSIGNED    NOT NULL,
  `titulo`              VARCHAR(150)    NOT NULL,
  `ordem`               TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `criado_em`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_tarefa` (`tarefa_id`),
  CONSTRAINT `fk_chk_tarefa`
    FOREIGN KEY (`tarefa_id`) REFERENCES `tarefas` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Checklists vinculados às tarefas';


CREATE TABLE IF NOT EXISTS `checklist_itens` (
  `id`                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `checklist_id`        INT UNSIGNED    NOT NULL,
  `descricao`           VARCHAR(300)    NOT NULL,
  `concluido`           BOOLEAN         NOT NULL DEFAULT FALSE,
  `concluido_por`       INT UNSIGNED    NULL,
  `concluido_em`        DATETIME        NULL,
  `ordem`               SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  INDEX `idx_checklist` (`checklist_id`),
  CONSTRAINT `fk_ci_checklist`
    FOREIGN KEY (`checklist_id`) REFERENCES `checklists` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ci_usuario`
    FOREIGN KEY (`concluido_por`) REFERENCES `usuarios` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Itens de cada checklist';


-- =============================================================================
-- 10. TABELA: comentarios
--     Regras de negócio:
--     - Comentários podem ser editados (registro de edição mantido)
--     - Soft delete: comentários não são apagados fisicamente
--     - Suporte a @menções e markdown
-- =============================================================================
CREATE TABLE IF NOT EXISTS `comentarios` (
  `id`                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `tarefa_id`           INT UNSIGNED    NOT NULL,
  `usuario_id`          INT UNSIGNED    NOT NULL,
  `conteudo`            TEXT            NOT NULL,
  `editado`             BOOLEAN         NOT NULL DEFAULT FALSE,
  `editado_em`          DATETIME        NULL,
  `deletado`            BOOLEAN         NOT NULL DEFAULT FALSE          COMMENT 'Soft delete',
  `deletado_em`         DATETIME        NULL,
  `criado_em`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_tarefa` (`tarefa_id`),
  INDEX `idx_usuario` (`usuario_id`),
  CONSTRAINT `fk_com_tarefa`
    FOREIGN KEY (`tarefa_id`) REFERENCES `tarefas` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_com_usuario`
    FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Comentários nas tarefas';


-- =============================================================================
-- 11. TABELA: anexos
--     Regras de negócio:
--     - Limite de tamanho por arquivo controlado na aplicação
--     - Tipos permitidos registrados (MIME type)
--     - Soft delete mantém rastreabilidade
-- =============================================================================
CREATE TABLE IF NOT EXISTS `anexos` (
  `id`                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `tarefa_id`           INT UNSIGNED    NOT NULL,
  `usuario_id`          INT UNSIGNED    NOT NULL                        COMMENT 'Quem fez upload',
  `nome_original`       VARCHAR(255)    NOT NULL,
  `nome_storage`        VARCHAR(255)    NOT NULL                        COMMENT 'Nome no storage (UUID)',
  `mime_type`           VARCHAR(100)    NOT NULL,
  `tamanho_bytes`       BIGINT UNSIGNED NOT NULL,
  `url`                 VARCHAR(500)    NOT NULL,
  `deletado`            BOOLEAN         NOT NULL DEFAULT FALSE,
  `criado_em`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_tarefa` (`tarefa_id`),
  CONSTRAINT `fk_anx_tarefa`
    FOREIGN KEY (`tarefa_id`) REFERENCES `tarefas` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_anx_usuario`
    FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Arquivos anexados às tarefas';


-- =============================================================================
-- 12. TABELA: historico_tarefas (audit log)
--     Regras de negócio:
--     - Todo campo alterado gera registro imutável
--     - Controle de quem/quando/o quê mudou
-- =============================================================================
CREATE TABLE IF NOT EXISTS `historico_tarefas` (
  `id`                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tarefa_id`           INT UNSIGNED    NOT NULL,
  `usuario_id`          INT UNSIGNED    NULL                            COMMENT 'NULL = sistema automático',
  `acao`                VARCHAR(80)     NOT NULL                        COMMENT 'Ex: status_alterado, responsavel_mudado',
  `campo`               VARCHAR(80)     NULL,
  `valor_anterior`      TEXT            NULL,
  `valor_novo`          TEXT            NULL,
  `criado_em`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_tarefa` (`tarefa_id`),
  INDEX `idx_usuario` (`usuario_id`),
  INDEX `idx_criado` (`criado_em`),
  CONSTRAINT `fk_ht_tarefa`
    FOREIGN KEY (`tarefa_id`) REFERENCES `tarefas` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ht_usuario`
    FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Histórico imutável de alterações nas tarefas';


-- =============================================================================
-- 13. TABELA: notificacoes
--     Regras de negócio:
--     - Tipos: prazo_proximo, tarefa_atribuida, comentario, mencao, conclusao, lembrete
--     - Leitura/não leitura por usuário
--     - Expiração automática (TTL sugerido: 90 dias)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `notificacoes` (
  `id`                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `usuario_id`          INT UNSIGNED    NOT NULL                        COMMENT 'Destinatário',
  `tipo`                ENUM('prazo_proximo','tarefa_atribuida','comentario','mencao',
                             'conclusao','lembrete','convite_projeto','sistema')
                                        NOT NULL,
  `titulo`              VARCHAR(200)    NOT NULL,
  `mensagem`            TEXT            NULL,
  `referencia_tipo`     VARCHAR(50)     NULL                            COMMENT 'Ex: tarefa, projeto, comentario',
  `referencia_id`       INT UNSIGNED    NULL                            COMMENT 'ID do objeto referenciado',
  `lida`                BOOLEAN         NOT NULL DEFAULT FALSE,
  `lida_em`             DATETIME        NULL,
  `criado_em`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expira_em`           DATETIME        NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_usuario_lida` (`usuario_id`, `lida`),
  INDEX `idx_criado` (`criado_em`),
  CONSTRAINT `fk_not_usuario`
    FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Notificações dos usuários';


-- =============================================================================
-- 14. TABELA: lembretes
--     Regras de negócio:
--     - Um lembrete está ligado a uma tarefa
--     - Canal: email, push, sms
--     - Pode ser recorrente
--     - Não pode agendar lembrete no passado
-- =============================================================================
CREATE TABLE IF NOT EXISTS `lembretes` (
  `id`                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `tarefa_id`           INT UNSIGNED    NOT NULL,
  `usuario_id`          INT UNSIGNED    NOT NULL,
  `data_hora`           DATETIME        NOT NULL,
  `canal`               SET('email','push','sms')
                                        NOT NULL DEFAULT 'push',
  `mensagem`            VARCHAR(300)    NULL,
  `enviado`             BOOLEAN         NOT NULL DEFAULT FALSE,
  `enviado_em`          DATETIME        NULL,
  `criado_em`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_tarefa` (`tarefa_id`),
  INDEX `idx_enviado_data` (`enviado`, `data_hora`),
  CONSTRAINT `fk_lem_tarefa`
    FOREIGN KEY (`tarefa_id`) REFERENCES `tarefas` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_lem_usuario`
    FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Lembretes agendados para tarefas';


-- =============================================================================
-- 15. TABELA: dependencias_tarefa
--     Regras de negócio:
--     - Uma tarefa pode depender de outra (bloqueante/bloqueada)
--     - Não pode criar dependência circular (verificado por procedure)
--     - Tipos: bloqueia, relacionada, duplicata
-- =============================================================================
CREATE TABLE IF NOT EXISTS `dependencias_tarefa` (
  `id`                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `tarefa_id`           INT UNSIGNED    NOT NULL                        COMMENT 'Tarefa que depende',
  `depende_de_id`       INT UNSIGNED    NOT NULL                        COMMENT 'Tarefa bloqueante',
  `tipo`                ENUM('bloqueia','relacionada','duplicata')
                                        NOT NULL DEFAULT 'bloqueia',
  `criado_em`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_dependencia` (`tarefa_id`, `depende_de_id`),
  CONSTRAINT `fk_dep_tarefa`
    FOREIGN KEY (`tarefa_id`) REFERENCES `tarefas` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_dep_depende`
    FOREIGN KEY (`depende_de_id`) REFERENCES `tarefas` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `chk_nao_auto_dependencia`
    CHECK (`tarefa_id` <> `depende_de_id`)
) ENGINE=InnoDB COMMENT='Dependências entre tarefas';


-- =============================================================================
-- 16. TABELA: tempo_registrado (time tracking)
--     Regras de negócio:
--     - Controle de horas trabalhadas por usuário/tarefa
--     - Data/hora de início e fim obrigatórios
--     - Duração calculada automaticamente (minutos)
--     - Não pode ter intervalo sobrepostos para o mesmo usuário (verificado por trigger)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `tempo_registrado` (
  `id`                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tarefa_id`           INT UNSIGNED    NOT NULL,
  `usuario_id`          INT UNSIGNED    NOT NULL,
  `inicio`              DATETIME        NOT NULL,
  `fim`                 DATETIME        NOT NULL,
  `duracao_minutos`     INT UNSIGNED    NOT NULL                        COMMENT 'Calculado automaticamente',
  `descricao`           VARCHAR(300)    NULL,
  `criado_em`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_tarefa` (`tarefa_id`),
  INDEX `idx_usuario_data` (`usuario_id`, `inicio`),
  CONSTRAINT `fk_tr2_tarefa`
    FOREIGN KEY (`tarefa_id`) REFERENCES `tarefas` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_tr2_usuario`
    FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_fim_maior_inicio`
    CHECK (`fim` > `inicio`)
) ENGINE=InnoDB COMMENT='Registro de tempo trabalhado por tarefa';


-- =============================================================================
-- 17. TABELA: configuracoes_usuario
--     Regras de negócio:
--     - Preferências individuais (1 linha por usuário)
--     - Notificações por canal configuráveis
-- =============================================================================
CREATE TABLE IF NOT EXISTS `configuracoes_usuario` (
  `usuario_id`          INT UNSIGNED    NOT NULL,
  `notif_email`         BOOLEAN         NOT NULL DEFAULT TRUE,
  `notif_push`          BOOLEAN         NOT NULL DEFAULT TRUE,
  `notif_prazo`         BOOLEAN         NOT NULL DEFAULT TRUE,
  `notif_atribuicao`    BOOLEAN         NOT NULL DEFAULT TRUE,
  `notif_comentario`    BOOLEAN         NOT NULL DEFAULT TRUE,
  `notif_mencao`        BOOLEAN         NOT NULL DEFAULT TRUE,
  `vista_padrao`        ENUM('lista','kanban','calendario','gantt')
                                        NOT NULL DEFAULT 'lista',
  `tema`                ENUM('claro','escuro','sistema')
                                        NOT NULL DEFAULT 'sistema',
  `idioma`              CHAR(5)         NOT NULL DEFAULT 'pt-BR',
  `semana_comeca_em`    TINYINT UNSIGNED NOT NULL DEFAULT 0             COMMENT '0=Domingo, 1=Segunda',
  `formato_data`        VARCHAR(20)     NOT NULL DEFAULT 'DD/MM/YYYY',
  `atualizado_em`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`usuario_id`),
  CONSTRAINT `fk_cfg_usuario`
    FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `chk_semana`
    CHECK (`semana_comeca_em` IN (0,1))
) ENGINE=InnoDB COMMENT='Preferências e configurações por usuário';


-- =============================================================================
-- PROCEDURES E FUNÇÕES
-- =============================================================================

DELIMITER $$

-- ---------------------------------------------------------------------------
-- PROCEDURE: sp_concluir_tarefa
-- Regra: ao concluir, registra data_conclusao, atualiza horas, gera histórico
-- ---------------------------------------------------------------------------
CREATE PROCEDURE `sp_concluir_tarefa`(
  IN p_tarefa_id   INT UNSIGNED,
  IN p_usuario_id  INT UNSIGNED
)
BEGIN
  DECLARE v_status_atual VARCHAR(20);
  DECLARE v_bloqueantes  INT DEFAULT 0;

  -- Busca status atual
  SELECT status INTO v_status_atual FROM tarefas WHERE id = p_tarefa_id FOR UPDATE;

  -- Regra: só pode concluir se estiver em andamento ou revisão
  IF v_status_atual NOT IN ('em_andamento','em_revisao','pendente') THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Tarefa não pode ser concluída no status atual.';
  END IF;

  -- Regra: verifica se existe tarefa bloqueante ainda aberta
  SELECT COUNT(*) INTO v_bloqueantes
  FROM dependencias_tarefa dt
  JOIN tarefas t ON t.id = dt.depende_de_id
  WHERE dt.tarefa_id = p_tarefa_id
    AND dt.tipo = 'bloqueia'
    AND t.status NOT IN ('concluida','cancelada');

  IF v_bloqueantes > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Existem tarefas bloqueantes ainda não concluídas.';
  END IF;

  -- Atualiza a tarefa
  UPDATE tarefas
  SET status         = 'concluida',
      data_conclusao = NOW()
  WHERE id = p_tarefa_id;

  -- Registra no histórico
  INSERT INTO historico_tarefas (tarefa_id, usuario_id, acao, campo, valor_anterior, valor_novo)
  VALUES (p_tarefa_id, p_usuario_id, 'status_alterado', 'status', v_status_atual, 'concluida');
END$$


-- ---------------------------------------------------------------------------
-- PROCEDURE: sp_atribuir_responsavel
-- Regra: valida se usuário é membro do projeto antes de atribuir
-- ---------------------------------------------------------------------------
CREATE PROCEDURE `sp_atribuir_responsavel`(
  IN p_tarefa_id     INT UNSIGNED,
  IN p_responsavel   INT UNSIGNED,
  IN p_atribuido_por INT UNSIGNED
)
BEGIN
  DECLARE v_projeto_id INT UNSIGNED;
  DECLARE v_membro     INT DEFAULT 0;

  SELECT projeto_id INTO v_projeto_id FROM tarefas WHERE id = p_tarefa_id;

  -- Se tarefa tem projeto, responsável precisa ser membro
  IF v_projeto_id IS NOT NULL THEN
    SELECT COUNT(*) INTO v_membro
    FROM membros_projeto
    WHERE projeto_id = v_projeto_id AND usuario_id = p_responsavel;

    IF v_membro = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Usuário não é membro do projeto desta tarefa.';
    END IF;
  END IF;

  -- Atualiza responsável principal
  UPDATE tarefas SET responsavel_id = p_responsavel WHERE id = p_tarefa_id;

  -- Insere em tarefa_responsaveis se não existir
  INSERT IGNORE INTO tarefa_responsaveis (tarefa_id, usuario_id, atribuido_por)
  VALUES (p_tarefa_id, p_responsavel, p_atribuido_por);

  -- Gera notificação
  INSERT INTO notificacoes (usuario_id, tipo, titulo, referencia_tipo, referencia_id)
  VALUES (p_responsavel, 'tarefa_atribuida', 'Você foi atribuído a uma tarefa', 'tarefa', p_tarefa_id);

  -- Histórico
  INSERT INTO historico_tarefas (tarefa_id, usuario_id, acao, campo, valor_novo)
  VALUES (p_tarefa_id, p_atribuido_por, 'responsavel_atribuido', 'responsavel_id', p_responsavel);
END$$


-- ---------------------------------------------------------------------------
-- FUNCTION: fn_progresso_projeto
-- Calcula o progresso do projeto com base nas tarefas concluídas
-- ---------------------------------------------------------------------------
CREATE FUNCTION `fn_progresso_projeto`(p_projeto_id INT UNSIGNED)
RETURNS TINYINT UNSIGNED
READS SQL DATA
DETERMINISTIC
BEGIN
  DECLARE v_total     INT DEFAULT 0;
  DECLARE v_concluidas INT DEFAULT 0;

  SELECT COUNT(*), SUM(IF(status = 'concluida', 1, 0))
  INTO v_total, v_concluidas
  FROM tarefas
  WHERE projeto_id = p_projeto_id AND tarefa_pai_id IS NULL; -- Só tarefas raiz

  IF v_total = 0 THEN RETURN 0; END IF;
  RETURN FLOOR((v_concluidas / v_total) * 100);
END$$


-- ---------------------------------------------------------------------------
-- FUNCTION: fn_calcular_duracao_minutos
-- Calcula duração em minutos entre duas datas
-- ---------------------------------------------------------------------------
CREATE FUNCTION `fn_calcular_duracao_minutos`(p_inicio DATETIME, p_fim DATETIME)
RETURNS INT UNSIGNED
DETERMINISTIC
BEGIN
  RETURN TIMESTAMPDIFF(MINUTE, p_inicio, p_fim);
END$$


DELIMITER ;


-- =============================================================================
-- TRIGGERS
-- =============================================================================

DELIMITER $$

-- ---------------------------------------------------------------------------
-- TRIGGER: trg_tempo_calcular_duracao
-- Calcula automaticamente a duração ao inserir registro de tempo
-- ---------------------------------------------------------------------------
CREATE TRIGGER `trg_tempo_calcular_duracao`
BEFORE INSERT ON `tempo_registrado`
FOR EACH ROW
BEGIN
  SET NEW.duracao_minutos = TIMESTAMPDIFF(MINUTE, NEW.inicio, NEW.fim);
  IF NEW.duracao_minutos <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fim deve ser maior que início no registro de tempo.';
  END IF;
END$$


-- ---------------------------------------------------------------------------
-- TRIGGER: trg_tempo_atualizar_horas_tarefa
-- Ao inserir tempo, recalcula horas_trabalhadas na tarefa
-- ---------------------------------------------------------------------------
CREATE TRIGGER `trg_tempo_atualizar_horas_tarefa`
AFTER INSERT ON `tempo_registrado`
FOR EACH ROW
BEGIN
  UPDATE tarefas
  SET horas_trabalhadas = (
    SELECT COALESCE(SUM(duracao_minutos), 0) / 60.0
    FROM tempo_registrado
    WHERE tarefa_id = NEW.tarefa_id
  )
  WHERE id = NEW.tarefa_id;
END$$


-- ---------------------------------------------------------------------------
-- TRIGGER: trg_tarefa_historico_status
-- Registra no histórico toda mudança de status
-- ---------------------------------------------------------------------------
CREATE TRIGGER `trg_tarefa_historico_status`
AFTER UPDATE ON `tarefas`
FOR EACH ROW
BEGIN
  IF OLD.status <> NEW.status THEN
    INSERT INTO historico_tarefas (tarefa_id, usuario_id, acao, campo, valor_anterior, valor_novo)
    VALUES (NEW.id, NEW.responsavel_id, 'status_alterado', 'status', OLD.status, NEW.status);
  END IF;

  IF OLD.prioridade <> NEW.prioridade THEN
    INSERT INTO historico_tarefas (tarefa_id, usuario_id, acao, campo, valor_anterior, valor_novo)
    VALUES (NEW.id, NEW.responsavel_id, 'prioridade_alterada', 'prioridade', OLD.prioridade, NEW.prioridade);
  END IF;

  IF (OLD.data_prazo IS NULL AND NEW.data_prazo IS NOT NULL)
     OR (OLD.data_prazo IS NOT NULL AND NEW.data_prazo IS NULL)
     OR (OLD.data_prazo <> NEW.data_prazo) THEN
    INSERT INTO historico_tarefas (tarefa_id, usuario_id, acao, campo, valor_anterior, valor_novo)
    VALUES (NEW.id, NEW.responsavel_id, 'prazo_alterado', 'data_prazo',
            OLD.data_prazo, NEW.data_prazo);
  END IF;
END$$


-- ---------------------------------------------------------------------------
-- TRIGGER: trg_progresso_projeto
-- Atualiza o progresso do projeto quando uma tarefa muda de status
-- ---------------------------------------------------------------------------
CREATE TRIGGER `trg_progresso_projeto`
AFTER UPDATE ON `tarefas`
FOR EACH ROW
BEGIN
  IF OLD.status <> NEW.status AND NEW.projeto_id IS NOT NULL THEN
    UPDATE projetos
    SET progresso = fn_progresso_projeto(NEW.projeto_id)
    WHERE id = NEW.projeto_id;
  END IF;
END$$


-- ---------------------------------------------------------------------------
-- TRIGGER: trg_projeto_conclusao_automatica
-- Se progresso chegar a 100, marca projeto como concluído
-- ---------------------------------------------------------------------------
CREATE TRIGGER `trg_projeto_conclusao_automatica`
AFTER UPDATE ON `projetos`
FOR EACH ROW
BEGIN
  IF OLD.progresso <> NEW.progresso AND NEW.progresso = 100
     AND NEW.status NOT IN ('concluido','cancelado') THEN
    UPDATE projetos
    SET status       = 'concluido',
        data_fim_real = CURDATE()
    WHERE id = NEW.id;
  END IF;
END$$


-- ---------------------------------------------------------------------------
-- TRIGGER: trg_criar_configuracoes_usuario
-- Ao criar usuário, cria automaticamente suas configurações padrão
-- ---------------------------------------------------------------------------
CREATE TRIGGER `trg_criar_configuracoes_usuario`
AFTER INSERT ON `usuarios`
FOR EACH ROW
BEGIN
  INSERT INTO configuracoes_usuario (usuario_id) VALUES (NEW.id);
END$$


-- ---------------------------------------------------------------------------
-- TRIGGER: trg_checklist_concluido_em
-- Registra quem e quando um item de checklist foi concluído
-- ---------------------------------------------------------------------------
CREATE TRIGGER `trg_checklist_concluido_em`
BEFORE UPDATE ON `checklist_itens`
FOR EACH ROW
BEGIN
  IF OLD.concluido = FALSE AND NEW.concluido = TRUE THEN
    SET NEW.concluido_em = NOW();
  END IF;
  IF NEW.concluido = FALSE THEN
    SET NEW.concluido_em = NULL;
    SET NEW.concluido_por = NULL;
  END IF;
END$$


-- ---------------------------------------------------------------------------
-- TRIGGER: trg_comentario_editado
-- Marca comentário como editado quando o conteúdo muda
-- ---------------------------------------------------------------------------
CREATE TRIGGER `trg_comentario_editado`
BEFORE UPDATE ON `comentarios`
FOR EACH ROW
BEGIN
  IF OLD.conteudo <> NEW.conteudo THEN
    SET NEW.editado    = TRUE;
    SET NEW.editado_em = NOW();
  END IF;
END$$


DELIMITER ;


-- =============================================================================
-- VIEWS ÚTEIS
-- =============================================================================

-- View: Tarefas com prazo vencido e não concluídas
CREATE OR REPLACE VIEW `vw_tarefas_atrasadas` AS
SELECT
  t.id,
  t.titulo,
  t.status,
  t.prioridade,
  t.data_prazo,
  TIMESTAMPDIFF(HOUR, t.data_prazo, NOW()) AS horas_atraso,
  u.nome AS responsavel,
  p.nome AS projeto
FROM tarefas t
LEFT JOIN usuarios u  ON u.id = t.responsavel_id
LEFT JOIN projetos p  ON p.id = t.projeto_id
WHERE t.data_prazo < NOW()
  AND t.status NOT IN ('concluida','cancelada');


-- View: Resumo de projetos com progresso e contagem de tarefas
CREATE OR REPLACE VIEW `vw_resumo_projetos` AS
SELECT
  p.id,
  p.nome,
  p.status,
  p.prioridade,
  p.progresso,
  p.data_inicio,
  p.data_fim_prevista,
  u.nome AS dono,
  COUNT(t.id)                                                 AS total_tarefas,
  SUM(t.status = 'concluida')                                 AS tarefas_concluidas,
  SUM(t.status = 'em_andamento')                              AS tarefas_em_andamento,
  SUM(t.status IN ('pendente','em_andamento','em_revisao')
      AND t.data_prazo < NOW())                               AS tarefas_atrasadas
FROM projetos p
JOIN usuarios u ON u.id = p.usuario_id
LEFT JOIN tarefas t ON t.projeto_id = p.id
GROUP BY p.id;


-- View: Minhas tarefas (dashboard pessoal) - parametrizar via WHERE
CREATE OR REPLACE VIEW `vw_minhas_tarefas` AS
SELECT
  t.id,
  t.titulo,
  t.status,
  t.prioridade,
  t.data_prazo,
  t.horas_estimadas,
  t.horas_trabalhadas,
  c.nome   AS categoria,
  p.nome   AS projeto,
  (t.data_prazo IS NOT NULL AND t.data_prazo < NOW()
   AND t.status NOT IN ('concluida','cancelada')) AS atrasada
FROM tarefas t
LEFT JOIN categorias c ON c.id = t.categoria_id
LEFT JOIN projetos   p ON p.id = t.projeto_id
WHERE t.status NOT IN ('cancelada');


-- =============================================================================
-- DADOS INICIAIS (SEED)
-- =============================================================================

-- Categorias globais padrão
INSERT INTO `categorias` (`nome`, `descricao`, `cor`, `icone`, `usuario_id`) VALUES
  ('Trabalho',    'Tarefas profissionais',          '#1565C0', 'fa-briefcase',    NULL),
  ('Pessoal',     'Tarefas pessoais e do dia a dia','#2E7D32', 'fa-user',         NULL),
  ('Estudos',     'Cursos, leituras e aprendizado', '#6A1B9A', 'fa-graduation-cap', NULL),
  ('Saúde',       'Exercícios, médico, bem-estar',  '#C62828', 'fa-heart',        NULL),
  ('Financeiro',  'Contas, investimentos e gastos', '#F57F17', 'fa-dollar-sign',  NULL),
  ('Casa',        'Compras e manutenção da casa',   '#4E342E', 'fa-home',         NULL);

-- Usuário administrador padrão (senha: 'Admin@2024' - já hasheada)
INSERT INTO `usuarios` (`nome`, `email`, `senha_hash`, `perfil`, `status`) VALUES
  ('Administrador', 'admin@taskorganizer.com',
   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TiGniRKp8xzMj8VHXkMNVvByX7De',
   'admin', 'ativo');


-- =============================================================================
-- RESTAURA CONFIGURAÇÕES
-- =============================================================================
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
SET SQL_MODE=@OLD_SQL_MODE;

-- =============================================================================
-- FIM DO SCRIPT
-- =============================================================================
