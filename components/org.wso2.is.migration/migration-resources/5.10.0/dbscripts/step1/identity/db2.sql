ALTER TABLE IDN_OAUTH2_ACCESS_TOKEN
	ADD COLUMN TOKEN_BINDING_REF VARCHAR(32) NOT NULL DEFAULT 'NONE'
	DROP CONSTRAINT CON_APP_KEY
	ADD CONSTRAINT CON_APP_KEY UNIQUE (CONSUMER_KEY_ID,AUTHZ_USER,TENANT_ID,USER_DOMAIN,USER_TYPE,TOKEN_SCOPE_HASH,TOKEN_STATE,TOKEN_STATE_ID,IDP_ID,TOKEN_BINDING_REF)
/

CALL SYSPROC.ADMIN_CMD('REORG TABLE IDN_OAUTH2_ACCESS_TOKEN')
/

CREATE OR REPLACE FUNCTION NEWUUID()
RETURNS CHAR(36)
BEGIN
    DECLARE @UUID CHAR(32);
    SET @UUID=LOWER(HEX(RAND()*255) || HEX(RAND()*255));
    RETURN LEFT(@UUID,8)||'-'||
           SUBSTR(@UUID,9,4)||'-'||
           SUBSTR(@UUID,13,4)||'-'||
           SUBSTR(@UUID,17,4)||'-'||
           RIGHT(@UUID,12);
END
/

ALTER TABLE IDN_ASSOCIATED_ID ADD COLUMN ASSOCIATION_ID CHAR(36) NOT NULL DEFAULT 'NONE'
/

CALL SYSPROC.ADMIN_CMD('REORG TABLE IDN_ASSOCIATED_ID')
/

UPDATE IDN_ASSOCIATED_ID SET ASSOCIATION_ID = NEWUUID()
/

CALL SYSPROC.ADMIN_CMD('REORG TABLE IDN_ASSOCIATED_ID')
/

ALTER TABLE SP_APP
    ADD COLUMN UUID CHAR(36) NOT NULL DEFAULT 'NONE'
    ADD COLUMN IMAGE_URL VARCHAR(1024)
    ADD COLUMN ACCESS_URL VARCHAR(1024)
    ADD COLUMN IS_DISCOVERABLE CHAR(1) DEFAULT '0'
/

CALL SYSPROC.ADMIN_CMD('REORG TABLE SP_APP')
/

UPDATE SP_APP SET UUID = NEWUUID()
/

CALL SYSPROC.ADMIN_CMD('REORG TABLE SP_APP')
/

ALTER TABLE SP_APP ADD CONSTRAINT APPLICATION_UUID_CONSTRAINT UNIQUE(UUID)
/

CALL SYSPROC.ADMIN_CMD('REORG TABLE SP_APP')
/

ALTER TABLE IDP
    ADD COLUMN IMAGE_URL VARCHAR(1024)
    ADD COLUMN UUID CHAR(36) NOT NULL DEFAULT 'NONE'
/

CALL SYSPROC.ADMIN_CMD('REORG TABLE IDP')
/

UPDATE IDP SET UUID = NEWUUID()
/

CALL SYSPROC.ADMIN_CMD('REORG TABLE IDP')
/

ALTER TABLE IDP ADD UNIQUE(UUID)
/

CALL SYSPROC.ADMIN_CMD('REORG TABLE IDP')
/

DROP FUNCTION NEWUUID()
/

CREATE OR REPLACE PROCEDURE ALTER_IDN_CONFIG_FILE
     DYNAMIC RESULT SETS 0
     MODIFIES SQL DATA
     LANGUAGE SQL
BEGIN ATOMIC
	IF EXISTS(SELECT * FROM SYSCAT.TABLES WHERE TABNAME='IDN_CONFIG_FILE')
	THEN
		IF NOT EXISTS(SELECT * FROM SYSCAT.COLUMNS WHERE TABNAME='IDN_CONFIG_FILE' AND COLNAME='NAME')
		THEN
			EXECUTE IMMEDIATE 'ALTER TABLE IDN_CONFIG_FILE ADD COLUMN NAME VARCHAR(255) NULL';
		END IF;
	END IF;
END
/

CALL ALTER_IDN_CONFIG_FILE
/

DROP PROCEDURE ALTER_IDN_CONFIG_FILE
/

ALTER TABLE FIDO2_DEVICE_STORE
    ADD COLUMN DISPLAY_NAME VARCHAR(255)
    ADD COLUMN IS_USERNAMELESS_SUPPORTED CHAR(1) DEFAULT '0'
/

CALL SYSPROC.ADMIN_CMD('REORG TABLE FIDO2_DEVICE_STORE')
/

ALTER TABLE IDN_OAUTH2_SCOPE_BINDING
    ADD COLUMN BINDING_TYPE VARCHAR(255) NOT NULL DEFAULT 'DEFAULT'
    ALTER COLUMN SCOPE_BINDING SET NOT NULL
