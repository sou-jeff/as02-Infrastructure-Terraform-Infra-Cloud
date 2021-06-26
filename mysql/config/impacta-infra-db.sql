CREATE USER IF NOT EXISTS 'impacta-infra'@'%' IDENTIFIED BY 'impacta-infra';

CREATE DATABASE IF NOT EXISTS impacta-infra;

ALTER DATABASE impacta-infra
  DEFAULT CHARACTER SET utf8
  DEFAULT COLLATE utf8_general_ci;

GRANT ALL PRIVILEGES ON impacta-infra.* TO 'impacta-infra'@'%' IDENTIFIED BY 'impacta-infra';
