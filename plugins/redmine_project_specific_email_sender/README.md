# Project Specific Email Sender

## Description

Allows each project to have a custom sender email address for all outbound emails and to grant permissions to roles to edit this email.

## Installing

First, clone this project into your redmine plugins folder:

``git clone <project_link>``

Then, you need run the migrations of the plugin:

``bundle exec rake redmine:plugins:migrate RAILS_ENV=production``

And you're good to go.

## Usage

Project specific emails can be edited in the Outbound Email tab in Projects.

Permission to edit projects email address can be granted to Roles. Under Role permissions, check the "Edit Project email" permission to grant a role edit privileges.

To edit a projects email: ``Select the project > Click the Settings Tab >> Outbound email tab``

## Versioning

This project uses [SemVer](https://semver.org/) as a versioning system with ``MAJOR.MINOR.PATCH``.
