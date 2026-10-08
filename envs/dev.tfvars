environment = "dev"

# Star Catch (README → Star Catch): its Key Vault secrets must exist before this applies.
star_catch = {
  image             = "ghcr.io/kiasm-tech/star-catch:e17c25703d260f0514c3b00d71550eecb716e0bc"
  registry_username = "bareshub"
  github_app_id     = "4305908"
  repos             = "" # switched on per repo in Crux
  worker_env        = { CRUX_PUBLIC_URL = "https://crux.kiasm.dev" }
}
