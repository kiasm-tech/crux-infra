environment = "dev"

# Star Catch (README → Star Catch): its Key Vault secrets must exist before this applies.
star_catch = {
  image             = "ghcr.io/kiasm-tech/star-catch:b401a9244e607d3390792d9f14ef0efe20a5510b"
  registry_username = "bareshub"
  github_app_id     = "4305908"
  repos             = "" # switched on per repo in Crux
  worker_env        = { CRUX_PUBLIC_URL = "https://crux.kiasm.dev" }
}
