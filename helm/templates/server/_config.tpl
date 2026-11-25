{{- define "unitycatalog.server.configTemplate" -}}

{{- if .Values.server.config.override -}}
{{ .Values.server.config.override }}
{{- else -}}
server.env=prod
{{- if .Values.auth.enabled }}
server.authorization=enable
server.authorization-url={{ include "unitycatalog.properties.value" (dict "value" .Values.auth.authorizationUrl "path" "auth.authorizationUrl") }}
server.token-url={{ include "unitycatalog.properties.value" (dict "value" .Values.auth.tokenUrl "path" "auth.tokenUrl") }}
server.client-id=${OAUTH_CLIENT_ID}
server.redirect-port={{ include "unitycatalog.properties.value" (dict "value" .Values.auth.redirectPort "path" "auth.redirectPort") }}
server.cookie-timeout={{ include "unitycatalog.properties.value" (dict "value" .Values.auth.cookieTimeout "path" "auth.cookieTimeout") }}
server.access-token-timeout={{ include "unitycatalog.properties.value" (dict "value" .Values.auth.accessTokenTimeout "path" "auth.accessTokenTimeout") }}
server.allowed-issuers={{ include "unitycatalog.properties.value" (dict "value" .Values.auth.allowedIssuers "path" "auth.allowedIssuers") }}
server.allowed-jwks-uris={{ include "unitycatalog.properties.value" (dict "value" .Values.auth.allowedJwksUris "path" "auth.allowedJwksUris") }}
server.audiences={{ include "unitycatalog.properties.value" (dict "value" .Values.auth.audiences "path" "auth.audiences") }}
{{- end }}

storage-root.models={{ include "unitycatalog.properties.value" (dict "value" .Values.storage.modelStorageRoot "path" "storage.modelStorageRoot") }}

{{- range $index, $config := .Values.storage.credentials.s3 }}
s3.bucketPath.{{ $index }}={{ include "unitycatalog.properties.value" (dict "value" $config.bucketPath "path" "storage.credentials.s3[].bucketPath") }}
s3.region.{{ $index }}={{ include "unitycatalog.properties.value" (dict "value" $config.region "path" "storage.credentials.s3[].region") }}
s3.awsRoleArn.{{ $index }}={{ include "unitycatalog.properties.value" (dict "value" $config.awsRoleArn "path" "storage.credentials.s3[].awsRoleArn") }}
{{- end }}

{{- range $index, $config := .Values.storage.credentials.adls }}
adls.storageAccountName.{{ $index }}={{ include "unitycatalog.properties.value" (dict "value" $config.storageAccountName "path" "storage.credentials.adls[].storageAccountName") }}
{{- end }}

{{- range $index, $config := .Values.storage.credentials.gcs }}
gcs.bucketPath.{{ $index }}={{ include "unitycatalog.properties.value" (dict "value" $config.bucketPath "path" "storage.credentials.gcs[].bucketPath") }}
gcs.jsonKeyFilePath.{{ $index }}=/etc/conf/gcs-credentials-{{ $index }}.json
{{- end }}
{{- end }}

{{- range $k, $v := .Values.server.config.extraProperties }}
{{ include "unitycatalog.properties.key" (dict "key" $k "path" (printf "server.config.extraProperties.%s" $k)) }}={{ include "unitycatalog.properties.value" (dict "value" $v "path" (printf "server.config.extraProperties.%s" $k)) }}
{{- end }}

{{- end }}

{{/*
A value in a properties file the init container runs envsubst on. Properties.load ends an entry at a
line break and decodes backslash escapes, so a value with a control character fails the render, a
backslash is doubled and a leading space is escaped. A $ reference is left for envsubst. `path`
names the value in messages.
*/}}
{{- define "unitycatalog.properties.value" -}}
{{- if or (kindIs "map" .value) (kindIs "slice" .value) }}
{{- fail (printf "%s: a value must be a string, number or boolean, not a map or list" .path) }}
{{- end }}
{{- $value := "" }}
{{- if not (kindIs "invalid" .value) }}
{{- $value = toString .value }}
{{- end }}
{{- if regexMatch "[[:cntrl:]]" $value }}
{{- fail (printf "%s: a value cannot contain a line break or another control character" .path) }}
{{- end }}
{{- $value = replace "\\" "\\\\" $value }}
{{- if hasPrefix " " $value }}\{{ end }}{{ $value }}
{{- end }}

{{/*
A key in a properties file. A key with a control character fails the render, and a backslash, =, :,
a space, # and ! are escaped, as Properties.load reads them. `path` names the key in messages.
*/}}
{{- define "unitycatalog.properties.key" -}}
{{- $key := toString .key }}
{{- if regexMatch "[[:cntrl:]]" $key }}
{{- fail (printf "%s: a key cannot contain a line break or another control character" .path) }}
{{- end }}
{{- regexReplaceAll "([\\\\=: #!])" $key "\\${1}" }}
{{- end }}

