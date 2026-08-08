CREATE TABLE IF NOT EXISTS `lotb_audit_log` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `category` VARCHAR(64) NOT NULL,
  `actor_citizenid` VARCHAR(64) NULL,
  `actor_source` INT NOT NULL DEFAULT 0,
  `action` VARCHAR(96) NOT NULL,
  `target` VARCHAR(128) NULL,
  `payload_json` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_lotb_audit_category` (`category`),
  KEY `idx_lotb_audit_actor` (`actor_citizenid`),
  KEY `idx_lotb_audit_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_rumors` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `rumor_key` VARCHAR(96) NOT NULL,
  `origin_citizenid` VARCHAR(64) NULL,
  `district` VARCHAR(64) NULL,
  `subject` VARCHAR(120) NOT NULL,
  `body` VARCHAR(500) NOT NULL,
  `confidence` INT NOT NULL DEFAULT 50,
  `heat` INT NOT NULL DEFAULT 0,
  `audience_json` LONGTEXT NULL,
  `state_json` LONGTEXT NULL,
  `expires_at` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_lotb_rumor_key` (`rumor_key`),
  KEY `idx_lotb_rumor_district` (`district`),
  KEY `idx_lotb_rumor_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_character_memory` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(64) NOT NULL,
  `memory_type` VARCHAR(64) NOT NULL,
  `weight` INT NOT NULL DEFAULT 0,
  `context_json` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_lotb_memory_citizen` (`citizenid`),
  KEY `idx_lotb_memory_type` (`memory_type`),
  KEY `idx_lotb_memory_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_district_state` (
  `district` VARCHAR(64) NOT NULL,
  `trust` INT NOT NULL DEFAULT 0,
  `pressure` INT NOT NULL DEFAULT 0,
  `prosperity` INT NOT NULL DEFAULT 0,
  `instability` INT NOT NULL DEFAULT 0,
  `community_pride` INT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`district`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_witness_reports` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `report_key` VARCHAR(96) NOT NULL,
  `district` VARCHAR(64) NULL,
  `event_type` VARCHAR(64) NOT NULL,
  `description_json` LONGTEXT NOT NULL,
  `confidence` INT NOT NULL DEFAULT 50,
  `decay_rate` INT NOT NULL DEFAULT 2,
  `source_kind` VARCHAR(32) NOT NULL DEFAULT 'npc',
  `case_ref` VARCHAR(96) NULL,
  `expires_at` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_lotb_witness_report_key` (`report_key`),
  KEY `idx_lotb_witness_district` (`district`),
  KEY `idx_lotb_witness_case` (`case_ref`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_object_legacy` (
  `legacy_key` VARCHAR(96) NOT NULL,
  `object_type` VARCHAR(48) NOT NULL,
  `label` VARCHAR(128) NOT NULL,
  `owner_citizenid` VARCHAR(64) NULL,
  `metadata_json` LONGTEXT NULL,
  `fame` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`legacy_key`),
  KEY `idx_lotb_legacy_owner` (`owner_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_object_legacy_events` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `legacy_key` VARCHAR(96) NOT NULL,
  `event_type` VARCHAR(64) NOT NULL,
  `summary` VARCHAR(500) NOT NULL,
  `actor_citizenid` VARCHAR(64) NULL,
  `district` VARCHAR(64) NULL,
  `importance` INT NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_lotb_legacy_event_key` (`legacy_key`),
  CONSTRAINT `fk_lotb_legacy_event` FOREIGN KEY (`legacy_key`) REFERENCES `lotb_object_legacy` (`legacy_key`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_city_contacts` (
  `contact_key` VARCHAR(96) NOT NULL,
  `name` VARCHAR(120) NOT NULL,
  `district` VARCHAR(64) NULL,
  `role` VARCHAR(96) NOT NULL,
  `public_description` VARCHAR(500) NULL,
  `state_json` LONGTEXT NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`contact_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_character_contacts` (
  `citizenid` VARCHAR(64) NOT NULL,
  `contact_key` VARCHAR(96) NOT NULL,
  `trust` INT NOT NULL DEFAULT 0,
  `fear` INT NOT NULL DEFAULT 0,
  `debt` INT NOT NULL DEFAULT 0,
  `last_interaction` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`, `contact_key`),
  CONSTRAINT `fk_lotb_character_contact` FOREIGN KEY (`contact_key`) REFERENCES `lotb_city_contacts` (`contact_key`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_scene_threads` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `thread_key` VARCHAR(96) NOT NULL,
  `title` VARCHAR(160) NOT NULL,
  `category` VARCHAR(64) NOT NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'open',
  `owner_citizenid` VARCHAR(64) NULL,
  `participants_json` LONGTEXT NULL,
  `state_json` LONGTEXT NULL,
  `expires_at` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_lotb_thread_key` (`thread_key`),
  KEY `idx_lotb_thread_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_opportunities` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `opportunity_key` VARCHAR(96) NOT NULL,
  `district` VARCHAR(64) NOT NULL,
  `kind` VARCHAR(64) NOT NULL,
  `title` VARCHAR(140) NOT NULL,
  `body` VARCHAR(500) NOT NULL,
  `minimum_heat` INT NOT NULL DEFAULT 0,
  `maximum_pressure` INT NOT NULL DEFAULT 100,
  `state_json` LONGTEXT NULL,
  `expires_at` DATETIME NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_lotb_opportunity_key` (`opportunity_key`),
  KEY `idx_lotb_opportunity_district` (`district`),
  KEY `idx_lotb_opportunity_expiry` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_evidence` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `evidence_key` VARCHAR(96) NOT NULL,
  `evidence_type` VARCHAR(64) NOT NULL,
  `case_ref` VARCHAR(96) NULL,
  `created_by` VARCHAR(64) NULL,
  `origin_json` LONGTEXT NULL,
  `metadata_json` LONGTEXT NULL,
  `integrity` INT NOT NULL DEFAULT 100,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_lotb_evidence_key` (`evidence_key`),
  KEY `idx_lotb_evidence_case` (`case_ref`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_evidence_custody` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `evidence_key` VARCHAR(96) NOT NULL,
  `from_holder` VARCHAR(96) NULL,
  `to_holder` VARCHAR(96) NOT NULL,
  `reason` VARCHAR(160) NULL,
  `handled_by_citizenid` VARCHAR(64) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_lotb_custody_evidence` (`evidence_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_contracts` (
  `contract_key` VARCHAR(96) NOT NULL,
  `creator_citizenid` VARCHAR(64) NOT NULL,
  `counterparty_citizenid` VARCHAR(64) NOT NULL,
  `title` VARCHAR(140) NOT NULL,
  `terms` VARCHAR(1000) NOT NULL,
  `amount` INT NOT NULL DEFAULT 0,
  `escrow_amount` INT NOT NULL DEFAULT 0,
  `status` VARCHAR(32) NOT NULL DEFAULT 'pending',
  `accepted_at` DATETIME NULL,
  `completed_at` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`contract_key`),
  KEY `idx_lotb_contract_creator` (`creator_citizenid`),
  KEY `idx_lotb_contract_counterparty` (`counterparty_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_businesses` (
  `business_key` VARCHAR(96) NOT NULL,
  `name` VARCHAR(140) NOT NULL,
  `owner_citizenid` VARCHAR(64) NOT NULL,
  `district` VARCHAR(64) NOT NULL,
  `balance` BIGINT NOT NULL DEFAULT 0,
  `reputation` INT NOT NULL DEFAULT 0,
  `state_json` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`business_key`),
  KEY `idx_lotb_business_owner` (`owner_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_business_stock` (
  `business_key` VARCHAR(96) NOT NULL,
  `item_name` VARCHAR(96) NOT NULL,
  `quantity` INT NOT NULL DEFAULT 0,
  `unit_cost` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`business_key`, `item_name`),
  CONSTRAINT `fk_lotb_business_stock` FOREIGN KEY (`business_key`) REFERENCES `lotb_businesses` (`business_key`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_dispatch_calls` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `call_key` VARCHAR(96) NOT NULL,
  `service` VARCHAR(16) NOT NULL,
  `caller_citizenid` VARCHAR(64) NULL,
  `message` VARCHAR(500) NOT NULL,
  `coords_json` LONGTEXT NOT NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'open',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_lotb_dispatch_key` (`call_key`),
  KEY `idx_lotb_dispatch_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_justice_cases` (
  `case_key` VARCHAR(96) NOT NULL,
  `title` VARCHAR(160) NOT NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'open',
  `judge_citizenid` VARCHAR(64) NULL,
  `parties_json` LONGTEXT NULL,
  `summary` VARCHAR(1000) NULL,
  `precedent_json` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`case_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_warrants` (
  `warrant_key` VARCHAR(96) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `case_key` VARCHAR(96) NULL,
  `reason` VARCHAR(500) NOT NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'active',
  `issued_by` VARCHAR(64) NULL,
  `expires_at` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`warrant_key`),
  KEY `idx_lotb_warrant_citizen` (`citizenid`),
  KEY `idx_lotb_warrant_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_medical_records` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `record_key` VARCHAR(96) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `author_citizenid` VARCHAR(64) NULL,
  `record_type` VARCHAR(64) NOT NULL,
  `summary` VARCHAR(800) NOT NULL,
  `private_json` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_lotb_medical_record_key` (`record_key`),
  KEY `idx_lotb_medical_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_crews` (
  `crew_key` VARCHAR(96) NOT NULL,
  `name` VARCHAR(120) NOT NULL,
  `leader_citizenid` VARCHAR(64) NOT NULL,
  `heat` INT NOT NULL DEFAULT 0,
  `influence` INT NOT NULL DEFAULT 0,
  `state_json` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`crew_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_crew_members` (
  `crew_key` VARCHAR(96) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `rank_name` VARCHAR(64) NOT NULL DEFAULT 'member',
  `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`crew_key`, `citizenid`),
  CONSTRAINT `fk_lotb_crew_member` FOREIGN KEY (`crew_key`) REFERENCES `lotb_crews` (`crew_key`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `lotb_district_state` (`district`) VALUES
('south_ls'),('downtown'),('vespucci'),('vinewood'),('county'),('east_ls'),('airport');

INSERT IGNORE INTO `lotb_city_contacts` (`contact_key`,`name`,`district`,`role`,`public_description`) VALUES
('ray_cooper','Raymond "Ray" Cooper','south_ls','connector','A quiet neighborhood fixer who remembers favors and disrespect.'),
('mara_voss','Mara Voss','downtown','broker','A business broker with ties to legitimate and gray-market contracts.'),
('doc_ellis','Dr. Ellis Monroe','vespucci','medical_contact','A discreet medical professional known for keeping careful records.');
