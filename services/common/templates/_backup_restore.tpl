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
        # --no-o --no-g: don't try to preserve owner/group (avoids permission errors)
        rsync -av --delete --no-o --no-g /restore-source/{{ $appName }}/ {{ $configPath }}/
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
      apk add --no-cache rsync
      while true; do
        current_time=$(date +%s)
        current_hour=$(date +%H)
        current_min=$(date +%M)
        current_sec=$(date +%S)
        
        # Calculate seconds until 2 AM
        seconds_since_2am=$(( (current_hour - 2) * 3600 + current_min * 60 + current_sec ))
        
        if [ $seconds_since_2am -lt 0 ]; then
          # It's before 2 AM today, wait until 2 AM today
          sleep_seconds=$(( -seconds_since_2am ))
        else
          # It's after 2 AM, wait until 2 AM tomorrow
          sleep_seconds=$(( 86400 - seconds_since_2am ))
        fi
        
        echo "Sleeping for $sleep_seconds seconds until 2 AM..."
        sleep $sleep_seconds
        
        echo "Starting backup..."
        mkdir -p /backup-dest/{{ $appName }}
        # Sync from config to backup
        # --no-o --no-g: don't try to preserve owner/group (avoids permission errors on NAS)
        rsync -av --delete --no-o --no-g {{ $configPath }}/ /backup-dest/{{ $appName }}/
        echo "Backup completed at $(date)"
        sleep 60
      done
  volumeMounts:
    - name: config
      mountPath: {{ $configPath }}
    - name: backup
      mountPath: /backup-dest
{{- end -}}
