# Used by "mix format"
[
  inputs: ["mix.exs", "config/*.exs", "apps/*/mix.exs",
    "apps/*/{lib,test,config}/**/*.{ex,exs}"],
  subdirectories: ["apps/*"],
  line_length: 120,
]
