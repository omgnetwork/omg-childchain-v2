# Used by "mix format"
[
  inputs: ["mix.exs", "config/*.exs", "apps/*/mix.exs",  "apps/*/*.ex", 
    "apps/*/{lib,test,config}/**/*.{ex,exs}", "apps/*/priv/repo/migrations/*.exs"],
  subdirectories: ["apps/*"],
  line_length: 120,
]