/

CALL SYSPROC.ADMIN_CMD('REORG TABLE IDN_OAUTH2_SCOPE_BINDING')
/

ALTER TABLE IDN_OAUTH2_SCOPE_BINDING ADD UNIQUE (SCOPE_ID, SCOPE_BINDING, BINDING_TYPE)
/

CALL SYSPROC.ADMIN_CMD('REORG TABLE IDN_OAUTH2_SCOPE_BINDING')
/

CREATE TABLE IDN_OAUTH2_AUTHZ_CODE_SCOPE (
    CODE_ID   VARCHAR(255) NOT NULL,
    SCOPE     VARCHAR(60) NOT NULL,
    TENANT_ID INTEGER DEFAULT -1,
    PRIMARY KEY (CODE_ID, SCOPE),
    FOREIGN KEY (CODE_ID) REFERENCES IDN_OAUTH2_AUTHORIZATION_CODE (CODE_ID) ON DELETE CASCADE)
/

CREATE TABLE IDN_OAUTH2_TOKEN_BINDING (
    TOKEN_ID VARCHAR(255) NOT NULL,
    TOKEN_BINDING_TYPE VARCHAR(32) NOT NULL,
    TOKEN_BINDING_REF VARCHAR(32) NOT NULL,
    TOKEN_BINDING_VALUE VARCHAR(1024) NOT NULL,
    TENANT_ID INTEGER DEFAULT -1,
    PRIMARY KEY (TOKEN_ID),
    FOREIGN KEY (TOKEN_ID) REFERENCES IDN_OAUTH2_ACCESS_TOKEN(TOKEN_ID) ON DELETE CASCADE)
/

CREATE TABLE IDN_FED_AUTH_SESSION_MAPPING (
	IDP_SESSION_ID VARCHAR(255) NOT NULL,
	SESSION_ID VARCHAR(255) NOT NULL,
	IDP_NAME VARCHAR(255) NOT NULL,
	AUTHENTICATOR_ID VARCHAR(255),
	PROTOCOL_TYPE VARCHAR(255),
	TIME_CREATED TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	PRIMARY KEY (IDP_SESSION_ID))
/

CREATE TABLE IDN_OAUTH2_CIBA_AUTH_CODE (
    AUTH_CODE_KEY CHAR (36) NOT NULL,
    AUTH_REQ_ID CHAR (36) NOT NULL,
    ISSUED_TIME TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSUMER_KEY VARCHAR(255),
    LAST_POLLED_TIME TIMESTAMP,
    POLLING_INTERVAL INTEGER,
    EXPIRES_IN  INTEGER,
    AUTHENTICATED_USER_NAME VARCHAR(255),
    USER_STORE_DOMAIN VARCHAR(100),
    TENANT_ID INTEGER,
    AUTH_REQ_STATUS VARCHAR (100) DEFAULT 'REQUESTED',
    IDP_ID INTEGER,
    CONSTRAINT AUTH_REQ_ID_CONSTRAINT UNIQUE(AUTH_REQ_ID),
    PRIMARY KEY (AUTH_CODE_KEY),
    FOREIGN KEY (CONSUMER_KEY) REFERENCES IDN_OAUTH_CONSUMER_APPS(CONSUMER_KEY) ON DELETE CASCADE)
/

CREATE TABLE IDN_OAUTH2_CIBA_REQUEST_SCOPES (
    AUTH_CODE_KEY CHAR (36) NOT NULL,
    SCOPE VARCHAR (255),
    FOREIGN KEY (AUTH_CODE_KEY) REFERENCES IDN_OAUTH2_CIBA_AUTH_CODE(AUTH_CODE_KEY) ON DELETE CASCADE)
/

CREATE TABLE IDN_OAUTH2_DEVICE_FLOW (
    CODE_ID VARCHAR(255) NOT NULL,
    DEVICE_CODE VARCHAR(255) NOT NULL,
    USER_CODE VARCHAR(25) NOT NULL,
    CONSUMER_KEY_ID INTEGER,
    LAST_POLL_TIME TIMESTAMP NOT NULL,
    EXPIRY_TIME TIMESTAMP NOT NULL,
    TIME_CREATED TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    POLL_TIME BIGINT,
    STATUS VARCHAR (25) DEFAULT 'PENDING',
    AUTHZ_USER VARCHAR (100),
    TENANT_ID INTEGER,
    USER_DOMAIN VARCHAR(50),
    IDP_ID INTEGER,
    PRIMARY KEY (DEVICE_CODE),
    UNIQUE (CODE_ID),
    FOREIGN KEY (CONSUMER_KEY_ID) REFERENCES IDN_OAUTH_CONSUMER_APPS(ID) ON DELETE CASCADE)
/

