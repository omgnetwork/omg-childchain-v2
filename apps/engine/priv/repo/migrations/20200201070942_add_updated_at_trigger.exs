defmodule Engine.Repo.Migrations.AddUpdatedAtTrigger do
  use Ecto.Migration

  # copied from Diesel initial migration - https://github.com/diesel-rs/diesel
  # https://github.com/diesel-rs/diesel/blob/2fa746f8f10b8a1dd0a46bac499ad7eee58de17c/diesel_cli/src/setup_sql/postgres/initial_setup/up.sql
  #
  # Sets up a trigger for the given table to automatically set a column called
  # `updated_at` whenever the row is modified (unless `updated_at` was included
  # in the modified columns)
  #
  # # Example
  #
  # ```sql
  # CREATE TABLE users (id SERIAL PRIMARY KEY, updated_at TIMESTAMP NOT NULL DEFAULT NOW());
  #
  # SELECT diesel_manage_updated_at('users');
  # ```
  def up do
    # `ecto_manage_updated_at` assigns the  `ecto_set_updated_at` trigger to the specified table.
    # the trigger is executed before update
    execute("
      CREATE OR REPLACE FUNCTION ecto_manage_updated_at(_tbl regclass) RETURNS VOID AS $$
      BEGIN
          EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON %s
                          FOR EACH ROW EXECUTE PROCEDURE ecto_set_updated_at()', _tbl);
      END;
      $$ LANGUAGE plpgsql;")

    # this function creates a trigger which updates `updated_at` field
    execute("
      CREATE OR REPLACE FUNCTION ecto_set_updated_at() RETURNS trigger AS $$
      BEGIN
          IF (
              NEW IS DISTINCT FROM OLD AND
              NEW.updated_at IS NOT DISTINCT FROM OLD.updated_at
          ) THEN
              NEW.updated_at := current_timestamp;
          END IF;
          RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;")

    # `now_utc` function is used as a default value for `updated_at` and `inserted_at` timestamps
    # it should be set as a default value manually
    #
    # # Example
    #
    #  add(:inserted_at, :utc_datetime, null: false, default: fragment("now_utc()"))
    execute("
      CREATE FUNCTION now_utc() RETURNS TIMESTAMP AS $$
        SELECT now() AT TIME ZONE 'UTC';
      $$ LANGUAGE sql;")
  end

  def down do
    execute("DROP FUNCTION IF EXISTS ecto_manage_updated_at(_tbl regclass);")
    execute("DROP FUNCTION IF EXISTS ecto_set_updated_at();")
    execute("DROP FUNCTION IF EXISTS now_utc();")
  end
end