{{/*
The host and port of a JDBC URL. A host with a character that ends it or starts another part of the
URL fails the render, and so does a port that is not a number. `path` names the database settings.
*/}}
{{- define "unitycatalog.server.jdbcHostPort" -}}
{{- $host := toString (.host | default "") }}
{{- if regexMatch "[/?#&=\\\\[:space:][:cntrl:]]" $host }}
{{- fail (printf "%s.host: a host cannot contain /, ?, #, &, =, a backslash, a space or a control character" .path) }}
{{- end }}
{{- $port := toString (.port | default "") }}
{{- if not (regexMatch "^[0-9]+$" $port) }}
{{- fail (printf "%s.port: a port must be a number, got %q" .path $port) }}
{{- end }}
{{- $host }}:{{ $port }}
{{- end }}

{{/*
The query of a JDBC URL, ?name=value&..., or nothing without parameters. Values are form-encoded,
and names too with `encodeNames`. A value must be a string, number or boolean. `path` names the
parameters in messages.
*/}}
{{- define "unitycatalog.server.jdbcUrlQuery" -}}
{{- $pairs := list }}
{{- range $key, $value := .params }}
{{- if or (kindIs "map" $value) (kindIs "slice" $value) }}
{{- fail (printf "%s.%s: a value must be a string, number or boolean, not a map or list" $.path $key) }}
{{- end }}
{{- $name := $key }}
{{- if $.encodeNames }}
{{- $name = urlquery $key }}
{{- end }}
{{- $pairs = append $pairs (printf "%s=%s" $name (urlquery $value)) }}
{{- end }}
{{- if $pairs }}?{{ join "&" $pairs }}{{ end }}
{{- end }}

{{- define "unitycatalog.server.hibernateConfigTemplate" -}}
{{- if .Values.server.db.overrideConfig -}}
{{ .Values.server.db.overrideConfig }}
{{- else if eq .Values.server.db.type "file" -}}
hibernate.connection.driver_class=org.h2.Driver
hibernate.connection.url=jdbc:h2:file:./etc/db/h2db;DB_CLOSE_ON_EXIT=FALSE;DB_CLOSE_DELAY=0
{{- else if eq .Values.server.db.type "postgresql" -}}

{{- $params := dict }}

{{- if .Values.server.db.postgresqlConfig.ssl.enabled }}
{{- $params = merge $params (dict "sslmode" .Values.server.db.postgresqlConfig.ssl.mode) }}
{{- $params = merge $params (dict "sslrootcert" "/home/unitycatalog/etc/conf/dbrootca.crt") }}
{{- end }}

{{- range $key, $value := .Values.server.db.postgresqlConfig.extraParams }}
{{- /* The init container runs envsubst on hibernate.properties, and the server reads it with Properties.load, which decodes backslash escapes and ends an entry at a line break. */}}
{{- if regexMatch "[&=$\\\\[:cntrl:]]" $key }}
{{- fail (printf "server.db.postgresqlConfig.extraParams.%q: a parameter name cannot contain &, =, $, a backslash or a control character" $key) }}
{{- end }}
{{- if hasKey $params $key }}
{{- fail (printf "server.db.postgresqlConfig.extraParams.%s is set by server.db.postgresqlConfig.ssl: remove it from extraParams" $key) }}
{{- end }}
{{- $_ := set $params $key $value }}
{{- end }}

{{- $pg := .Values.server.db.postgresqlConfig -}}
hibernate.connection.driver_class=org.postgresql.Driver
{{- /* PgJDBC form-decodes the database name and the parameter values, but not the parameter names. */}}
hibernate.connection.url=jdbc:postgresql://{{ include "unitycatalog.server.jdbcHostPort" (dict "host" $pg.host "port" $pg.port "path" "server.db.postgresqlConfig") }}/{{ urlquery $pg.dbName }}{{ include "unitycatalog.server.jdbcUrlQuery" (dict "params" $params "encodeNames" false "path" "server.db.postgresqlConfig.extraParams") }}
hibernate.connection.user={{ include "unitycatalog.properties.value" (dict "value" $pg.username "path" "server.db.postgresqlConfig.username") }}
{{- else if eq .Values.server.db.type "mysql" -}}
{{- $my := .Values.server.db.mysqlConfig -}}
hibernate.connection.driver_class=com.mysql.cj.jdbc.Driver
{{- /* Connector/J form-decodes the whole URL, the database name too, so urlquery is the right escape for it. */}}
hibernate.connection.url=jdbc:mysql://{{ include "unitycatalog.server.jdbcHostPort" (dict "host" (required "server.db.mysqlConfig.host is required" $my.host) "port" $my.port "path" "server.db.mysqlConfig") }}/{{ urlquery $my.dbName }}{{ include "unitycatalog.server.jdbcUrlQuery" (dict "params" $my.extraParams "encodeNames" true "path" "server.db.mysqlConfig.extraParams") }}
hibernate.connection.user={{ include "unitycatalog.properties.value" (dict "value" $my.username "path" "server.db.mysqlConfig.username") }}
{{- else }}
{{ fail "Unsupported database type. Supported types are: file, postgresql, mysql." }}
{{- end }}

