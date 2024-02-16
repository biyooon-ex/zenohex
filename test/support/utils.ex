defmodule Zenohex.Test.Utils do
  @moduledoc false

  def maybe_different_session(session) do
    if System.get_env("USE_DIFFERENT_SESSION") == "1" do
      Zenohex.open!()
    else
      session
    end
  end
end