CREATE TABLE IDN_OAUTH2_DEVICE_FLOW_SCOPES (
    ID INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    SCOPE_ID VARCHAR(255),
    SCOPE VARCHAR(255),
    PRIMARY KEY (ID),
    FOREIGN KEY (SCOPE_ID) REFERENCES IDN_OAUTH2_DEVICE_FLOW(CODE_ID) ON DELETE CASCADE)
/

-- IDN_OAUTH2_TOKEN_BINDING --
CREATE INDEX IDX_IDN_AUTH_BIND ON IDN_OAUTH2_TOKEN_BINDING (TOKEN_BINDING_REF)
/

-- IDN_ASSOCIATED_ID --
CREATE INDEX IDX_AI_DN_UN_AI ON IDN_ASSOCIATED_ID(DOMAIN_NAME, USER_NAME, ASSOCIATION_ID)
/

-- IDN_OAUTH2_ACCESS_TOKEN --
CREATE INDEX IDX_AT_CKID_AU_TID_UD_TSH_TS ON IDN_OAUTH2_ACCESS_TOKEN(CONSUMER_KEY_ID, AUTHZ_USER, TENANT_ID, USER_DOMAIN, TOKEN_SCOPE_HASH, TOKEN_STATE)
/

-- IDN_FED_AUTH_SESSION_MAPPING --
CREATE INDEX IDX_FED_AUTH_SESSION_ID ON IDN_FED_AUTH_SESSION_MAPPING (SESSION_ID)
/

-- Related to scope management changes --

ALTER TABLE IDN_OAUTH2_SCOPE
    ADD COLUMN SCOPE_TYPE VARCHAR(255) NOT NULL DEFAULT 'OAUTH2'
    ADD UNIQUE (NAME, SCOPE_TYPE, TENANT_ID)
/

CALL SYSPROC.ADMIN_CMD('REORG TABLE IDN_OAUTH2_SCOPE')
/

CREATE TABLE IDN_OIDC_SCOPE_CLAIM_MAPPING_NEW (
    ID INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1),
    SCOPE_ID INTEGER NOT NULL,
    EXTERNAL_CLAIM_ID INTEGER NOT NULL,
    PRIMARY KEY (ID),
    FOREIGN KEY (SCOPE_ID) REFERENCES IDN_OAUTH2_SCOPE(SCOPE_ID) ON DELETE CASCADE,
    FOREIGN KEY (EXTERNAL_CLAIM_ID) REFERENCES IDN_CLAIM(ID) ON DELETE CASCADE,
    UNIQUE (SCOPE_ID, EXTERNAL_CLAIM_ID)
)
/

CREATE OR REPLACE PROCEDURE OIDC_SCOPE_DATA_MIGRATE_PROCEDURE
BEGIN
    DECLARE oidc_scope_count INT DEFAULT 0;
    DECLARE row_offset INT DEFAULT 0;
    DECLARE oauth_scope_id INT DEFAULT 0;
    DECLARE oidc_scope_id INT DEFAULT 0;
    SET oidc_scope_count = (SELECT COUNT FROM IDN_OIDC_SCOPE);
    WHILE row_offset < oidc_scope_count DO
        SET oidc_scope_id = (SELECT ID FROM IDN_OIDC_SCOPE LIMIT row_offset,1);
        SET oauth_scope_id = (SELECT SCOPE_ID FROM FINAL TABLE (INSERT INTO IDN_OAUTH2_SCOPE (NAME, DISPLAY_NAME, TENANT_ID, SCOPE_TYPE) SELECT NAME, NAME, TENANT_ID, 'OIDC' FROM IDN_OIDC_SCOPE LIMIT row_offset,1));
        INSERT INTO IDN_OIDC_SCOPE_CLAIM_MAPPING_NEW (SCOPE_ID, EXTERNAL_CLAIM_ID) SELECT oauth_scope_id, EXTERNAL_CLAIM_ID FROM IDN_OIDC_SCOPE_CLAIM_MAPPING WHERE SCOPE_ID = oidc_scope_id;
        SET row_offset = row_offset + 1;
    END WHILE;
END
/

CALL OIDC_SCOPE_DATA_MIGRATE_PROCEDURE
/

DROP PROCEDURE OIDC_SCOPE_DATA_MIGRATE_PROCEDURE
/

DROP TABLE IDN_OIDC_SCOPE_CLAIM_MAPPING
/

CREATE TABLE IDN_OIDC_SCOPE_CLAIM_MAPPING LIKE IDN_OIDC_SCOPE_CLAIM_MAPPING_NEW
/

INSERT INTO IDN_OIDC_SCOPE_CLAIM_MAPPING SELECT * FROM IDN_OIDC_SCOPE_CLAIM_MAPPING_NEW
/

DROP TABLE IDN_OIDC_SCOPE_CLAIM_MAPPING_NEW
/

DROP TABLE IDN_OIDC_SCOPE
/

DROP SEQUENCE IDN_OIDC_SCOPE_SEQUENCE
/