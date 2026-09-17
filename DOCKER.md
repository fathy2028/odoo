# Running this Odoo in Docker

Works the same on Linux, macOS (Intel and Apple Silicon) and Windows. Nothing is
installed on the host: Python, PostgreSQL, wkhtmltopdf and Node all live in the
containers.

## Requirements

- Docker Engine 20.10+ with the Compose v2 plugin (`docker compose`, not `docker-compose`)
- About 4 GB of RAM available to Docker and ~6 GB of disk
- On **Windows**: Docker Desktop with the WSL2 backend
- On **macOS**: Docker Desktop (the image builds natively for Apple Silicon)

## Quick start

```bash
git clone https://github.com/fathy2028/odoo.git
cd odoo
cp .env.example .env        # Windows: copy .env.example .env
docker compose up -d --build
```

The first build takes several minutes (it compiles the Python dependencies).
Then open <http://localhost:8069> and log in with `admin` / `admin`.

On the first start the entrypoint creates the database named by `ODOO_DB`,
installs `ODOO_INIT_MODULES` and loads demo data when `ODOO_WITH_DEMO=true`.
On later starts it only installs modules that are missing.

## Configuration

`.env` is git-ignored; copy it from `.env.example`. Without it Compose uses the
same defaults.

| Variable | Default | Meaning |
|---|---|---|
| `DB_USER` / `DB_PASSWORD` | `odoo` / `odoo` | PostgreSQL credentials |
| `ODOO_PORT` | `8069` | Host port for the web interface |
| `ODOO_GEVENT_PORT` | `8072` | Host port for websockets (live chat) |
| `ODOO_DB` | `ecom` | Database prepared on startup (empty = skip) |
| `ODOO_INIT_MODULES` | `website_sale,fathy` | Modules installed if missing |
| `ODOO_WITH_DEMO` | `true` | Load demo data |

Server options live in `config/odoo.conf`. The database settings there are
overwritten at startup from the environment.

## Everyday commands

```bash
docker compose up -d --build                              # start (rebuild if needed)
docker compose logs -f odoo                               # follow the logs
docker compose down                                       # stop, keep the data
docker compose down -v                                    # stop and delete all data
docker compose restart odoo                               # apply config/odoo.conf changes
docker compose run --rm odoo module upgrade -d ecom fathy # upgrade a module
docker compose run --rm odoo shell -d ecom                # Odoo Python shell
docker compose exec db psql -U odoo -d ecom               # SQL prompt
```

Your own modules go in `custom_addons/`. The folder is mounted into the running
container, so Python changes need only `docker compose restart odoo`; changes to
XML data need a module upgrade (see above).

## Notes per OS

**Windows.** `.gitattributes` keeps shell scripts LF on checkout, and the image
strips carriage returns during the build, so a Windows clone starts normally.
Run the commands from PowerShell in the repo folder. If Docker Desktop asks to
share the drive holding the repo, accept it, otherwise the bind mounts stay empty.

**macOS.** On Apple Silicon everything builds natively for arm64. Give Docker
Desktop at least 4 GB of memory under Settings → Resources.

**Linux.** If `docker` needs `sudo`, either prefix the commands or add yourself
to the `docker` group. The container runs as uid 999 and only reads
`custom_addons`, so no permission changes are needed.

**Other architectures.** The patched wkhtmltopdf is published for amd64, arm64
and ppc64el. Elsewhere the build falls back to the distribution package, which
produces PDFs without headers and footers.

## Before deploying

- Change `admin_passwd` in `config/odoo.conf` (it guards the database manager)
- Change the `admin` user's password and the database password in `.env`
- Add `list_db = False` to hide the database manager
- Set `workers = 2` or more in `config/odoo.conf` for real use, and put a reverse
  proxy in front, setting `proxy_mode = True`
