# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :mafia_interface, MafiaInterfaceWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "6cZh1y8pi98xOUV0/VmKj5ncMBj7j7s+oDFkqU7gU1m5H/Pvl8MbzPB9DGWuHWx2",
  render_errors: [view: MafiaInterfaceWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: MafiaInterface.PubSub,
  live_view: [signing_salt: "V5Ih/uQZ"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
