# Heroku Deployment Guide for Redmine

This guide will help you deploy Redmine to Heroku.

## Prerequisites

1. Heroku account (sign up at https://www.heroku.com)
2. Heroku CLI installed (https://devcenter.heroku.com/articles/heroku-cli)
3. Git repository initialized

## Initial Setup

### 1. Install Heroku CLI and Login

```bash
# Install Heroku CLI (if not already installed)
# macOS: brew tap heroku/brew && brew install heroku
# Or download from https://devcenter.heroku.com/articles/heroku-cli

# Login to Heroku
heroku login
```

### 2. Create Heroku App

```bash
cd /Users/dave/Development/_Smarlify/Redmine-PM

# Create a new Heroku app
heroku create your-app-name

# Or let Heroku generate a name
heroku create
```

### 3. Add PostgreSQL Database

Heroku provides PostgreSQL as an addon. Add it to your app:

```bash
# Add the free tier PostgreSQL database
heroku addons:create heroku-postgresql:essential-0

# Or for a paid tier
heroku addons:create heroku-postgresql:standard-0
```

### 4. Configure Environment Variables

Set any required environment variables:

```bash
# Set Rails environment
heroku config:set RAILS_ENV=production

# Enable static file serving
heroku config:set RAILS_SERVE_STATIC_FILES=true

# Set secret key base (Rails will generate one, but you can set your own)
heroku config:set SECRET_KEY_BASE=$(rails secret)
```

### 5. Deploy to Heroku

```bash
# Make sure all changes are committed
git add .
git commit -m "Configure for Heroku deployment"

# Push to Heroku
git push heroku main

# Or if your default branch is master
git push heroku master
```

### 6. Run Database Migrations

```bash
# Run migrations
heroku run rake db:migrate

# Load default Redmine data (locales, roles, etc.)
heroku run rake redmine:load_default_data

# This will prompt you for a language, choose your preferred one (e.g., 'en')
```

### 7. Create Admin User

```bash
# Open Rails console on Heroku
heroku run rails console

# Then in the console, create an admin user:
# user = User.new(:login => "admin", :password => "yourpassword", :password_confirmation => "yourpassword", :firstname => "Admin", :lastname => "User", :mail => "admin@example.com")
# user.admin = true
# user.save!
```

### 8. Restart the Application

```bash
heroku restart
```

### 9. Open Your App

```bash
heroku open
```

## Important Notes

### Database Configuration

The `config/database.yml` file is configured to use Heroku's `DATABASE_URL` environment variable automatically. Heroku sets this when you add the PostgreSQL addon.

### Static Assets

Static file serving is enabled in production for Heroku. If you want to use a CDN or asset host, you can configure it in `config/environments/production.rb`.

### File Storage

Redmine stores uploaded files in the `files/` directory by default. On Heroku, the filesystem is ephemeral, meaning files will be lost on each deploy. For production use, consider:

1. **Using a cloud storage service** (S3, Google Cloud Storage, etc.)
2. **Using Heroku addons** like Bucketeer or similar
3. **Configuring Redmine** to use external storage

### Email Configuration

To send emails from Redmine on Heroku, configure SMTP settings:

```bash
# Add SendGrid addon (free tier available)
heroku addons:create sendgrid:starter

# Or configure custom SMTP
heroku config:set SMTP_HOST=smtp.example.com
heroku config:set SMTP_PORT=587
heroku config:set SMTP_USERNAME=your-username
heroku config:set SMTP_PASSWORD=your-password
```

Then configure in Redmine admin panel: Administration → Settings → Email notifications

### Scaling

For production use, consider:

```bash
# Scale up web dynos
heroku ps:scale web=1

# For better performance, use Standard dynos
heroku ps:resize web=standard-1x
```

### Monitoring

```bash
# View logs
heroku logs --tail

# Check app status
heroku ps

# View config vars
heroku config
```

## Troubleshooting

### Database Connection Issues

If you encounter database connection issues:

```bash
# Check database URL
heroku config:get DATABASE_URL

# Test database connection
heroku run rails db
```

### Asset Precompilation

If assets aren't loading:

```bash
# Precompile assets manually
heroku run rake assets:precompile
```

### Memory Issues

If you encounter memory issues, consider:

1. Upgrading to a larger dyno
2. Reducing worker processes in `config/puma.rb`
3. Using a memory-efficient cache store

## Updating Your Deployment

After making changes:

```bash
git add .
git commit -m "Your commit message"
git push heroku main  # or master
heroku run rake db:migrate  # if you have new migrations
heroku restart
```

## Additional Resources

- [Heroku Ruby Support](https://devcenter.heroku.com/articles/ruby-support)
- [Heroku PostgreSQL](https://devcenter.heroku.com/articles/heroku-postgresql)
- [Redmine Installation Guide](https://www.redmine.org/projects/redmine/wiki/RedmineInstall)

