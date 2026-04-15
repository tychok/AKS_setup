{{- define "business-app.name" -}}
{{ .Values.appName | default .Release.Name }}
{{- end -}}

{{- define "business-app.labels" -}}
app.kubernetes.io/name: {{ include "business-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: aks-platform
team: {{ .Values.team | default "unknown" }}
{{- if .Values.costCenter }}
cost-center: {{ .Values.costCenter | quote }}
{{- end }}
{{- end -}}

{{- define "business-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "business-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "business-app.nodeSelector" -}}
{{- if eq .Values.nodePool "highmem" }}
nodepool: highmem
tier: highmem
{{- else if eq .Values.nodePool "compute" }}
nodepool: compute
tier: compute
{{- else }}
nodepool: standard
tier: standard
{{- end }}
{{- end -}}

{{- define "business-app.tolerations" -}}
{{- if eq .Values.nodePool "highmem" }}
- key: workload
  value: highmem
  effect: NoSchedule
{{- else if eq .Values.nodePool "compute" }}
- key: workload
  value: compute
  effect: NoSchedule
{{- end }}
{{- with .Values.tolerations }}
{{ toYaml . }}
{{- end }}
{{- end -}}
