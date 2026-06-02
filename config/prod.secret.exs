use Mix.Config

# In this file, we keep production configuration that
# you likely want to automate and keep it away from
# your version control system.
config :battleship, Battleship.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE") || "9vBUPPF+U6OIacuWP6B8OalXx+dXsWmE+GrSP0mO4WEVyUp1Q8QS/RNAOkrM3YTu"
