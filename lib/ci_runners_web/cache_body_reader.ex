# https://github.com/phoenixframework/phoenix/issues/459#issuecomment-440820663
defmodule CiRunnersWeb.CacheBodyReader do
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    # Store the raw body string for signature verification
    conn = Plug.Conn.put_private(conn, :raw_body, body)
    {:ok, body, conn}
  end

  def read_cached_body(conn) do
    case Map.has_key?(conn.private, :raw_body) do
      true ->
        {:ok, conn.private[:raw_body], conn}

      false ->
        {:error, nil, conn}
    end
  end
end
