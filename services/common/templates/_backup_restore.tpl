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
      # rsync --no-g leaves new files group-owned by this container's own
      # group (root), not the pod's fsGroup, so a plain "g+rwX" only helps
      # if that group happens to match -- it didn't (root vs fsGroup 1000),
      # and files that already existed before this fix kept failing.
      # Force world-writable so this can't depend on group ownership at all.
      chmod -R a+rwX {{ $configPath }}
      exit 0
  resources:
    requests:
      cpu: 10m
      memory: 32Mi
      ephemeral-storage: 64Mi
    limits:
      cpu: 250m
      memory: 128Mi
      ephemeral-storage: 256Mi
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
        # A backup is a --delete mirror: one bad snapshot (crash, permission
        # error, botched restore) permanently overwrites the only good copy,
        # with no history to fall back to. Refuse to mirror if the live
        # config lost more than half its files vs. the last backup -- that's
        # config that broke, not config the user actually cleaned up.
        current_count=$(find {{ $configPath }} -type f 2>/dev/null | wc -l)
        backup_count=$(find /backup-dest/{{ $appName }} -type f 2>/dev/null | wc -l)
        if [ "$backup_count" -gt 10 ] && [ "$current_count" -lt "$((backup_count / 2))" ]; then
          echo "🛑 Refusing backup: live config has $current_count files, last backup has $backup_count. >50% drop looks like corruption, not intentional cleanup. Leaving last good backup in place."
          return
        fi
        # First, count total files
        total=$(rsync -a --dry-run --stats --delete --no-o --no-g {{ $configPath }}/ /backup-dest/{{ $appName }}/ | grep "Number of regular files transferred:" | awk '{print $6}')
        echo "📊 Files to transfer: $total"
        # Now do actual transfer with verbose output and counter
        rsync -av --delete --no-o --no-g {{ $configPath }}/ /backup-dest/{{ $appName }}/ | awk -v total="$total" 'BEGIN{count=0} !/\/$/ && !/sending incremental/ && !/sent.*received/ && !/total size/ && NF>0 && !/^$/ {count++; printf "[%d/%s] %s\n", count, total, $0}'
        echo ""
        echo "✅ Backup completed at $(date)"
      }

      echo "⏰ Starting backup scheduler (every {{ .Values.persistence.backup.intervalSeconds | default 3600 }}s)..."
      echo "💡 Tip: Trigger manual backup with: kubectl exec -it <pod> -c backup-config -- touch /tmp/trigger-backup"
      do_backup
      while true; do
        elapsed=0
        while [ $elapsed -lt {{ .Values.persistence.backup.intervalSeconds | default 3600 }} ]; do
          if [ -f /tmp/trigger-backup ]; then
            echo "🔔 Manual backup triggered!"
            rm -f /tmp/trigger-backup
            do_backup
            elapsed=0
          fi
          sleep 10
          elapsed=$((elapsed + 10))
        done
        do_backup
      done
  resources:
    requests:
      cpu: 10m
      memory: 32Mi
      ephemeral-storage: 64Mi
    limits:
      cpu: 250m
      memory: 128Mi
      ephemeral-storage: 256Mi
  volumeMounts:
    - name: config
      mountPath: {{ $configPath }}
    - name: backup
      mountPath: /backup-dest
{{- end -}}
