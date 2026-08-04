# Expected Tests

## Web Internal

```bash
curl -I http://192.168.50.10:8080
curl http://192.168.50.10:8080/download/
curl http://192.168.50.10:8080/download/backup-config.txt
```

## Web Lab

```bash
curl -I http://192.168.50.10:8081
curl http://192.168.50.10:8081/robots.txt
curl http://192.168.50.10:8081/api/profile/1
curl 'http://192.168.50.10:8081/download?file=readme.txt'
```

## Logs

```bash
tail -f logs/web-internal/access.log
tail -f logs/web-vuln/access.jsonl
tail -f logs/web-vuln/collector.log
```
