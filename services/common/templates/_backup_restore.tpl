{{/*
Restore InitContainer
Params:
  - .Values: The values context
  - .AppName: The name of the application (e.g. sonarr)
  - .ConfigPath: The path where config is mounted (default: /config)
*/}}
{{- define "common.restore.initContainer" -}}
{{- $appName := .AppName -}}
{{- $configPath := .ConfigPath | default "/config" -}}
- name: restore-config
  image: alpine:latest
  command: ["/bin/sh", "-c"]
  args:
    - |
      set -e
      echo "Installing rsync..."
      apk add --no-cache rsync
      echo "Restoring config from backup..."
      mkdir -p {{ $configPath }}
      if [ -d "/restore-source/{{ $appName }}" ]; then
        echo "Found backup, syncing..."
        # -a: archive mode (preserves permissions, times, etc.)
        # -v: verbose
        # --delete: delete extraneous files from dest dirs
        rsync -av --delete /restore-source/{{ $appName }}/ {{ $configPath }}/
        echo "Restore complete."
      else
        echo "No backup found at /restore-source/{{ $appName }}, starting fresh."
      fi
      exit 0
  volumeMounts:
    - name: config
      mountPath: {{ $configPath }}
    - name: {{ if eq .Values.persistence.restore.existingClaim .Values.persistence.backup.existingClaim }}backup{{ else }}restore{{ end }}
      mountPath: /restore-source
      readOnly: true
{{- end -}}

{{/*
Backup Sidecar Container
Params:
  - .Values: The values context
  - .AppName: The name of the application (e.g. sonarr)
  - .ConfigPath: The path where config is mounted (default: /config)
*/}}
{{- define "common.backup.sidecar" -}}
{{- $appName := .AppName -}}
{{- $configPath := .ConfigPath | default "/config" -}}
- name: backup-config
  image: alpine:latest
  command: ["/bin/sh", "-c"]
  args:
    - |
      echo "Starting backup scheduler..."
      apk add --no-cache coreutils rsync
      while true; do
        current_time=$(date +%s)
        target_today=$(date -d "today 02:00" +%s)
        if [ $current_time -lt $target_today ]; then
          next_run=$target_today
        else
          next_run=$(date -d "tomorrow 02:00" +%s)
        fi
        
        sleep_seconds=$((next_run - current_time))
        echo "Sleeping for $sleep_seconds seconds until 2 AM..."
        sleep $sleep_seconds
        
        echo "Starting backup..."
        mkdir -p /backup-dest/{{ $appName }}
        # Sync from config to backup
        rsync -av --delete {{ $configPath }}/ /backup-dest/{{ $appName }}/
        echo "Backup completed at $(date)"
        sleep 60
      done
  volumeMounts:
    - name: config
      mountPath: {{ $configPath }}
    - name: backup
      mountPath: /backup-dest
{{- end -}}
