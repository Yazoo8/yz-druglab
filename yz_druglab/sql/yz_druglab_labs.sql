CREATE TABLE IF NOT EXISTS `yz_druglab_labs` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `drug_type` VARCHAR(50) NOT NULL,
    `job_name` VARCHAR(50) NOT NULL,
    `world_x` FLOAT NOT NULL,
    `world_y` FLOAT NOT NULL,
    `world_z` FLOAT NOT NULL,
    `world_w` FLOAT NOT NULL DEFAULT 0,
    `code` VARCHAR(20) NOT NULL DEFAULT '1234',
    `price` INT UNSIGNED NOT NULL DEFAULT 0,
    `owner_identifier` VARCHAR(64) NULL DEFAULT NULL,
    `entrance_shell_model` VARCHAR(80) NULL DEFAULT NULL,
    `lab_shell_model` VARCHAR(80) NULL DEFAULT NULL,
    `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
