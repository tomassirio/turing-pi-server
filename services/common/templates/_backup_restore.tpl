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
  image: instrumentisto/rsync-ssh:latest
  imagePullPolicy: IfNotPresent
  command: ["/bin/sh", "-c"]
  args:
    - |
      set -e
      echo "🔄 Restoring config from backup..."
      mkdir -p {{ $configPath }}
      if [ -d "/restore-source/{{ $appName }}" ]; then
        echo "📦 Found backup, syncing..."
        # First, count total files
        total=$(rsync -a --dry-run --stats --delete --no-o --no-g /restore-source/{{ $appName }}/ {{ $configPath }}/ | grep "Number of regular files transferred:" | awk '{print $6}')
        echo "📊 Files to transfer: $total"
        # Now do actual transfer with verbose output and counter
        rsync -av --delete --no-o --no-g /restore-source/{{ $appName }}/ {{ $configPath }}/ | awk -v total="$total" 'BEGIN{count=0} !/\/$/ && !/sending incremental/ && !/sent.*received/ && !/total size/ && NF>0 && !/^$/ {count++; printf "[%d/%s] %s\n", count, total, $0}'
        echo ""
        echo "✅ Restore complete."
      else
        echo "⚠️ No backup found at /restore-source/{{ $appName }}, starting fresh."
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

Manual backup trigger:
  kubectl exec -it <pod-name> -c backup-config -- touch /tmp/trigger-backup
*/}}
{{- define "common.backup.sidecar" -}}
{{- $appName := .AppName -}}
{{- $configPath := .ConfigPath | default "/config" -}}
- name: backup-config
  image: instrumentisto/rsync-ssh:latest
  imagePullPolicy: IfNotPresent
  command: ["/bin/sh", "-c"]
  args:
    - |
      do_backup() {
        echo "🚀 Starting backup..."
        mkdir -p /backup-dest/{{ $appName }}
        # First, count total files
        total=$(rsync -a --dry-run --stats --delete --no-o --no-g {{ $configPath }}/ /backup-dest/{{ $appName }}/ | grep "Number of regular files transferred:" | awk '{print $6}')
        echo "📊 Files to transfer: $total"
        # Now do actual transfer with verbose output and counter
        rsync -av --delete --no-o --no-g {{ $configPath }}/ /backup-dest/{{ $appName }}/ | awk -v total="$total" 'BEGIN{count=0} !/\/$/ && !/sending incremental/ && !/sent.*received/ && !/total size/ && NF>0 && !/^$/ {count++; printf "[%d/%s] %s\n", count, total, $0}'
        echo ""
        echo "✅ Backup completed at $(date)"
      }

      echo "⏰ Starting backup scheduler..."
      echo "💡 Tip: Trigger manual backup with: kubectl exec -it <pod> -c backup-config -- touch /tmp/trigger-backup"
      while true; do
        # Check for manual trigger
        if [ -f /tmp/trigger-backup ]; then
          echo "🔔 Manual backup triggered!"
          rm -f /tmp/trigger-backup
          do_backup
          continue
        fi

        # Get current time
        current_hour=$(date +%H | sed 's/^0//')
        current_min=$(date +%M | sed 's/^0//')
        current_sec=$(date +%S | sed 's/^0//')
        
        # Calculate seconds since midnight today
        seconds_since_midnight=$((current_hour * 3600 + current_min * 60 + current_sec))
        
        # Target is 2 AM (7200 seconds since midnight)
        target_seconds=7200
        
        if [ $seconds_since_midnight -lt $target_seconds ]; then
          # Before 2 AM today - wait until 2 AM today
          sleep_seconds=$((target_seconds - seconds_since_midnight))
        else
          # After 2 AM - wait until 2 AM tomorrow (86400 = seconds in a day)
          sleep_seconds=$((86400 - seconds_since_midnight + target_seconds))
        fi
        
        echo "💤 Next scheduled backup in $sleep_seconds seconds (2 AM)..."

        # Sleep in short intervals to check for manual trigger
        elapsed=0
        while [ $elapsed -lt $sleep_seconds ]; do
          sleep 10
          elapsed=$((elapsed + 10))
          # Check for manual trigger during wait
          if [ -f /tmp/trigger-backup ]; then
            echo "🔔 Manual backup triggered!"
            rm -f /tmp/trigger-backup
            do_backup
            break
          fi
        done

        # If we completed the full wait (no manual trigger), do scheduled backup
        if [ $elapsed -ge $sleep_seconds ]; then
          do_backup
        fi
      done
  volumeMounts:
    - name: config
      mountPath: {{ $configPath }}
    - name: backup
      mountPath: /backup-dest
{{- end -}}
