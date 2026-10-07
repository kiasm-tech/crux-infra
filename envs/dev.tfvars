environment = "dev"

# Star Catch (README → Star Catch): its Key Vault secrets must exist before this applies.
star_catch = {
  image             = "ghcr.io/kiasm-tech/star-catch:24c304aa7b1f1e2c51e58e6f0823ae66064009ec"
  registry_username = "bareshub"
  github_app_id     = "4305908"
  repos             = "" # switched on per repo in Crux
  worker_env        = { CRUX_PUBLIC_URL = "https://crux.kiasm.dev" }
}
