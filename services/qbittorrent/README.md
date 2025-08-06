In order to run this chart with the secrets, use helm secrets

```bash
  helm secrets upgrade -i qbittorrent services/qbittorrent/ -f services/qbittorrent/secrets.yaml
```
