environment = "dev"

# Star Catch (README → Star Catch): its Key Vault secrets must exist before this applies.
star_catch = {
  image             = "ghcr.io/kiasm-tech/star-catch:96b0e538769d089685ece6886ddc9191569d06d2"
  registry_username = "bareshub"
  github_app_id     = "4305908"
  repos             = "" # switched on per repo in Crux
}
