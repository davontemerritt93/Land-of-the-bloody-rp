-- LAND OF THE BLOODY RP — v0.5 city services expansion
-- Import after lotb_v04.sql

CREATE TABLE IF NOT EXISTS `lotb_insurance_policies` (
  `policy_key` VARCHAR(96) NOT NULL,
  `holder_citizenid` VARCHAR(64) NOT NULL,
  `asset_type` VARCHAR(32) NOT NULL,
  `asset_ref` VARCHAR(128) NOT NULL,
  `coverage_limit` INT NOT NULL DEFAULT 0,
  `deductible` INT NOT NULL DEFAULT 0,
  `premium` INT NOT NULL DEFAULT 0,
  `status` VARCHAR(32) NOT NULL DEFAULT 'active',
  `next_due_at` DATETIME NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`policy_key`),
  KEY `idx_lotb_policy_holder` (`holder_citizenid`),
  KEY `idx_lotb_policy_asset` (`asset_type`,`asset_ref`),
  KEY `idx_lotb_policy_due` (`next_due_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_insurance_claims` (
  `claim_key` VARCHAR(96) NOT NULL,
  `policy_key` VARCHAR(96) NOT NULL,
  `claimant_citizenid` VARCHAR(64) NOT NULL,
  `incident_type` VARCHAR(64) NOT NULL,
  `description` VARCHAR(1000) NOT NULL,
  `requested_amount` INT NOT NULL DEFAULT 0,
  `approved_amount` INT NOT NULL DEFAULT 0,
  `evidence_json` LONGTEXT NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'submitted',
  `reviewer_citizenid` VARCHAR(64) NULL,
  `review_note` VARCHAR(800) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reviewed_at` DATETIME NULL,
  PRIMARY KEY (`claim_key`),
  KEY `idx_lotb_claim_policy` (`policy_key`),
  KEY `idx_lotb_claim_claimant` (`claimant_citizenid`),
  KEY `idx_lotb_claim_status` (`status`),
  CONSTRAINT `fk_lotb_claim_policy` FOREIGN KEY (`policy_key`) REFERENCES `lotb_insurance_policies` (`policy_key`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_city_services_feed` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `feed_key` VARCHAR(96) NOT NULL,
  `category` VARCHAR(48) NOT NULL,
  `title` VARCHAR(140) NOT NULL,
  `body` VARCHAR(600) NOT NULL,
  `district` VARCHAR(64) NULL,
  `priority` INT NOT NULL DEFAULT 0,
  `expires_at` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_lotb_feed_key` (`feed_key`),
  KEY `idx_lotb_feed_created` (`created_at`),
  KEY `idx_lotb_feed_expiry` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_case_rulings` (
  `ruling_key` VARCHAR(96) NOT NULL,
  `case_key` VARCHAR(96) NOT NULL,
  `judge_citizenid` VARCHAR(64) NOT NULL,
  `title` VARCHAR(180) NOT NULL,
  `holding` VARCHAR(1200) NOT NULL,
  `rationale` VARCHAR(2000) NOT NULL,
  `tags_json` LONGTEXT NULL,
  `citations_json` LONGTEXT NULL,
  `precedential` TINYINT(1) NOT NULL DEFAULT 1,
  `status` VARCHAR(32) NOT NULL DEFAULT 'published',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`ruling_key`),
  KEY `idx_lotb_ruling_case` (`case_key`),
  KEY `idx_lotb_ruling_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_media_articles` (
  `article_key` VARCHAR(96) NOT NULL,
  `author_citizenid` VARCHAR(64) NOT NULL,
  `outlet` VARCHAR(96) NOT NULL,
  `headline` VARCHAR(180) NOT NULL,
  `body` TEXT NOT NULL,
  `category` VARCHAR(48) NOT NULL DEFAULT 'local',
  `district` VARCHAR(64) NULL,
  `sources_json` LONGTEXT NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'draft',
  `correction_note` VARCHAR(800) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `published_at` DATETIME NULL,
  PRIMARY KEY (`article_key`),
  KEY `idx_lotb_media_author` (`author_citizenid`),
  KEY `idx_lotb_media_status` (`status`),
  KEY `idx_lotb_media_published` (`published_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_sentences` (
  `sentence_key` VARCHAR(96) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `case_key` VARCHAR(96) NULL,
  `imposed_by_citizenid` VARCHAR(64) NOT NULL,
  `total_minutes` INT NOT NULL,
  `served_minutes` INT NOT NULL DEFAULT 0,
  `status` VARCHAR(32) NOT NULL DEFAULT 'active',
  `parole_after_minutes` INT NULL,
  `notes` VARCHAR(1200) NULL,
  `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `released_at` DATETIME NULL,
  PRIMARY KEY (`sentence_key`),
  KEY `idx_lotb_sentence_citizen` (`citizenid`),
  KEY `idx_lotb_sentence_status` (`status`),
  KEY `idx_lotb_sentence_case` (`case_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_inmate_profiles` (
  `citizenid` VARCHAR(64) NOT NULL,
  `conduct` INT NOT NULL DEFAULT 0,
  `program_credit` INT NOT NULL DEFAULT 0,
  `commissary_balance` INT NOT NULL DEFAULT 0,
  `housing_unit` VARCHAR(64) NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_corrections_events` (
  `event_key` VARCHAR(96) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `event_type` VARCHAR(64) NOT NULL,
  `summary` VARCHAR(800) NOT NULL,
  `conduct_delta` INT NOT NULL DEFAULT 0,
  `program_credit_delta` INT NOT NULL DEFAULT 0,
  `recorded_by_citizenid` VARCHAR(64) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`event_key`),
  KEY `idx_lotb_corrections_citizen` (`citizenid`),
  KEY `idx_lotb_corrections_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_visitation_requests` (
  `visit_key` VARCHAR(96) NOT NULL,
  `inmate_citizenid` VARCHAR(64) NOT NULL,
  `visitor_citizenid` VARCHAR(64) NOT NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'requested',
  `scheduled_at` DATETIME NULL,
  `note` VARCHAR(500) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`visit_key`),
  KEY `idx_lotb_visit_inmate` (`inmate_citizenid`),
  KEY `idx_lotb_visit_visitor` (`visitor_citizenid`),
  KEY `idx_lotb_visit_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
