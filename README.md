# rclone-pbs-script

Inspired by [https://r00t.dk/post/2022/05/28/rsync-rclone-experience-backing-up-proxmox/](https://r00t.dk/post/2022/05/28/rsync-rclone-experience-backing-up-proxmox/), this script has been modified to support multiple backends, as well as send an optional notification to [healthchecks.io](healthchecks.io).

## Usage

### backup

```bash
bash -x rclone.sh [SRC] [BACKEND]:[BUCKET]/[DIR]
```

### Restoring

Create the restore directory in your Proxmox Backup Server appliance

```bash
root@pbs:~# mkdir /restore
```

Create the Repository in PBS

```bash
cat <<EOF >> /etc/proxmox-backup/datastore.cfg
datastore: RestoreTest
        path /restore
EOF
```

Perform the restore sync from the Rclone Backend

```
root@pbs:~# rclone sync \
    --progress \
    --stats-one-line \
    --stats=30s \
    --transfers=24 \
    --checkers=24 \
    --config=./.rclone.conf \
    [BACKEND]:[BUCKET]/[DIR] /restore/.
```

## Secrets

Secrets are sourced from `env_conf`. There is an example at `env_conf.example` which should be updated and renamed for your use.
