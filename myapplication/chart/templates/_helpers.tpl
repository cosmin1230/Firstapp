{{/*
Expand the name of the chart
*/}}
{{- define "my-application.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "my-application.name" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the image name
*/}}
{{- define "my-application.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag | quote -}}
{{- end -}}

{{/*
Return the service name
*/}}
{{- define "my-application.serviceName" -}}
{{- printf "%s-service" .Chart.Name | quote -}}
{{- end -}}

{{/*
Return the MySQL secret name
*/}}
{{- define "my-application.mysqlSecretName" -}}
{{- printf "%s-mysql-secret" .Chart.Name | quote -}}
{{- end -}}