# Because we don't use --no-start option for ExUnit, we NEED to make sure
# that before :engine tests start, there are no connections towards PG.
# Why? Because before each :engine DB test, we expect the DB to be wiped clean.
# (mix ecto.drop)
# ** (Mix) The database for Engine.Repo couldn't be dropped: ERROR 55006 (object_in_use):
# What I mean is ... Meaning Engine.Repo process isn't running.
Application.start(:engine)
ExUnit.start(capture_log: true, assert_receive_timeout: 1000)
