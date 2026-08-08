-- LAND OF THE BLOODY RP — v0.4 production expansion
-- Import after sql/lotb.sql

CREATE TABLE IF NOT EXISTS `lotb_wills` (
  `will_key` VARCHAR(96) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `executor_citizenid` VARCHAR(64) NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'draft',
  `instructions` VARCHAR(1500) NOT NULL DEFAULT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`will_key`),
  KEY `idx_lotb_will_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_will_assets` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `will_key` VARCHAR(96) NOT NULL,
  `asset_type` VARCHAR(48) NOT NULL,
  `asset_ref` VARCHAR(128) NOT NULL,
  `beneficiary_citizenid` VARCHAR(64) NOT NULL,
  `note` VARCHAR(500) NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'listed',
  PRIMARY KEY (`id`),
  KEY `idx_lotb_will_asset_will` (`will_key`),
  CONSTRAINT `fk_lotb_will_asset` FOREIGN KEY (`will_key`) REFERENCES `lotb_wills` (`will_key`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_properties` (
  `property_key` VARCHAR(96) NOT NULL,
  `label` VARCHAR(140) NOT NULL,
  `district` VARCHAR(64) NOT NULL,
  `property_type` VARCHAR(48) NOT NULL DEFAULT 'residential',
  `owner_citizenid` VARCHAR(64) NULL,
  `purchase_price` BIGINT NOT NULL DEFAULT 0,
  `rent_price` INT NOT NULL DEFAULT 0,
  `maintenance` INT NOT NULL DEFAULT 100,
  `security` INT NOT NULL DEFAULT 0,
  `coords_json` LONGTEXT NOT NULL,
  `state_json` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`property_key`),
  KEY `idx_lotb_property_owner` (`owner_citizenid`),
  KEY `idx_lotb_property_district` (`district`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_property_access` (
  `property_key` VARCHAR(96) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `access_level` VARCHAR(32) NOT NULL DEFAULT 'guest',
  `granted_by` VARCHAR(64) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`property_key`,`citizenid`),
  CONSTRAINT `fk_lotb_property_access` FOREIGN KEY (`property_key`) REFERENCES `lotb_properties` (`property_key`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_dealership_inventory` (
  `stock_key` VARCHAR(96) NOT NULL,
  `dealership_key` VARCHAR(96) NOT NULL,
  `model` VARCHAR(96) NOT NULL,
  `label` VARCHAR(140) NOT NULL,
  `price` INT NOT NULL,
  `quantity` INT NOT NULL DEFAULT 0,
  `garage` VARCHAR(96) NOT NULL DEFAULT 'pillboxgarage',
  `metadata_json` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`stock_key`),
  KEY `idx_lotb_dealer` (`dealership_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_vehicle_sales` (
  `sale_key` VARCHAR(96) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `vehicle_id` INT NULL,
  `stock_key` VARCHAR(96) NOT NULL,
  `price` INT NOT NULL,
  `salesperson_citizenid` VARCHAR(64) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`sale_key`),
  KEY `idx_lotb_vehicle_sale_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_mechanic_orders` (
  `order_key` VARCHAR(96) NOT NULL,
  `vehicle_id` INT NOT NULL,
  `customer_citizenid` VARCHAR(64) NOT NULL,
  `mechanic_citizenid` VARCHAR(64) NULL,
  `shop_key` VARCHAR(96) NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'open',
  `description` VARCHAR(800) NOT NULL,
  `quoted_price` INT NOT NULL DEFAULT 0,
  `paid_amount` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `completed_at` DATETIME NULL,
  PRIMARY KEY (`order_key`),
  KEY `idx_lotb_mech_vehicle` (`vehicle_id`),
  KEY `idx_lotb_mech_customer` (`customer_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_vehicle_service_history` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `vehicle_id` INT NOT NULL,
  `order_key` VARCHAR(96) NULL,
  `service_type` VARCHAR(64) NOT NULL,
  `summary` VARCHAR(500) NOT NULL,
  `mileage` INT NULL,
  `mechanic_citizenid` VARCHAR(64) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_lotb_service_vehicle` (`vehicle_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_underworld_profiles` (
  `citizenid` VARCHAR(64) NOT NULL,
  `network` INT NOT NULL DEFAULT 0,
  `discipline` INT NOT NULL DEFAULT 0,
  `heat` INT NOT NULL DEFAULT 0,
  `intel` INT NOT NULL DEFAULT 0,
  `state_json` LONGTEXT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_underworld_unlocks` (
  `citizenid` VARCHAR(64) NOT NULL,
  `unlock_key` VARCHAR(96) NOT NULL,
  `source` VARCHAR(96) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`,`unlock_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_crime_jobs` (
  `job_key` VARCHAR(96) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `kind` VARCHAR(64) NOT NULL,
  `district` VARCHAR(64) NOT NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'offered',
  `difficulty` INT NOT NULL DEFAULT 1,
  `payload_json` LONGTEXT NULL,
  `expires_at` DATETIME NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`job_key`),
  KEY `idx_lotb_crime_job_citizen` (`citizenid`),
  KEY `idx_lotb_crime_job_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_crafting_recipes` (
  `recipe_key` VARCHAR(96) NOT NULL,
  `label` VARCHAR(140) NOT NULL,
  `category` VARCHAR(64) NOT NULL,
  `requirements_json` LONGTEXT NOT NULL,
  `outputs_json` LONGTEXT NOT NULL,
  `minimum_network` INT NOT NULL DEFAULT 0,
  `minimum_discipline` INT NOT NULL DEFAULT 0,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`recipe_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lotb_bank_ledger` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `account_type` VARCHAR(32) NOT NULL,
  `account_ref` VARCHAR(96) NOT NULL,
  `direction` VARCHAR(8) NOT NULL,
  `amount` BIGINT NOT NULL,
  `reason` VARCHAR(180) NULL,
  `actor_citizenid` VARCHAR(64) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_lotb_ledger_account` (`account_type`,`account_ref`),
  KEY `idx_lotb_ledger_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `lotb_crafting_recipes`
(`recipe_key`,`label`,`category`,`requirements_json`,`outputs_json`,`minimum_network`,`minimum_discipline`) VALUES
('repair_kit_basic','Basic Repair Kit','mechanic','{"metals":4,"rubber":2}','{"repairkit":1}',0,0),
('lock_bypass_basic','Basic Lock Bypass','underworld','{"metals":2,"electronics":2}','{"lockpick":1}',10,10);