hibernate.show_sql=false
hibernate.archive.autodetection=class
hibernate.use_sql_comments=true
org.hibernate.SQL=INFO
org.hibernate.type.descriptor.sql.BasicBinder=TRACE
{{- end }}

{{- define "unitycatalog.server.log4j2ConfigTemplate" -}}
status=warn
appenders=console,auditFile

appender.console.type=Console
appender.console.name=Console
appender.console.layout.type=PatternLayout
appender.console.layout.pattern=%d{HH:mm:ss.SSS} ${hostName} [%t] %-5level %logger{36} %notEmpty{request_id=%X{request_id} }- %msg%n

# Audit records (server.audit.sink=io.unitycatalog.server.audit.FileAuditSink); no file is created
# until the first record. Rolls over every hour and at 10MB, and keeps up to 7 days or 1GB of archives.
appender.auditFile.type=RollingFile
appender.auditFile.name=AuditFile
appender.auditFile.fileName=/home/unitycatalog/etc/logs/audit.log
appender.auditFile.filePattern=/home/unitycatalog/etc/logs/audit-%d{yyyy-MM-dd-HH}-%i.log.gz
appender.auditFile.createOnDemand=true
appender.auditFile.ignoreExceptions=false
appender.auditFile.layout.type=PatternLayout
appender.auditFile.layout.pattern=%m%n
appender.auditFile.policies.type=Policies
appender.auditFile.policies.time.type=TimeBasedTriggeringPolicy
appender.auditFile.policies.time.interval=1
appender.auditFile.policies.size.type=SizeBasedTriggeringPolicy
appender.auditFile.policies.size.size=10MB
appender.auditFile.strategy.type=DefaultRolloverStrategy
appender.auditFile.strategy.max=20
appender.auditFile.strategy.fileIndex=max
appender.auditFile.strategy.action.type=Delete
appender.auditFile.strategy.action.basePath=/home/unitycatalog/etc/logs
appender.auditFile.strategy.action.condition.type=IfFileName
appender.auditFile.strategy.action.condition.glob=audit-*.log.gz
appender.auditFile.strategy.action.condition.any.type=IfAny
appender.auditFile.strategy.action.condition.any.age.type=IfLastModified
appender.auditFile.strategy.action.condition.any.age.age=P7D
appender.auditFile.strategy.action.condition.any.size.type=IfAccumulatedFileSize
appender.auditFile.strategy.action.condition.any.size.exceeds=1GB

logger.audit.name=audit
logger.audit.level=info
logger.audit.additivity=false
logger.audit.appenderRef.auditFile.ref=AuditFile

rootLogger.level={{ .Values.server.logLevel }}
rootLogger.appenderRefs=console
rootLogger.appenderRef.console.ref=Console
{{- end }}

{{/*
The database password, for the server and upgrade-schema containers.
*/}}
{{- define "unitycatalog.server.dbPasswordEnv" -}}
{{- $db := dict "postgresql" .Values.server.db.postgresqlConfig "mysql" .Values.server.db.mysqlConfig }}
{{- with get $db .Values.server.db.type }}
{{- if .passwordSecretName }}
- name: UC_HIBERNATE_CONNECTION_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .passwordSecretName | quote }}
      key: {{ required "Password secret key is required" .passwordSecretKey | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Secrets for the server container (see "Secrets" in docs/server/configuration.md): the database
password, every part of each storage credential and the credential encryption key come from here,
not from the generated properties files, which are written only at pod start.
*/}}
{{- define "unitycatalog.server.secretEnv" -}}
{{- include "unitycatalog.server.dbPasswordEnv" . }}
{{- range $index, $config := .Values.storage.credentials.s3 }}
- name: UC_S3_ACCESSKEY_{{ $index }}
  valueFrom:
    secretKeyRef:
      name: {{ $config.credentialsSecretName | quote }}
      key: accessKey
- name: UC_S3_SECRETKEY_{{ $index }}
  valueFrom:
    secretKeyRef:
      name: {{ $config.credentialsSecretName | quote }}
      key: secretKey
{{- end }}
{{- range $index, $config := .Values.storage.credentials.adls }}
- name: UC_ADLS_TENANTID_{{ $index }}
  valueFrom:
    secretKeyRef:
      name: {{ $config.credentialsSecretName | quote }}
      key: tenantId
- name: UC_ADLS_CLIENTID_{{ $index }}
  valueFrom:
    secretKeyRef:
      name: {{ $config.credentialsSecretName | quote }}
      key: clientId
- name: UC_ADLS_CLIENTSECRET_{{ $index }}
  valueFrom:
    secretKeyRef:
      name: {{ $config.credentialsSecretName | quote }}
      key: clientSecret
{{- end }}
{{- with .Values.server.credentialEncryptionKeySecret }}
{{- if .name }}
- name: UC_SERVER_CREDENTIAL_ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .name | quote }}
      key: {{ required "Credential encryption key secret key is required" .key | quote }}
{{- end }}
{{- end }}
{{- end }}
