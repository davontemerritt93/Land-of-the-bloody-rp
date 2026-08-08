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
