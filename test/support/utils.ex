defmodule Zenohex.Test.Utils do
  def maybe_different_session(session) do
    if is_nil(System.get_env("USE_DIFFERENT_SESSION")) do
      session
    else
      Zenohex.open!()
    end
  end
end
