environment = "dev"

# Star Catch (README → Star Catch): its Key Vault secrets must exist before this applies.
star_catch = {
  image             = "ghcr.io/kiasm-tech/star-catch:06i-c9d0e4b" # built from feat/06i-build-context
  registry_username = "bareshub"
  github_app_id     = "4305908"
  repos             = "pmndrs/zustand"
  worker_env        = { STAR_CATCH_MOCK_GITHUB = "true" } # recorded PRs until the App's webhook points at intake
}
