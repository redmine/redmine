# Running locally

### Set up

Make sure you have initialized and updated the plugin submodules by doing
```
git submodule init
git submodule update
```

Create `config/database.yml` with your redmine database configuration, eg

```
development:
  adapter: postgresql
  host: "redmine.cvercoii5oay.us-east-1.rds.amazonaws.com"
  port: "5432"
  username: "redmine"
  password: "secret"
  database: "redmine_experimental"
  encoding: "utf8"
```

### Building

Use `scripts/build.sh` to build the docker image locally. You'll need to rebuild the docker image any time plugins change.

### Running

Run `scripts/run.sh` and point your browser at http://localhost:3000. Changes to files under `app/` will be reloaded automatically.
