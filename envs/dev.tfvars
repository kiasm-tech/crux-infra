environment = "dev"

# Star Catch (README → Star Catch): its Key Vault secrets must exist before this applies.
star_catch = {
  image             = "ghcr.io/kiasm-tech/star-catch:75684a82a9ecce9ce5c2b99ce94c0653387e56a5"
  registry_username = "bareshub"
  github_app_id     = "4305908"
  repos             = "" # switched on per repo in Crux
}
